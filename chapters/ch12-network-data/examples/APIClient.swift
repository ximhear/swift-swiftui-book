// Ch12 - API 클라이언트와 엔드포인트 패턴

import Foundation

// MARK: - API 클라이언트

actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            d.keyDecodingStrategy = .convertFromSnakeCase
            return d
        }()
    }

    func request<T: Decodable>(
        _ endpoint: Endpoint
    ) async throws -> T {
        let urlRequest = try endpoint.urlRequest(
            baseURL: baseURL)
        let (data, response) = try await session.data(
            for: urlRequest)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
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

    init(path: String, method: HTTPMethod = .get,
         queryItems: [URLQueryItem] = [],
         body: Data? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
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
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.httpBody = body
        if body != nil {
            req.setValue("application/json",
                        forHTTPHeaderField: "Content-Type")
        }
        return req
    }
}

// MARK: - 엔드포인트 카탈로그

extension Endpoint {
    static func users(page: Int = 1) -> Endpoint {
        Endpoint(path: "/users", queryItems: [
            URLQueryItem(name: "page", value: "\(page)")
        ])
    }

    static func user(id: String) -> Endpoint {
        Endpoint(path: "/users/\(id)")
    }
}

// MARK: - 에러

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
}

// MARK: - 재시도

func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do { return try await operation() }
        catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                try await Task.sleep(
                    for: .seconds(pow(2.0,
                        Double(attempt))))
            }
        }
    }
    throw lastError!
}
