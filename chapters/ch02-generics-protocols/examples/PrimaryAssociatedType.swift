// Ch02 - Primary Associated Type

import Foundation

// MARK: - Primary Associated Type 선언

protocol Container<Element> {
    associatedtype Element
    var count: Int { get }
    func item(at index: Int) -> Element
}

struct ArrayContainer<Element>: Container {
    private let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    var count: Int { elements.count }

    func item(at index: Int) -> Element {
        elements[index]
    }
}

struct RangeContainer: Container {
    private let range: ClosedRange<Int>

    init(_ range: ClosedRange<Int>) {
        self.range = range
    }

    var count: Int { range.count }

    func item(at index: Int) -> Int {
        range.lowerBound + index
    }
}

// MARK: - some/any + Primary Associated Type

// some: 정적 디스패치
func processStrings(
    _ container: some Container<String>
) {
    for i in 0..<container.count {
        let str = container.item(at: i)
        print(str.uppercased())
    }
}

// any: 이종 컬렉션
func demonstrateHeterogeneousContainers() {
    let containers: [any Container<Int>] = [
        ArrayContainer([1, 2, 3]),
        RangeContainer(1...10)
    ]
    for container in containers {
        print("Count: \(container.count)")
    }
}

// MARK: - 표준 라이브러리 활용

func printAll(_ items: some Collection<String>) {
    for item in items {
        print(item)
    }
}

func firstPositive(
    _ numbers: some Sequence<Int>
) -> Int? {
    numbers.first { $0 > 0 }
}

// MARK: - 설계 가이드: 핵심 타입만 Primary로

protocol Cache<Value> {
    associatedtype Key: Hashable
    associatedtype Value

    func get(_ key: Key) -> Value?
    mutating func set(_ key: Key, value: Value)
}

struct InMemoryCache<Key: Hashable, Value>: Cache {
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? {
        storage[key]
    }

    mutating func set(_ key: Key, value: Value) {
        storage[key] = value
    }
}
