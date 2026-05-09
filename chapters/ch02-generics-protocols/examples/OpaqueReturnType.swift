// Ch02 - Opaque Return Type 활용 전략

import Foundation

// MARK: - 기본 규칙: 타입 일관성

protocol Theme {
    var primaryColor: String { get }
    var fontSize: Int { get }
}

struct LightTheme: Theme {
    var primaryColor = "#000000"
    var fontSize = 16
}

struct DarkTheme: Theme {
    var primaryColor = "#FFFFFF"
    var fontSize = 16
}

// 하나의 타입으로 통합하여 some 사용
struct AdaptiveTheme: Theme {
    var isDark: Bool
    var primaryColor: String {
        isDark ? "#FFFFFF" : "#000000"
    }
    var fontSize: Int { 16 }
}

func currentTheme(isDark: Bool) -> some Theme {
    AdaptiveTheme(isDark: isDark)
}

// 여러 타입 반환이 필요하면 any 사용
func flexibleTheme(isDark: Bool) -> any Theme {
    isDark ? DarkTheme() : LightTheme()
}

// MARK: - 매개변수 위치의 some (Swift 5.7+)

// some은 제네릭의 간결한 표현
func sum(_ items: some Collection<Int>) -> Int {
    items.reduce(0, +)
}

// 위와 동일:
// func sum<C: Collection<Int>>(_ items: C) -> Int {
//     items.reduce(0, +)
// }

// 같은 타입 요구 시 제네릭 필수
func merge<C: Collection<Int>>(
    _ a: C, _ b: C
) -> [Int] {
    Array(a) + Array(b)
}

// some은 각각 독립 타입 허용
func mergeAny(
    _ a: some Collection<Int>,
    _ b: some Collection<Int>
) -> [Int] {
    // a: Array, b: Set 가능
    Array(a) + Array(b)
}

// MARK: - API 설계에서의 Opaque Return Type

struct NetworkClient {
    struct User: Decodable {
        let id: String
        let name: String
    }

    // 내부 구현을 숨기면서 성능 유지
    func fetchUsers()
        -> some AsyncSequence<User, Error> {
        AsyncThrowingStream { continuation in
            // 네트워크 요청 구현...
            continuation.finish()
        }
    }
}

func demonstrateOpaqueAPI() async throws {
    let client = NetworkClient()
    for try await user in client.fetchUsers() {
        print(user.name)
    }
}
