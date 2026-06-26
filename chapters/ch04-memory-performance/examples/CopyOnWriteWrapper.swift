// Ch04 - @CopyOnWrite 프로퍼티 래퍼 사용 예제
//
// 빌드 및 실행:
//   swiftc CopyOnWriteWrapper.swift -o /tmp/cow_wrapper
//   /tmp/cow_wrapper
//
// 핵심:
//   - buffer (wrappedValue)  → 읽기만, 복사 안 함
//   - $buffer (projectedValue) → 변경, 필요시 isKnownUniquelyReferenced 검사 후 copy()
//   - 구조체 복사는 얕은 복사, 첫 mutation 시점에만 실제 데이터가 분리됨

import Foundation

// MARK: - 범용 COW 래퍼

@propertyWrapper
struct CopyOnWrite<Value: AnyObject & NSCopying> {
    private var storage: Value

    init(wrappedValue: Value) { storage = wrappedValue }

    var wrappedValue: Value {
        get { storage }
        set { storage = newValue }
    }

    var projectedValue: Value {
        mutating get {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy() as! Value
            }
            return storage
        }
    }
}

// MARK: - NSCopying을 구현한 참조 타입

final class PixelBuffer: NSCopying {
    var pixels: [UInt8]

    init(_ pixels: [UInt8]) { self.pixels = pixels }

    func copy(with zone: NSZone? = nil) -> Any {
        print("  ⚙️ PixelBuffer.copy() 호출됨")
        return PixelBuffer(pixels)
    }
}

// MARK: - @CopyOnWrite로 감싼 값 타입

struct Canvas {
    @CopyOnWrite var buffer: PixelBuffer

    init(_ pixels: [UInt8]) {
        _buffer = CopyOnWrite(wrappedValue: PixelBuffer(pixels))
    }

    var pixelCount: Int { buffer.pixels.count }

    mutating func setPixel(at i: Int, value: UInt8) {
        $buffer.pixels[i] = value
    }
}

// MARK: - 데모

print("=== @CopyOnWrite 데모 ===\n")

var a = Canvas([10, 20, 30, 40])
var b = a   // 구조체 복사 — 같은 PixelBuffer 공유

print("[1] 읽기만 — copy() 호출 없음")
_ = a.pixelCount
_ = b.pixelCount

print("\n[2] b만 변경 — 이 시점에 copy() 호출")
b.setPixel(at: 0, value: 99)

print("\n[3] 결과 (a, b 독립)")
print("  a.pixels = \(a.buffer.pixels)")
print("  b.pixels = \(b.buffer.pixels)")

print("\n[4] b 추가 변경 — b는 유일 참조이므로 copy() 안 됨")
b.setPixel(at: 1, value: 88)
print("  b.pixels = \(b.buffer.pixels)")
