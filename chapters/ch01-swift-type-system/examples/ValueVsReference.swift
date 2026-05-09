// Ch01 - 값 타입 vs 참조 타입 성능 비교

import Foundation

// MARK: - 값 타입 (스택 할당)

struct ValuePoint {
    var x: Double
    var y: Double
}

// MARK: - 참조 타입 (힙 할당)

class ReferencePoint {
    var x: Double
    var y: Double
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - 벤치마크

func measureValueType() {
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<1_000_000 {
        var point = ValuePoint(x: 1.0, y: 2.0)
        point.x += 1.0
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print("값 타입: \(elapsed)초")
}

func measureReferenceType() {
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<1_000_000 {
        let point = ReferencePoint(x: 1.0, y: 2.0)
        point.x += 1.0
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print("참조 타입: \(elapsed)초")
}

// MARK: - 값 의미론의 안전성

// 참조 타입의 함정
class SettingsClass {
    var fontSize: Int = 14
}

func demonstrateReferenceTrap() {
    let defaultSettings = SettingsClass()
    let userSettings = defaultSettings
    userSettings.fontSize = 18

    // 의도하지 않은 변경!
    print(defaultSettings.fontSize) // 18
}

// 값 타입의 안전성
struct SettingsStruct {
    var fontSize: Int = 14
}

func demonstrateValueSafety() {
    let defaultSettings = SettingsStruct()
    var userSettings = defaultSettings
    userSettings.fontSize = 18

    // 원본은 안전
    print(defaultSettings.fontSize) // 14
}
