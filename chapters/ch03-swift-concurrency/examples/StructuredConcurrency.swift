// Ch03 - Structured Concurrency 기본 패턴

import Foundation

// MARK: - 콜백 → async/await 변환

struct User: Sendable { let id: String; var name: String }
struct Avatar: Sendable { let data: Data }
struct Post: Sendable { let title: String }
struct Profile: Sendable {
    let user: User
    let avatar: Avatar
    let posts: [Post]
}

// async/await 버전: 선형적이고 읽기 쉬움
func fetchUserProfile(
    userId: String
) async throws -> Profile {
    let user = try await fetchUser(userId: userId)

    // async let으로 병렬 실행
    async let avatar = fetchAvatar(url: user.avatarURL)
    async let posts = fetchPosts(userId: userId)

    return Profile(
        user: user,
        avatar: try await avatar,
        posts: try await posts
    )
}

// MARK: - Suspension Point

struct Order { let amount: Int; let items: [String] }
struct Receipt { let id: String }

func processOrder(_ order: Order) async throws -> Receipt {
    // 각 await가 중단 지점
    let payment = try await chargePayment(order.amount)
    try await deductInventory(order.items)
    return try await generateReceipt(payment: payment)
}

// MARK: - Task 취소 처리

struct DataItem { let value: Int }
struct ProcessResult { let output: Int }

func processLargeDataset(
    _ items: [DataItem]
) async throws -> [ProcessResult] {
    var results: [ProcessResult] = []

    for item in items {
        // 취소 확인
        try Task.checkCancellation()

        let result = try await process(item)
        results.append(result)
    }

    return results
}

// MARK: - 헬퍼 (컴파일을 위한 스텁)

extension User { var avatarURL: URL { URL(string: "https://example.com")! } }
func fetchUser(userId: String) async throws -> User { User(id: userId, name: "Test") }
func fetchAvatar(url: URL) async throws -> Avatar { Avatar(data: Data()) }
func fetchPosts(userId: String) async throws -> [Post] { [] }
func chargePayment(_ amount: Int) async throws -> String { "pay_123" }
func deductInventory(_ items: [String]) async throws { }
func generateReceipt(payment: String) async throws -> Receipt { Receipt(id: "r_1") }
func process(_ item: DataItem) async throws -> ProcessResult { ProcessResult(output: item.value) }
