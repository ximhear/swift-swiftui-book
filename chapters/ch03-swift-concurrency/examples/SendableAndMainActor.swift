// Ch03 - Sendable과 MainActor

import Foundation
import SwiftUI

// MARK: - Sendable 타입

// 값 타입은 기본적으로 Sendable
struct Coordinate: Sendable {
    var latitude: Double
    var longitude: Double
}

// 불변 final 클래스도 Sendable 가능
final class APIEndpoint: Sendable {
    let baseURL: URL
    let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

// MARK: - @unchecked Sendable

final class ThreadSafeCache<Key: Hashable, Value>:
    @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? {
        lock.withLock { storage[key] }
    }

    func set(_ key: Key, value: Value) {
        lock.withLock { storage[key] = value }
    }
}

// MARK: - @Sendable 클로저

actor EventBus {
    private var handlers:
        [String: [@Sendable (Any) -> Void]] = [:]

    func subscribe(
        to event: String,
        handler: @escaping @Sendable (Any) -> Void
    ) {
        handlers[event, default: []].append(handler)
    }

    func emit(_ event: String, data: Any) {
        guard let eventHandlers = handlers[event]
        else { return }
        for handler in eventHandlers {
            handler(data)
        }
    }
}

// MARK: - MainActor ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userName: String = ""
    @Published var isLoading = false

    func loadProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let name = try await fetchUserName(userId)
            userName = name
        } catch {
            userName = "에러 발생"
        }
    }

    // 무거운 작업은 MainActor 밖에서 실행
    nonisolated func fetchUserName(
        _ userId: String
    ) async throws -> String {
        // 백그라운드에서 실행됨
        try await Task.sleep(for: .milliseconds(500))
        return "사용자 \(userId)"
    }
}

// MARK: - SwiftUI .task 패턴

struct UserProfileView: View {
    @State private var userName = ""
    let userId: String

    var body: some View {
        Text(userName)
            .task(id: userId) {
                // userId가 바뀌면 이전 Task 취소 후 재시작
                do {
                    userName = try await fetchUser(userId)
                } catch {
                    userName = "로드 실패"
                }
            }
    }
}

private func fetchUser(_ id: String) async throws -> String {
    "User \(id)"
}
