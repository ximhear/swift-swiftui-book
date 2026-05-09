// Ch02 - Associated Type 심화

import Foundation

// MARK: - 기본 Associated Type

protocol Repository {
    associatedtype Item: Identifiable

    func findAll() -> [Item]
    func find(by id: Item.ID) -> Item?
    mutating func save(_ item: Item) throws
    mutating func delete(by id: Item.ID) throws
}

struct User: Identifiable, Codable, Comparable {
    let id: UUID
    var name: String
    var email: String

    static func < (lhs: User, rhs: User) -> Bool {
        lhs.name < rhs.name
    }
}

struct UserRepository: Repository {
    private var users: [UUID: User] = [:]

    func findAll() -> [User] {
        Array(users.values)
    }

    func find(by id: UUID) -> User? {
        users[id]
    }

    mutating func save(_ item: User) throws {
        users[item.id] = item
    }

    mutating func delete(by id: UUID) throws {
        users.removeValue(forKey: id)
    }
}

// MARK: - 다중 Associated Type

protocol DataMapper {
    associatedtype Input
    associatedtype Output
    associatedtype Failure: Error

    func map(_ input: Input) throws(Failure) -> Output
}

struct UserMapper: DataMapper {
    struct MappingError: Error {
        let field: String
    }

    func map(_ input: [String: Any])
        throws(MappingError) -> User {
        guard let name = input["name"] as? String else {
            throw MappingError(field: "name")
        }
        guard let email = input["email"] as? String
        else {
            throw MappingError(field: "email")
        }
        return User(
            id: UUID(),
            name: name,
            email: email
        )
    }
}

// MARK: - 조건부 확장

extension Repository where Item: Codable {
    func exportJSON() throws -> Data {
        let items = findAll()
        return try JSONEncoder().encode(items)
    }
}

extension Repository where Item: Comparable {
    func findAllSorted() -> [Item] {
        findAll().sorted()
    }
}
