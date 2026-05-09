# Chapter 12. 네트워크와 데이터 계층

> 대부분의 앱은 서버와 통신하고 데이터를 로컬에 저장합니다. URLSession + async/await 패턴, 체계적인 에러 처리와 재시도 전략, 캐싱과 오프라인 지원, 그리고 SwiftData 통합까지 — 이 장에서는 견고한 데이터 계층을 설계하는 방법을 다룹니다.

---

## 12.1 URLSession + async/await 패턴

### API 클라이언트 설계

```swift
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
        
        return try decoder.decode(T.self, from: data)
    }
}

// 엔드포인트 정의
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
            resolvingAgainstBaseURL: true
        )!
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

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

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
```

### 엔드포인트 카탈로그 패턴

🟡 중급

```swift
extension Endpoint {
    // GET /users
    static func users(
        page: Int = 1,
        limit: Int = 20
    ) -> Endpoint {
        Endpoint(
            path: "/users",
            queryItems: [
                URLQueryItem(name: "page",
                            value: "\(page)"),
                URLQueryItem(name: "limit",
                            value: "\(limit)")
            ]
        )
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

// 사용
let users: [User] = try await client.request(
    .users(page: 1))
let user: User = try await client.request(
    .user(id: "123"))
```

---

## 12.2 에러 처리와 재시도 전략

### 계층적 에러 처리

```swift
enum AppError: Error {
    case network(NetworkError)
    case data(DataError)
    case business(BusinessError)
    
    enum NetworkError: Error {
        case noConnection
        case timeout
        case serverError(statusCode: Int)
    }
    
    enum DataError: Error {
        case notFound
        case corrupted
        case migrationFailed
    }
    
    enum BusinessError: Error {
        case insufficientBalance
        case itemOutOfStock
        case unauthorized
    }
}
```

### 지수 백오프 재시도

```swift
struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: Duration
    let maxDelay: Duration
    let retryableErrors: (Error) -> Bool
    
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
    var lastError: Error?
    
    for attempt in 0..<policy.maxAttempts {
        do {
            return try await operation()
        } catch where policy.retryableErrors(error) {
            lastError = error
            if attempt < policy.maxAttempts - 1 {
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
    
    throw lastError!
}

private func pow(_ base: Duration,
                  _ exponent: Double) -> Duration {
    let seconds = Double(base.components.seconds)
    return .seconds(seconds * Foundation.pow(2, exponent))
}
```

---

## 12.3 캐싱과 오프라인 지원

### 메모리 + 디스크 캐시

🟡 중급

```swift
actor DualLayerCache<Key: Hashable & Sendable,
                      Value: Codable & Sendable> {
    private var memoryCache: [Key: CacheEntry] = [:]
    private let diskCacheURL: URL
    private let maxAge: TimeInterval
    
    struct CacheEntry {
        let value: Value
        let timestamp: Date
        
        func isExpired(maxAge: TimeInterval) -> Bool {
            Date.now.timeIntervalSince(timestamp) > maxAge
        }
    }
    
    init(name: String, maxAge: TimeInterval = 3600) {
        self.maxAge = maxAge
        diskCacheURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(name)
        
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true
        )
    }
    
    func get(_ key: Key) -> Value? {
        // 1. 메모리 캐시 확인
        if let entry = memoryCache[key],
           !entry.isExpired(maxAge: maxAge) {
            return entry.value
        }
        
        // 2. 디스크 캐시 확인
        if let value = loadFromDisk(key) {
            memoryCache[key] = CacheEntry(
                value: value, timestamp: .now)
            return value
        }
        
        return nil
    }
    
    func set(_ key: Key, value: Value) {
        memoryCache[key] = CacheEntry(
            value: value, timestamp: .now)
        saveToDisk(key, value: value)
    }
    
    private func loadFromDisk(_ key: Key) -> Value? {
        let fileURL = diskCacheURL.appendingPathComponent(
            "\(key.hashValue)")
        guard let data = try? Data(contentsOf: fileURL)
        else { return nil }
        return try? JSONDecoder().decode(
            Value.self, from: data)
    }
    
    private func saveToDisk(_ key: Key, value: Value) {
        let fileURL = diskCacheURL.appendingPathComponent(
            "\(key.hashValue)")
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: fileURL)
        }
    }
}
```

---

## 12.4 SwiftData 통합

### 기본 모델 정의

```swift
import SwiftData

@Model
class BookmarkArticle {
    var articleId: String
    var title: String
    var summary: String
    var bookmarkedAt: Date
    
    init(articleId: String, title: String,
         summary: String) {
        self.articleId = articleId
        self.title = title
        self.summary = summary
        self.bookmarkedAt = .now
    }
}

// SwiftUI에서 사용
struct BookmarkListView: View {
    @Query(sort: \BookmarkArticle.bookmarkedAt,
           order: .reverse)
    var bookmarks: [BookmarkArticle]
    
    @Environment(\.modelContext) var context
    
    var body: some View {
        List(bookmarks) { bookmark in
            VStack(alignment: .leading) {
                Text(bookmark.title).font(.headline)
                Text(bookmark.summary).font(.caption)
            }
            .swipeActions {
                Button("삭제", role: .destructive) {
                    context.delete(bookmark)
                }
            }
        }
    }
}
```

### Repository 패턴과 SwiftData

🟡 중급

```swift
protocol BookmarkStore {
    func all() throws -> [BookmarkArticle]
    func save(_ article: Article) throws
    func delete(articleId: String) throws
    func isBookmarked(articleId: String) throws -> Bool
}

struct SwiftDataBookmarkStore: BookmarkStore {
    let context: ModelContext
    
    func all() throws -> [BookmarkArticle] {
        let descriptor = FetchDescriptor<BookmarkArticle>(
            sortBy: [SortDescriptor(\.bookmarkedAt,
                                     order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func save(_ article: Article) throws {
        let bookmark = BookmarkArticle(
            articleId: article.id.uuidString,
            title: article.title,
            summary: String(article.body.prefix(100))
        )
        context.insert(bookmark)
        try context.save()
    }
    
    func delete(articleId: String) throws {
        let predicate = #Predicate<BookmarkArticle> {
            $0.articleId == articleId
        }
        let descriptor = FetchDescriptor(
            predicate: predicate)
        let results = try context.fetch(descriptor)
        results.forEach { context.delete($0) }
        try context.save()
    }
    
    func isBookmarked(articleId: String) throws -> Bool {
        let predicate = #Predicate<BookmarkArticle> {
            $0.articleId == articleId
        }
        var descriptor = FetchDescriptor(
            predicate: predicate)
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}
```

---

## 정리

- **API 클라이언트**: Actor 기반 설계로 스레드 안전성을 보장하고, Endpoint 카탈로그 패턴으로 API 호출을 체계적으로 관리합니다.

- **에러 처리**: 계층적 에러 타입과 지수 백오프 재시도 정책으로 견고한 네트워크 코드를 작성합니다.

- **캐싱**: 메모리 + 디스크 이중 캐시로 성능과 오프라인 지원을 동시에 달성합니다.

- **SwiftData**: `@Model`로 모델을 정의하고, `@Query`로 View에서 직접 데이터를 조회합니다. Repository 패턴으로 테스트 가능한 데이터 접근 계층을 만듭니다.

다음 장에서는 **테스트 전략**을 다룹니다.
