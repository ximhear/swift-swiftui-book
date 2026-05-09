# 부록 A. Swift 6.0/6.1 주요 변경 사항

## Swift 5.9에서 도입된 기능

### Noncopyable 타입 (`~Copyable`)

Swift 5.9에서 도입된 Noncopyable 타입은 복사가 불가능한 값 타입을 정의합니다. 고유한 리소스를 나타내는 데 유용합니다:

```swift
struct FileHandle: ~Copyable {
    let descriptor: Int32
    
    init(path: String) {
        self.descriptor = open(path, O_RDONLY)
    }
    
    deinit {
        close(descriptor)
    }
}

// 소유권 이전: consume 키워드
func process(_ handle: consuming FileHandle) {
    // handle의 소유권을 가져옴
    print("Processing file descriptor: \(handle.descriptor)")
    // 함수 종료 시 deinit 호출
}

var file = FileHandle(path: "/tmp/data.txt")
process(consume file)
// file을 이후 사용하면 컴파일 에러
```

### `consume` 연산자

`consume` 키워드로 값의 소유권을 명시적으로 이전합니다:

```swift
func transferOwnership() {
    var name = "Swift"
    let moved = consume name
    // print(name)  // 컴파일 에러: name은 이미 소비됨
    print(moved)    // "Swift"
}
```

### `package` 접근 수준

Swift Package 내부에서만 접근 가능한 API를 정의합니다. `public`보다 제한적이지만 `internal`보다 넓은 범위입니다:

```swift
// PackageA의 모듈 내부
package struct SharedConfig {
    package var apiEndpoint: String
    package var timeout: TimeInterval
}

// 같은 Package의 다른 모듈에서 접근 가능
// 다른 Package에서는 접근 불가
```

### Macro

Swift 5.9에서 도입된 매크로 시스템으로 컴파일 타임에 코드를 생성할 수 있습니다:

```swift
// 매크로 사용 예시
@Observable
class UserSettings {
    var name: String = ""
    var age: Int = 0
}

// #Preview 매크로 (SwiftUI)
#Preview {
    ContentView()
}

// 표준 라이브러리 매크로
let (a, b) = #expect(throws: ValidationError.self) {
    try validate(input)
}
```

---

## Swift 6.0에서 도입된 기능

### Strict Concurrency

Swift 6의 가장 큰 변화는 **Strict Concurrency Checking**이 기본으로 활성화된 것입니다.

#### 주요 변경

- **Data Race Safety가 기본**: 동시성 경계를 넘는 모든 데이터가 `Sendable`을 준수해야 합니다.
- **Global Actor 격리 강화**: `@MainActor` 등 Global Actor의 격리가 더 엄격하게 적용됩니다.
- **완전한 Actor 격리 검사**: 컴파일러가 모든 Actor 격리 위반을 에러로 보고합니다.

#### 마이그레이션 전략

```swift
// 1단계: Swift 5 모드에서 경고로 확인
// Build Settings → Swift Language Version → Swift 5
// Build Settings → Strict Concurrency Checking → Complete

// 2단계: 경고를 하나씩 수정

// 3단계: Swift 6 모드로 전환
// Build Settings → Swift Language Version → Swift 6
```

### Typed Throws

에러 타입을 명시할 수 있는 Typed Throws가 도입되었습니다:

```swift
enum ValidationError: Error {
    case tooShort
    case invalidFormat
}

func validate(_ input: String) throws(ValidationError) {
    guard input.count >= 3 else {
        throw .tooShort
    }
}

// 호출 측에서 에러 타입이 확정됨
do {
    try validate("ab")
} catch {
    // error의 타입이 ValidationError로 확정
    switch error {
    case .tooShort: print("너무 짧음")
    case .invalidFormat: print("형식 오류")
    }
}
```

### 기타 Swift 6.0 변경

- **C++ Interop 개선**: C++ 코드와의 상호 운용성이 향상되었습니다.
- **128비트 정수**: `Int128`, `UInt128` 타입이 표준 라이브러리에 추가되었습니다.

---

## Swift 6.1에서 도입된 기능

### `nonisolated(unsafe)` 개선

Swift 6.1에서는 `nonisolated(unsafe)`의 적용 범위가 개선되어, Sendable 검사를 우회해야 하는 경우 더 세밀한 제어가 가능해졌습니다:

```swift
class LegacyManager {
    // Sendable하지 않지만 실제로는 스레드 안전한 프로퍼티
    nonisolated(unsafe) var cache: NSCache<NSString, NSData> = .init()
}
```

### InlineArray

고정 크기 인라인 배열로, 힙 할당 없이 스택에 저장됩니다:

```swift
// 고정 크기 3의 인라인 배열
let rgb: InlineArray<3, UInt8> = [255, 128, 0]

// 성능이 중요한 경우 힙 할당을 피할 수 있음
struct Pixel {
    var channels: InlineArray<4, Float>  // RGBA
}
```

### `count(where:)`

컬렉션에서 조건을 만족하는 요소의 수를 직접 셀 수 있습니다:

```swift
let scores = [85, 92, 78, 95, 88, 72, 91]

// 기존 방식
let oldCount = scores.filter { $0 >= 90 }.count

// Swift 6.1: 중간 배열 생성 없이 효율적으로 카운트
let highScores = scores.count(where: { $0 >= 90 })
print(highScores) // 3
```

### 조건문에서 Trailing Comma 허용

`if`, `guard`, `while` 등의 조건 목록 끝에 후행 쉼표를 허용합니다:

```swift
// Swift 6.1부터 조건 끝에 쉼표를 허용
if
    let user = currentUser,
    user.isActive,
    user.hasPermission,  // 후행 쉼표 허용 — 조건 추가/제거 시 diff가 깔끔해짐
{
    grantAccess(to: user)
}
```

### `@retroactive` 개선

다른 모듈의 프로토콜 적합성을 명시적으로 표시하는 `@retroactive`가 개선되어, 경고 없이 외부 타입에 프로토콜 적합성을 추가할 수 있습니다:

```swift
// 외부 모듈의 타입에 프로토콜 적합성 추가 시
// @retroactive로 의도를 명확히 표시
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
```

### 기타 Swift 6.1 변경

- **`sending` 파라미터 추론 개선**: 클로저의 sending 특성이 더 정확하게 추론됩니다.
- **Task 격리 상속 개선**: Task가 부모의 격리 컨텍스트를 더 자연스럽게 상속합니다.
- **컴파일러 진단 개선**: 동시성 관련 에러 메시지가 더 명확해졌습니다.
