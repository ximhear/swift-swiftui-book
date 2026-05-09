// Ch02 - 프로토콜 합성과 조건부 준수

import Foundation

// MARK: - 프로토콜 합성

protocol Storable {
    func save() throws
}

protocol Loadable {
    static func load(from id: String) throws -> Self
}

protocol Cacheable {
    var cacheKey: String { get }
    var expiresAt: Date? { get }
}

typealias Persistable = Storable & Loadable & Codable
typealias SyncableEntity =
    Persistable & Cacheable & Sendable

struct UserProfile: SyncableEntity {
    var cacheKey: String { "user_\(id)" }
    var expiresAt: Date? { nil }

    let id: String
    var name: String
    var email: String

    func save() throws { /* ... */ }

    static func load(
        from id: String
    ) throws -> UserProfile {
        UserProfile(id: id, name: "", email: "")
    }
}

// 프로토콜 합성으로 정확한 요구사항 표현
func syncToCloud<T: Storable & Loadable & Cacheable>(
    _ item: T
) throws {
    if let expiresAt = item.expiresAt,
       expiresAt < Date.now {
        let refreshed = try T.load(from: item.cacheKey)
        try refreshed.save()
    } else {
        try item.save()
    }
}

// MARK: - 조건부 준수 (Conditional Conformance)

struct Pair<First, Second> {
    var first: First
    var second: Second
}

extension Pair: Equatable
    where First: Equatable, Second: Equatable {
    static func == (lhs: Pair, rhs: Pair) -> Bool {
        lhs.first == rhs.first
            && lhs.second == rhs.second
    }
}

extension Pair: Hashable
    where First: Hashable, Second: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(first)
        hasher.combine(second)
    }
}

extension Pair: Codable
    where First: Codable, Second: Codable { }

func demonstrateConditionalConformance() {
    // String과 Int 모두 Hashable → Pair도 Hashable
    let pair = Pair(first: "hello", second: 42)
    let set: Set = [pair]
    print("Set count: \(set.count)")

    // 중첩도 자동으로 작동
    let nestedPair = Pair(
        first: Pair(first: "a", second: 1),
        second: Pair(first: "b", second: 2)
    )
    let nestedSet: Set = [nestedPair]
    print("Nested set count: \(nestedSet.count)")
}
