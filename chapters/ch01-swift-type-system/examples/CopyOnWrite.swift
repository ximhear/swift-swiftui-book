// Ch01 - Copy-on-Write 구현 패턴

import Foundation

// MARK: - 기본 COW 구현

final class StorageBuffer<T> {
    var elements: [T]

    init(_ elements: [T]) {
        self.elements = elements
    }

    func copy() -> StorageBuffer {
        StorageBuffer(elements)
    }
}

struct OptimizedArray<T> {
    private var storage: StorageBuffer<T>

    init(_ elements: [T] = []) {
        storage = StorageBuffer(elements)
    }

    // 변경 전에 유일한 참조인지 확인
    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
    }

    mutating func append(_ element: T) {
        ensureUnique()
        storage.elements.append(element)
    }

    var count: Int {
        storage.elements.count
    }

    subscript(index: Int) -> T {
        get { storage.elements[index] }
        set {
            ensureUnique()
            storage.elements[index] = newValue
        }
    }
}

// MARK: - 실무 패턴: Document COW

struct Page {
    var content: String
    var number: Int
}

struct Document {
    private final class Storage {
        var text: String
        var pages: [Page]
        var metadata: [String: String]

        init(text: String, pages: [Page],
             metadata: [String: String]) {
            self.text = text
            self.pages = pages
            self.metadata = metadata
        }

        func copy() -> Storage {
            Storage(
                text: text,
                pages: pages,
                metadata: metadata
            )
        }
    }

    private var storage: Storage

    init(text: String = "",
         pages: [Page] = [],
         metadata: [String: String] = [:]) {
        storage = Storage(
            text: text,
            pages: pages,
            metadata: metadata
        )
    }

    // 읽기 — 복사 없음
    var text: String {
        storage.text
    }

    var pageCount: Int {
        storage.pages.count
    }

    // 쓰기 — 필요시에만 복사
    var mutableText: String {
        get { storage.text }
        set {
            ensureUnique()
            storage.text = newValue
        }
    }

    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
    }
}
