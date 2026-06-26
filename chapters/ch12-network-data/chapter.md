# Chapter 12. 네트워크와 데이터 계층

> 대부분의 앱은 서버와 통신하고 데이터를 로컬에 저장합니다. URLSession + async/await 패턴, 체계적인 에러 처리와 재시도 전략, 캐싱과 오프라인 지원, 그리고 SwiftData 통합까지 — 이 장에서는 견고한 데이터 계층을 설계하는 방법을 다룹니다.

---

## 12.1 URLSession + async/await 패턴

### API 클라이언트 설계

🟡 중급

네트워크 호출은 앱 전반에서 반복되는 작업입니다. 매번 `URLSession`을 직접 다루기보다, 요청 생성·응답 검증·디코딩을 한곳에 모아두면 호출부가 간결해지고 에러 처리도 일관됩니다. 여기서는 동시 호출이 잦은 점을 고려해 클라이언트를 액터(Actor)로 설계해 내부 상태(`session`, `decoder`)를 안전하게 공유합니다.

> **Note**: 아래는 본문 설명용 확장판입니다. 바로 실행해 볼 수 있는 축약 버전은 `examples/APIClient.swift`에 같은 시그니처로 정리해 두었습니다.

**파일: APIClient.swift**

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
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // 디코딩 실패를 도메인 에러로 래핑해 호출부에서 구분 가능하게
            throw APIError.decodingError(error)
        }
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
    case patch = "PATCH"
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

### 엔드포인트(Endpoint) 카탈로그 패턴

🟡 중급

호출부에 경로 문자열과 쿼리 파라미터가 흩어지면 오타와 중복이 늘어납니다. 엔드포인트(Endpoint) 카탈로그 패턴은 각 API를 정적 팩토리 메서드로 한곳에 모아, 호출부에서는 `.users(page:)`처럼 의도가 드러나는 이름만 쓰도록 합니다.

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

🟢 기본

에러를 단일 평면 enum으로 두면 케이스가 수십 개로 불어나 처리부가 거대한 `switch`가 됩니다. 네트워크·데이터·비즈니스처럼 책임 영역별로 에러를 중첩 enum으로 묶으면, 호출부는 관심 있는 계층만 골라 처리할 수 있습니다.

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

🔴 고급

일시적인 서버 오류(5xx)나 일시적 네트워크 단절은 잠시 뒤 다시 시도하면 성공하는 경우가 많습니다. 다만 즉시 반복하면 서버에 부하를 더하므로, 시도할 때마다 대기 시간을 1초 → 2초 → 4초처럼 지수적으로 늘리는 지수 백오프(exponential backoff) 전략을 씁니다. 재시도 정책을 값 타입으로 분리하면 호출부마다 다른 정책을 주입할 수 있습니다.

재시도 정책은 `withRetryPolicy`의 기본 인자(`static let \`default\``)로 쓰이고 동시성 경계를 넘나들 수 있어야 합니다. 따라서 `RetryPolicy`는 반드시 `Sendable`이어야 하며, 저장하는 클로저도 `@Sendable`로 표시해야 합니다.

```swift
import Foundation

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
                // baseDelay에 2^attempt를 곱해 지수적으로 증가
                // (Foundation.pow는 Double을 반환하고
                //  Duration * Double은 Duration을 돌려준다)
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
    
    // precondition으로 최소 1회 실행이 보장되므로
    // 여기 도달했다면 마지막 재시도가 실패해 lastError가 채워져 있다
    throw lastError ?? CancellationError()
}
```

> **Warning**: 재시도 루프 도중 `Task`가 취소되면 `Task.sleep(for:)`이 `CancellationError`를 던집니다. 이 에러는 `retryableErrors`에서 `false`를 반환하므로 재시도 없이 즉시 위로 전파됩니다. 즉 취소는 백오프 대기 중에도 곧바로 반영되며, 이를 다시 잡아 재시도하지 않도록 주의해야 합니다.

---

## 12.3 캐싱과 오프라인 지원

### 메모리 + 디스크 캐시

🟡 중급

메모리 캐시는 빠르지만 앱을 종료하면 사라집니다. 디스크 캐시를 함께 두면 재실행 후에도 데이터를 재사용할 수 있어 오프라인 상황에서도 마지막 응답을 보여줄 수 있습니다. 아래 `DualLayerCache`는 메모리를 1차, 디스크를 2차로 두고, 동시 접근을 액터로 직렬화합니다.

