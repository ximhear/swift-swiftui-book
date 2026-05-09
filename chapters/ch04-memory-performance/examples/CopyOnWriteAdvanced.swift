// Ch04 - Copy-on-Write 고급 구현

import Foundation

// MARK: - 대용량 이미지 편집기 COW

struct Layer {
    var name: String
    var opacity: Double
    var isVisible: Bool
}

struct ImageDocument: Equatable {
    private final class Storage: Equatable {
        var pixels: [UInt8]
        var width: Int
        var height: Int
        var layers: [Layer]
        var undoStack: [[UInt8]]

        init(pixels: [UInt8], width: Int, height: Int,
             layers: [Layer] = [],
             undoStack: [[UInt8]] = []) {
            self.pixels = pixels
            self.width = width
            self.height = height
            self.layers = layers
            self.undoStack = undoStack
        }

        func copy() -> Storage {
            Storage(
                pixels: pixels,
                width: width,
                height: height,
                layers: layers,
                undoStack: undoStack
            )
        }

        static func == (lhs: Storage, rhs: Storage) -> Bool {
            lhs === rhs || (
                lhs.width == rhs.width &&
                lhs.height == rhs.height &&
                lhs.pixels == rhs.pixels
            )
        }
    }

    private var storage: Storage

    init(width: Int, height: Int) {
        let pixelCount = width * height * 4
        storage = Storage(
            pixels: Array(repeating: 0, count: pixelCount),
            width: width,
            height: height
        )
    }

    var width: Int { storage.width }
    var height: Int { storage.height }

    func pixel(at x: Int, y: Int)
        -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let offset = (y * storage.width + x) * 4
        return (
            storage.pixels[offset],
            storage.pixels[offset + 1],
            storage.pixels[offset + 2],
            storage.pixels[offset + 3]
        )
    }

    mutating func setPixel(
        at x: Int, y: Int,
        r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255
    ) {
        ensureUnique()
        let offset = (y * storage.width + x) * 4
        storage.pixels[offset] = r
        storage.pixels[offset + 1] = g
        storage.pixels[offset + 2] = b
        storage.pixels[offset + 3] = a
    }

    mutating func applyFilter(
        _ filter: (UInt8, UInt8, UInt8)
            -> (UInt8, UInt8, UInt8)
    ) {
        ensureUnique()
        storage.undoStack.append(storage.pixels)
        for i in stride(
            from: 0,
            to: storage.pixels.count,
            by: 4
        ) {
            let (r, g, b) = filter(
                storage.pixels[i],
                storage.pixels[i + 1],
                storage.pixels[i + 2]
            )
            storage.pixels[i] = r
            storage.pixels[i + 1] = g
            storage.pixels[i + 2] = b
        }
    }

    mutating func undo() -> Bool {
        ensureUnique()
        guard let previous = storage.undoStack.popLast()
        else { return false }
        storage.pixels = previous
        return true
    }

    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage
    }
}

// MARK: - COW 동작 검증

func verifyCOWBehavior() {
    var doc1 = ImageDocument(width: 100, height: 100)
    var doc2 = doc1  // 복사 없음 (공유)

    doc2.setPixel(at: 0, y: 0, r: 255, g: 0, b: 0)
    // doc2 수정 → 이제 비로소 복사

    let original = doc1.pixel(at: 0, y: 0)
    assert(original.r == 0)  // 원본 안전
}
