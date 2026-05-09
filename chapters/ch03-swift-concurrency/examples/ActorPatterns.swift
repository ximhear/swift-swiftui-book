// Ch03 - Actor와 데이터 격리

import Foundation

// MARK: - 기본 Actor

actor BankAccount {
    var balance: Int = 0

    func deposit(_ amount: Int) {
        balance += amount
    }

    func withdraw(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    var statement: String {
        "잔액: \(balance)원"
    }
}

// MARK: - Actor Reentrancy 안전 패턴

actor ImageCache {
    private var cache: [URL: Data] = [:]
    private var inProgress: [URL: Task<Data, Error>] = [:]

    func loadImage(from url: URL) async throws -> Data {
        if let cached = cache[url] {
            return cached
        }

        // 이미 진행 중인 요청이 있으면 그 결과를 기다림
        if let existing = inProgress[url] {
            return try await existing.value
        }

        let task = Task {
            try await URLSession.shared
                .data(from: url).0
        }

        inProgress[url] = task

        do {
            let data = try await task.value
            cache[url] = data
            inProgress.removeValue(forKey: url)
            return data
        } catch {
            inProgress.removeValue(forKey: url)
            throw error
        }
    }
}

// MARK: - nonisolated

actor UserService {
    private var users: [String: String] = [:]

    func addUser(id: String, name: String) {
        users[id] = name
    }

    // 상태에 접근하지 않으므로 격리 불필요
    nonisolated func validate(email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    nonisolated var description: String {
        "UserService"
    }
}

// MARK: - Actor 기반 캐시 매니저

actor CacheManager<Key: Hashable & Sendable,
                    Value: Sendable> {
    private var cache: [Key: CacheEntry] = [:]
    private let maxAge: TimeInterval

    struct CacheEntry {
        let value: Value
        let timestamp: Date

        func isExpired(maxAge: TimeInterval) -> Bool {
            Date.now.timeIntervalSince(timestamp) > maxAge
        }
    }

    init(maxAge: TimeInterval = 300) {
        self.maxAge = maxAge
    }

    func get(_ key: Key) -> Value? {
        guard let entry = cache[key],
              !entry.isExpired(maxAge: maxAge) else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        cache[key] = CacheEntry(
            value: value,
            timestamp: .now
        )
    }

    func getOrFetch(
        _ key: Key,
        fetch: @Sendable () async throws -> Value
    ) async throws -> Value {
        if let cached = get(key) {
            return cached
        }
        let value = try await fetch()
        set(key, value: value)
        return value
    }
}
