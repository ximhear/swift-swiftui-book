// Ch01 - any vs some 실무 선택 가이드

import Foundation

// MARK: - some: 컴파일 타임에 타입 결정

protocol Shape {
    func area() -> Double
}

struct Circle: Shape {
    var radius: Double
    func area() -> Double { .pi * radius * radius }
}

struct Rectangle: Shape {
    var width: Double
    var height: Double
    func area() -> Double { width * height }
}

// some — 항상 같은 구체 타입 반환
func makeDefaultShape() -> some Shape {
    Circle(radius: 10)
}

// some을 매개변수에 사용 (Swift 5.7+)
func printArea(_ shape: some Shape) {
    print("면적: \(shape.area())")
}

// MARK: - any: 런타임에 타입 결정

// 이종 컬렉션 — any 필수
let shapes: [any Shape] = [
    Circle(radius: 5),
    Rectangle(width: 10, height: 20)
]

enum OutputFormat {
    case circle, rectangle
}

// 런타임 분기 — any 필수
func createShape(for format: OutputFormat) -> any Shape {
    switch format {
    case .circle:    return Circle(radius: 10)
    case .rectangle: return Rectangle(width: 20, height: 15)
    }
}

// MARK: - Primary Associated Type + some/any

protocol DataStore<Item> {
    associatedtype Item
    func fetch(id: String) async throws -> Item
    func save(_ item: Item) async throws
}

struct User {
    let id: String
    let name: String
}

struct CoreDataUserStore: DataStore {
    func fetch(id: String) async throws -> User {
        User(id: id, name: "테스트 사용자")
    }
    func save(_ item: User) async throws {
        // CoreData에 저장
    }
}

struct APIUserStore: DataStore {
    func fetch(id: String) async throws -> User {
        User(id: id, name: "원격 사용자")
    }
    func save(_ item: User) async throws {
        // API를 통해 저장
    }
}

// some + Primary Associated Type
func makeUserStore() -> some DataStore<User> {
    CoreDataUserStore()
}

enum StoreType {
    case local, remote
}

// any + Primary Associated Type
func createStore(
    for type: StoreType
) -> any DataStore<User> {
    switch type {
    case .local:  return CoreDataUserStore()
    case .remote: return APIUserStore()
    }
}