```swift
import Foundation
import CryptoKit

actor DualLayerCache<Key: Hashable & Sendable
                       & CustomStringConvertible,
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
    
    // 키를 안정적인 파일명으로 변환한다.
    // hashValue는 프로세스마다 무작위 시드를 쓰므로(SE-0206)
    // 앱을 재실행하면 같은 키라도 값이 달라져 캐시를 못 찾는다.
    // SHA256은 입력이 같으면 항상 같은 값을 주므로 파일명으로 안전하다.
    private func fileName(for key: Key) -> String {
        let digest = SHA256.hash(
            data: Data(key.description.utf8))
        return digest.map {
            String(format: "%02x", $0)
        }.joined()
    }
    
    private func loadFromDisk(_ key: Key) -> Value? {
        let fileURL = diskCacheURL.appendingPathComponent(
            fileName(for: key))
        guard let data = try? Data(contentsOf: fileURL)
        else { return nil }
        return try? JSONDecoder().decode(
            Value.self, from: data)
    }
    
    private func saveToDisk(_ key: Key, value: Value) {
        let fileURL = diskCacheURL.appendingPathComponent(
            fileName(for: key))
        if let data = try? JSONEncoder().encode(value) {
            // .atomic: 쓰기 중 강제 종료 시 부분 손상 방지
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
```

> **Warning**: 디스크 캐시 파일명에 `key.hashValue`를 쓰면 안 됩니다. Swift의 기본 해싱은 프로세스마다 무작위 시드를 사용해, 앱을 재실행하면 같은 키라도 `hashValue`가 달라집니다. 그러면 이전 실행에서 저장한 파일을 찾지 못해 항상 캐시 미스가 나고, 못 찾은 고아 파일이 계속 쌓입니다. 파일명에는 SHA256처럼 입력에 대해 항상 같은 결과를 주는 결정적(deterministic) 인코딩을 써야 합니다.

> **Note**: 위 캐시는 만료(`maxAge`)만 다루고 명시적 무효화는 제공하지 않습니다. 실무에서는 서버 데이터가 바뀌었을 때 특정 키를 강제로 비우는 `invalidate(_:)`나, 디스크 파일까지 함께 지우는 정리 로직을 더해야 메모리·디스크 두 계층이 어긋나지 않습니다.

---

## 12.4 SwiftData 통합

### 기본 모델 정의

🟢 기본

SwiftData는 `@Model` 매크로로 영속 모델을 선언하고, View에서는 `@Query`로 저장소를 직접 구독합니다. 데이터가 바뀌면 View가 자동으로 갱신되므로, 별도의 로딩 코드 없이 선언만으로 화면과 저장소를 연결할 수 있습니다.

```swift
import SwiftUI
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

View가 `@Query`로 저장소에 직접 묶이면 편하지만, 비즈니스 로직을 단위 테스트하거나 저장 방식을 바꾸기는 어렵습니다. Repository 패턴은 데이터 접근을 프로토콜 뒤로 숨겨, 테스트에서는 인메모리 구현으로 대체할 수 있게 합니다.

여기서 한 가지 동시성 제약을 짚어야 합니다. `ModelContext`는 `Sendable`이 아니며 자신을 만든 액터(보통 `@MainActor`)에 묶입니다. 따라서 `ModelContext`를 품은 `SwiftDataBookmarkStore`도 비-Sendable이며, 같은 액터 위에서만 호출해야 합니다. View가 쓰는 `@Environment(\.modelContext)`는 메인 액터 컨텍스트이므로, 아래 Repository는 `@MainActor`에서 사용한다고 전제합니다.

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

> **Warning**: `ModelContext`는 `Sendable`이 아닙니다. 메인 액터의 컨텍스트를 그대로 백그라운드 `Task`로 넘겨 쓰면 데이터 손상이나 크래시로 이어질 수 있습니다. 백그라운드에서 대량 저장이 필요하면 컨텍스트를 액터 밖으로 넘기지 말고, 아래처럼 `@ModelActor`로 전용 컨텍스트를 분리해야 합니다.

대량 가져오기나 백그라운드 동기화처럼 메인 스레드를 벗어나 작업해야 한다면, `@ModelActor` 매크로로 컨테이너로부터 자체 `ModelContext`를 소유하는 액터를 만듭니다.

```swift
@ModelActor
actor BackgroundBookmarkStore {
    // @ModelActor가 modelContext 프로퍼티와
    // init(modelContainer:)를 자동 생성한다
    func save(articleId: String, title: String,
              summary: String) throws {
        let bookmark = BookmarkArticle(
            articleId: articleId,
            title: title,
            summary: summary
        )
        modelContext.insert(bookmark)
        try modelContext.save()
    }
}
```

---

## 정리

- **API 클라이언트**: 액터(Actor) 기반 설계로 스레드 안전성을 보장하고, 엔드포인트(Endpoint) 카탈로그 패턴으로 API 호출을 체계적으로 관리합니다.

- **에러 처리**: 계층적 에러 타입과 지수 백오프 재시도 정책으로 견고한 네트워크 코드를 작성합니다.

- **캐싱**: 메모리 + 디스크 이중 캐시로 성능과 오프라인 지원을 동시에 달성합니다.

- **SwiftData**: `@Model`로 모델을 정의하고, `@Query`로 View에서 직접 데이터를 조회합니다. Repository 패턴으로 테스트 가능한 데이터 접근 계층을 만들되, `ModelContext`가 비-Sendable임을 기억하고 백그라운드 작업에는 `@ModelActor`를 사용합니다.

다음 장에서는 **테스트 전략**을 다룹니다.
