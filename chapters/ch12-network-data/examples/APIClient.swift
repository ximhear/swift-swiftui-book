// Ch12 - API 클라이언트, 엔드포인트, 재시도 정책
// 본문 §12.1·§12.2의 실행 가능한 최소 예제 (본문과 시그니처 1:1 대응)

import Foundation

// MARK: - API 클라이언트

actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            d.keyDecodingStrategy = .convertFromSnakeCase
            return d
        }()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func request<T: Decodable>(
        _ endpoint: Endpoint
    ) async throws -> T {
        let urlRequest = try endpoint.urlRequest(
            baseURL: baseURL)
        let (data, response) = try await session.data(
            for: urlRequest)

        guard let httpResponse = response
            as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(
            httpResponse.statusCode) else {
            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - HTTP 메서드

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - 엔드포인트

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Data?
    let headers: [String: String]

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.headers = headers
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value,
                             forHTTPHeaderField: key)
        }
        if body != nil {
            request.setValue("application/json",
                             forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

// MARK: - 에러

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "유효하지 않은 URL"
        case .invalidResponse: "유효하지 않은 응답"
        case .httpError(let code, _): "HTTP 에러: \(code)"
        case .decodingError(let error):
            "디코딩 에러: \(error.localizedDescription)"
        }
    }
}

// MARK: - 엔드포인트 카탈로그

struct User: Decodable {
    let id: String
    let name: String
}

struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

extension Endpoint {
    // GET /users
    static func users(page: Int = 1,
                      limit: Int = 20) -> Endpoint {
        Endpoint(path: "/users", queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    // GET /users/:id
    static func user(id: String) -> Endpoint {
        Endpoint(path: "/users/\(id)")
    }

    // POST /users
    static func createUser(
        _ user: CreateUserRequest
    ) throws -> Endpoint {
        Endpoint(
            path: "/users",
            method: .post,
            body: try JSONEncoder().encode(user)
        )
    }
}

// MARK: - 재시도 정책 (지수 백오프)

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelay: Duration
    let maxDelay: Duration
    // @Sendable이 없으면 RetryPolicy가 Sendable이 되지 못해
    // static let `default`(전역 상태)가 Swift 6에서 컴파일 실패한다
    let retryableErrors: @Sendable (Error) -> Bool

    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: .seconds(1),
        maxDelay: .seconds(30),
        retryableErrors: { error in
            if let apiError = error as? APIError,
               case .httpError(let code, _) = apiError {
                return code >= 500 || code == 429
            }
            return (error as NSError).domain
                == NSURLErrorDomain
        }
    )
}

func withRetryPolicy<T: Sendable>(
    _ policy: RetryPolicy = .default,
    operation: @Sendable () async throws -> T
) async throws -> T {
    precondition(policy.maxAttempts >= 1)
    var lastError: Error?

    for attempt in 0..<policy.maxAttempts {
        do {
            return try await operation()
        } catch where policy.retryableErrors(error) {
            lastError = error
            if attempt < policy.maxAttempts - 1 {
                // baseDelay * 2^attempt 로 대기 시간을 늘린다
                let delay = min(
                    policy.baseDelay * pow(2.0,
                        Double(attempt)),
                    policy.maxDelay
                )
                try await Task.sleep(for: delay)
            }
        } catch {
            throw error  // 재시도 불가능한 에러
        }
    }

    throw lastError ?? CancellationError()
}
