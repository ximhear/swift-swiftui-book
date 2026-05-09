# Chapter 4. 메모리 관리와 성능 최적화

> Swift의 ARC(Automatic Reference Counting)는 대부분의 메모리 관리를 자동으로 처리합니다. 하지만 "자동"이 "완벽"을 의미하지는 않습니다. 순환 참조를 넘어서, 레퍼런스 카운팅의 오버헤드, 의도치 않은 메모리 유지, 그리고 대용량 데이터를 위한 Copy-on-Write 최적화까지 — 이 장에서는 메모리를 정확히 이해하고 최적화하는 기법을 배웁니다.

---

## 4.1 ARC 심화: 순환 참조를 넘어서

### ARC의 동작 원리 복습

ARC는 각 참조 타입 인스턴스에 대해 **참조 카운트**를 관리합니다. 카운트가 0이 되면 메모리에서 해제합니다.

```swift
class Document {
    let title: String
    
    init(title: String) {
        self.title = title
        print("\(title) 생성")
    }
    
    deinit {
        print("\(title) 해제")
    }
}

func createDocument() {
    let doc = Document(title: "보고서")
    // 참조 카운트: 1
    
    let copy = doc
    // 참조 카운트: 2
    
    // copy가 스코프를 벗어남 → 참조 카운트: 1
    // doc이 스코프를 벗어남 → 참조 카운트: 0 → 해제
}
// 출력: "보고서 생성" → "보고서 해제"
```

### 레퍼런스 카운팅의 숨겨진 비용

🟡 중급

ARC의 retain/release 연산은 **원자적(atomic)**입니다. 멀티스레드 환경에서 안전하게 동작하기 위해 원자적 연산을 사용하며, 이는 일반 대입보다 비용이 높습니다.

```swift
// 참조 타입: 할당할 때마다 retain/release 발생
class Wrapper {
    var value: Int
    init(_ value: Int) { self.value = value }
}

func referenceOverhead() {
    let wrapper = Wrapper(42)
    
    for _ in 0..<1_000_000 {
        let temp = wrapper  // retain (+1)
        _ = temp.value
        // temp 해제: release (-1)
        // 매 반복마다 원자적 연산 2회
    }
}

// 값 타입: retain/release 없음
struct ValueWrapper {
    var value: Int
}

func valueEfficiency() {
    let wrapper = ValueWrapper(value: 42)
    
    for _ in 0..<1_000_000 {
        let temp = wrapper  // 단순 복사, 원자적 연산 없음
        _ = temp.value
    }
}
```

> **Note**: 컴파일러는 불필요한 retain/release를 최적화하여 제거합니다. 하지만 최적화가 불가능한 경우(예: 함수 호출 경계, 프로토콜 디스패치)에는 비용이 남습니다.

### Swift 객체의 메모리 구조

🔴 고급

ARC가 어떻게 동작하는지 정확히 이해하려면, Swift 클래스 인스턴스가 힙에 어떤 형태로 존재하는지 알아야 합니다. Swift의 모든 클래스 인스턴스는 **최소 16바이트의 헤더**를 가집니다.

```
┌──────────────────────────────────┐
│  Metadata Pointer (8 bytes)      │  ← isa 포인터: 타입 메타데이터를 가리킴
├──────────────────────────────────┤
│  Reference Count (8 bytes)       │  ← strong RC + unowned RC + 플래그 비트들
├──────────────────────────────────┤
│  Stored Property 1               │
│  Stored Property 2               │
│  ...                             │
└──────────────────────────────────┘
```

실제로 `class_getInstanceSize`를 사용하여 객체의 크기를 확인할 수 있습니다:

```swift
import Foundation

class Empty {}

class TwoInts {
    var a: Int = 0
    var b: Int = 0
}

class MixedProperties {
    var flag: Bool = false    // 1바이트 + 패딩
    var value: Int = 0        // 8바이트
    var ratio: Double = 0.0   // 8바이트
}

func printObjectSizes() {
    print(class_getInstanceSize(Empty.self))
    // 16 — 헤더만 (metadata 8B + refcount 8B)
    
    print(class_getInstanceSize(TwoInts.self))
    // 32 — 헤더 16B + Int 8B + Int 8B
    
    print(class_getInstanceSize(MixedProperties.self))
    // 40 — 헤더 16B + Bool 1B + 패딩 7B + Int 8B + Double 8B
}
```

이처럼 모든 클래스 인스턴스에는 16바이트 오버헤드가 존재합니다. 작은 데이터를 클래스로 감싸면 실제 데이터보다 헤더가 더 큰 상황이 발생합니다. 이것이 "작은 데이터에는 값 타입을 사용하라"는 조언의 구체적인 근거입니다.

### Side Table과 참조 카운트의 3단계 구조

🔴 고급

Swift의 참조 카운팅은 단순한 정수 하나가 아닙니다. 왜 이것이 중요한가? `weak` 참조가 어떻게 대상이 해제된 후에도 안전하게 `nil`을 반환할 수 있는지, 그 메커니즘을 이해하면 `weak`과 `unowned`의 성능 차이를 정량적으로 판단할 수 있습니다.

Swift의 참조 카운트는 **3단계 구조**로 동작합니다:

1. **Strong Reference Count**: 강한 참조의 수. 0이 되면 `deinit`이 호출되고 저장 프로퍼티가 해제됩니다.
2. **Unowned Reference Count**: unowned 참조의 수 + 1(strong이 0이 아닌 한). 0이 되면 객체의 메모리가 실제로 해제됩니다.
3. **Weak Reference Count**: weak 참조의 수 + 1. side table에 저장됩니다.

```
── Strong RC가 0이 아닌 상태 (정상) ──

객체 헤더:
┌─────────────────────────────────────────────┐
│ [strong RC | unowned RC | 플래그 비트들]     │  ← 인라인 refcount (8B)
└─────────────────────────────────────────────┘

── weak 참조가 처음 생기면 Side Table 생성 ──

객체 헤더:                    Side Table:
┌──────────────────┐         ┌──────────────────┐
│ side table 포인터 │ ──────→ │ strong RC         │
└──────────────────┘         │ unowned RC        │
                             │ weak RC           │
                             │ 객체 포인터        │
                             └──────────────────┘
```

**Side Table**은 `weak` 참조가 처음 생성될 때 별도로 힙에 할당되는 보조 구조체입니다. 객체가 `deinit`된 후에도 side table은 남아있어, `weak` 참조가 접근했을 때 "이미 해제됨"을 알려주고 `nil`을 반환할 수 있습니다. 모든 `weak` 참조가 사라져야 비로소 side table도 해제됩니다.

이 구조 때문에:
- `unowned`는 객체 헤더에 직접 접근하므로 빠릅니다 (추가 간접 참조 없음).
- `weak`는 side table을 경유하므로 한 단계 추가 간접 참조가 필요하고, side table 할당 비용도 있습니다.
- 객체가 `deinit`된 후에도 `unowned` 참조가 남아 있으면 메모리 해제가 지연됩니다 (unowned RC가 0이 되어야 해제).

### ARC 최적화 — retain/release 제거

🔴 고급

Swift 컴파일러는 불필요한 retain/release 쌍을 적극적으로 제거합니다. 왜 이것을 알아야 하는가? 컴파일러가 최적화할 수 있는 패턴과 그렇지 않은 패턴을 구분하면, 성능에 민감한 코드를 작성할 때 더 나은 설계 결정을 내릴 수 있습니다.

주요 최적화 케이스:

**1. Guaranteed Parameter (빌려주기)**

함수의 매개변수로 참조 타입을 전달할 때, Swift는 기본적으로 `+0` 컨벤션(빌려주기)을 사용합니다. 호출자가 이미 참조를 보유하고 있으므로 callee에서 추가로 retain할 필요가 없습니다.

```swift
class Data {
    var buffer: [UInt8] = []
}

func process(data: Data) {
    // 'data'는 guaranteed parameter — retain/release 없음
    // 이 함수 실행 중에 호출자가 data의 참조를 유지하므로 안전
    print(data.buffer.count)
}

let myData = Data()
process(data: myData)
// myData가 스코프에 있으므로 process() 내에서 retain 불필요
```

**2. Owned Return (소유권 이전)**

함수가 새로 생성한 객체를 반환할 때, retain 없이 소유권을 직접 이전합니다.

```swift
func createDocument() -> Document {
    let doc = Document(title: "새 문서")
    return doc  // retain 없이 소유권 이전 (+1 → 호출자에게)
}

let doc = createDocument()
// doc의 참조 카운트는 1 — 불필요한 retain/release 없음
```

**3. 로컬 변수 최적화**

컴파일러가 변수의 전체 수명을 추적할 수 있는 경우, retain/release를 완전히 제거합니다.

```swift
func localOptimization() {
    let obj = MyClass()      // 생성: RC = 1
    let alias = obj          // 컴파일러가 retain 생략 가능
    print(alias)
    // 함수 끝에서 release 1회만 실행
}
```

### 참조 카운트 관찰하기

실제 참조 카운트를 관찰하면 ARC의 동작을 직관적으로 이해할 수 있습니다:

```swift
import Foundation

class Sample {
    var name: String
    init(name: String) { self.name = name }
}

func observeRetainCount() {
    let obj = Sample(name: "테스트")
    
    // CFGetRetainCount — Objective-C 런타임 기반 (정확하지 않을 수 있음)
    print(CFGetRetainCount(obj))  // 2 (내부적으로 +1 된 값이 반환됨)
    
    let ref2 = obj
    print(CFGetRetainCount(ref2)) // 3
    
    // Swift 내부 함수로 관찰 (디버깅 용도)
    // _swift_retainCount는 공개 API가 아니므로 프로덕션에서 사용하지 마세요
    
    weak var weakRef = obj
    print(CFGetRetainCount(obj))  // strong count는 변하지 않음
    
    _ = ref2  // 컴파일러 최적화 방지
}
```

> **주의**: `CFGetRetainCount`는 디버깅 참고용입니다. 컴파일러 최적화로 인해 실제 값이 예상과 다를 수 있으며, 프로덕션 코드에서 이 값에 의존하면 안 됩니다. Apple 공식 문서에서도 "디버깅 이외의 목적으로 사용하지 말 것"을 명시하고 있습니다.

### 의도치 않은 메모리 유지 — 클로저 캡처

순환 참조가 아니어도 **의도보다 오래 메모리가 유지**되는 경우가 있습니다:

```swift
class DataProcessor {
    var data: [Int] = Array(repeating: 0, count: 100_000)
    
    func processAsync() {
        // ❌ self 전체가 캡처됨 → data도 유지됨
        DispatchQueue.global().async {
            let count = self.data.count
            print("처리 완료: \(count)건")
        }
    }
    
    func processAsyncBetter() {
        // ✅ 필요한 값만 캡처
        let count = data.count
        DispatchQueue.global().async {
            print("처리 완료: \(count)건")
        }
    }
}
```

```swift
// SwiftUI에서 흔한 실수
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    // ❌ Timer가 self를 강하게 캡처
    func startAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: 30,
                             repeats: true) { _ in
            Task {
                await self.refresh()  // self 강한 참조
            }
        }
    }
    
    // ✅ weak self 사용
    func startAutoRefreshSafe() {
        Timer.scheduledTimer(withTimeInterval: 30,
                             repeats: true) { [weak self] _ in
            Task {
                await self?.refresh()
            }
        }
    }
}
```

---

## 4.2 weak vs unowned — 선택 기준

### weak: 안전하지만 비용이 있다

`weak` 참조는 참조 대상이 해제되면 자동으로 `nil`이 됩니다. 안전하지만 옵셔널로 다뤄야 합니다.

```swift
class Parent {
    var child: Child?
    let name: String
    
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

class Child {
    weak var parent: Parent?  // 순환 참조 방지
    let name: String
    
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

func demonstrateWeak() {
    let parent = Parent(name: "부모")
    let child = Child(name: "자식")
    
    parent.child = child
    child.parent = parent
    
    // 두 객체 모두 정상적으로 해제됨
}
```

### unowned: 빠르지만 위험할 수 있다

`unowned`는 참조 대상이 해제되어도 `nil`이 되지 않습니다. 해제된 후 접근하면 **런타임 크래시**가 발생합니다.

```swift
class Customer {
    var card: CreditCard?
    let name: String
    
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

class CreditCard {
    // 카드는 항상 고객이 존재할 때만 유효
    unowned let owner: Customer
    let number: String
    
    init(owner: Customer, number: String) {
        self.owner = owner
        self.number = number
    }
    deinit { print("카드 \(number) 해제") }
}
```

### 선택 기준 정리

| 기준 | `weak` | `unowned` |
|------|--------|-----------|
| 참조 대상의 수명 | 나보다 먼저 해제될 수 있음 | 나보다 같거나 오래 삶 |
| 타입 | Optional (`T?`) | Non-optional (`T`) |
| 해제 후 접근 | `nil` 반환 | 크래시 |
| 성능 | side table 접근 비용 | 직접 접근, 약간 빠름 |
| 사용 빈도 | 대부분의 경우 | 수명이 보장될 때만 |

```swift
// 실무 가이드:
// 1. 기본적으로 weak을 사용
// 2. 다음 조건을 모두 만족할 때만 unowned:
//    - 참조 대상의 수명이 나와 같거나 긺이 확실
//    - 옵셔널 언래핑 비용을 피하고 싶음
//    - 코드가 더 깔끔해짐

// 대표적인 unowned 사용: 클로저에서 self
class NetworkManager {
    var onComplete: (() -> Void)?
    
    func fetch() {
        // self가 fetch 도중 해제될 가능성이 있음
        onComplete = { [weak self] in
            self?.handleComplete()
        }
        
        // self가 onComplete보다 오래 삶이 보장됨
        // (예: 동기적으로 호출되는 경우)
        let processor = DataProcessor()
        processor.process { [unowned self] result in
            self.handleResult(result)
        }
    }
}
```

---

## 4.3 Instruments를 활용한 메모리 프로파일링

### Xcode Memory Graph Debugger

가장 먼저 사용해볼 도구는 Xcode에 내장된 **Memory Graph Debugger**입니다.

1. 앱을 디버그 모드로 실행
2. 디버그 바에서 메모리 그래프 아이콘(세 개의 연결된 원) 클릭
3. 현재 메모리에 있는 모든 객체와 참조 관계를 시각적으로 확인

[그림: Xcode Memory Graph Debugger 스크린샷 — 순환 참조가 보라색 경고로 표시됨]

### Instruments: Allocations

메모리 할당 패턴을 분석하려면 Instruments의 **Allocations** 도구를 사용합니다.

주요 확인 사항:
- **All Heap Allocations**: 힙에 할당된 모든 객체
- **Persistent**: 아직 해제되지 않은 객체 수
- **Growth**: 시간에 따른 메모리 증가량
- **Transient**: 생성 후 이미 해제된 객체 수

```swift
// 메모리 누수를 유발하는 코드 예시
class ImageGallery {
    var images: [UIImage] = []
    var onImageLoaded: ((UIImage) -> Void)?
    
    func loadImages(urls: [URL]) {
        for url in urls {
            // ❌ self를 강하게 캡처하는 클로저를 저장
            let loader = ImageLoader(url: url)
            loader.onComplete = { image in
                self.images.append(image)
                self.onImageLoaded?(image)
            }
            loader.start()
        }
    }
}
```

### Instruments: Leaks

**Leaks** 도구는 순환 참조를 자동으로 탐지합니다.

확인 순서:
1. Product → Profile (⌘I)로 Instruments 실행
2. Leaks 템플릿 선택
3. 앱을 사용하며 화면 전환, 기능 실행
4. Leaks 목록에서 누수된 객체의 참조 그래프 확인

### 실전 디버깅: 일반적인 메모리 문제 패턴

🟡 중급

**패턴 1: 클로저 순환 참조**

```swift
// 진단: deinit이 호출되지 않음
class SearchController {
    var searchResults: [String] = []
    var debounceTimer: Timer?
    
    deinit { print("SearchController 해제") }  // 호출 안 됨!
    
    func setupSearch() {
        // ❌ Timer가 self를 강하게 캡처
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: true
        ) { _ in
            self.performSearch()
        }
    }
    
    // ✅ 수정: weak self
    func setupSearchFixed() {
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: true
        ) { [weak self] _ in
            self?.performSearch()
        }
    }
    
    func performSearch() { /* ... */ }
}
```

**패턴 2: delegate 순환 참조**

```swift
protocol DataSourceDelegate: AnyObject {
    func didLoadData(_ data: [String])
}

class DataSource {
    // ❌ 강한 참조: 순환 참조 위험
    // var delegate: DataSourceDelegate?
    
    // ✅ weak으로 선언
    weak var delegate: DataSourceDelegate?
}
```

**패턴 3: NotificationCenter 관찰자 누수**

```swift
class EventListener {
    private var observations: [NSObjectProtocol] = []
    
    func startListening() {
        // ✅ 관찰자 저장 후 deinit에서 해제
        let obs = NotificationCenter.default.addObserver(
            forName: .dataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleUpdate(notification)
        }
        observations.append(obs)
    }
    
    deinit {
        observations.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }
    
    func handleUpdate(_ notification: Notification) { }
}

extension Notification.Name {
    static let dataDidUpdate = Notification.Name("dataDidUpdate")
}
```

---

## 4.4 Copy-on-Write 커스텀 구현

1장에서 COW의 기본 개념을 다뤘습니다. 이 절에서는 실무에서 사용할 수 있는 **완성도 높은 COW 구현**을 만들어봅니다.

### 범용 COW 래퍼

🔴 고급

```swift
/// 임의의 참조 타입을 COW로 감싸는 범용 래퍼
@propertyWrapper
struct CopyOnWrite<Value: AnyObject & NSCopying> {
    private var storage: Value
    
    init(wrappedValue: Value) {
        storage = wrappedValue
    }
    
    var wrappedValue: Value {
        get { storage }
        set { storage = newValue }
    }
    
    /// 변경이 필요할 때 호출 — 유일한 참조가 아니면 복사
    var projectedValue: Value {
        mutating get {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy() as! Value
            }
            return storage
        }
    }
}
```

### 실전 예: 대용량 이미지 편집기

🔴 고급

```swift
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
        let pixelCount = width * height * 4 // RGBA
        storage = Storage(
            pixels: Array(repeating: 0, count: pixelCount),
            width: width,
            height: height
        )
    }
    
    // 읽기 전용 — 복사 없음
    var width: Int { storage.width }
    var height: Int { storage.height }
    var layerCount: Int { storage.layers.count }
    
    func pixel(at x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let offset = (y * storage.width + x) * 4
        return (
            storage.pixels[offset],
            storage.pixels[offset + 1],
            storage.pixels[offset + 2],
            storage.pixels[offset + 3]
        )
    }
    
    // 쓰기 — 필요시 복사
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
        // 변경 전 상태를 undo 스택에 저장
        storage.undoStack.append(storage.pixels)
        
        for i in stride(from: 0,
                        to: storage.pixels.count,
                        by: 4) {
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
        guard let previous = storage.undoStack.popLast() else {
            return false
        }
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

struct Layer {
    var name: String
    var opacity: Double
    var isVisible: Bool
}
```

### COW 성능 검증

```swift
func verifyCOWBehavior() {
    var doc1 = ImageDocument(width: 1920, height: 1080)
    
    // 할당만으로는 복사 없음
    var doc2 = doc1
    // doc1과 doc2는 같은 Storage를 공유
    
    // doc2 수정 시 비로소 복사 발생
    doc2.setPixel(at: 0, y: 0, r: 255, g: 0, b: 0)
    // doc1의 Storage는 변경되지 않음
    
    let original = doc1.pixel(at: 0, y: 0)
    assert(original.r == 0)  // 원본 안전
}
```

---

## 4.5 Unsafe 포인터와 로우 레벨 메모리

🔴 고급

Swift는 안전한 언어이지만, C 라이브러리와의 상호운용이나 극한의 성능 최적화가 필요할 때 **안전하지 않은(unsafe) 메모리 접근**을 허용합니다. 왜 이것이 중요한가? 이미지 처리, 네트워크 패킷 파싱, 오디오 버퍼 조작 등 성능에 민감한 영역에서는 Swift의 안전성 검사 비용을 제거해야 할 때가 있습니다. 또한 C/C++ 라이브러리를 Swift에서 사용하려면 포인터 변환을 피할 수 없습니다.

### UnsafePointer 계열 타입 정리

Swift는 네 가지 주요 unsafe 포인터 타입을 제공합니다:

| 타입 | 변경 가능 | 타입 정보 | 용도 |
|------|-----------|-----------|------|
| `UnsafePointer<T>` | 읽기 전용 | 타입 있음 | C `const T*`에 대응 |
| `UnsafeMutablePointer<T>` | 읽기/쓰기 | 타입 있음 | C `T*`에 대응 |
| `UnsafeRawPointer` | 읽기 전용 | 타입 없음 | C `const void*`에 대응 |
| `UnsafeMutableRawPointer` | 읽기/쓰기 | 타입 없음 | C `void*`에 대응 |
| `UnsafeBufferPointer<T>` | 읽기 전용 | 타입 있음 | 연속 메모리 영역 + 길이 정보 |
| `UnsafeMutableBufferPointer<T>` | 읽기/쓰기 | 타입 있음 | 연속 메모리 영역 + 길이 정보 |

```swift
func unsafePointerBasics() {
    // UnsafeMutablePointer: 타입이 있는 변경 가능한 포인터
    let count = 5
    let pointer = UnsafeMutablePointer<Int>.allocate(capacity: count)
    pointer.initialize(repeating: 0, count: count)
    
    // 개별 요소 접근
    pointer[0] = 42
    pointer[1] = 100
    print(pointer[0])  // 42
    
    // 포인터 산술
    let second = pointer.advanced(by: 1)
    print(second.pointee)  // 100
    
    // 반드시 해제해야 합니다 — ARC가 관리하지 않음
    pointer.deinitialize(count: count)
    pointer.deallocate()
}
```

```swift
// UnsafeBufferPointer: 연속 메모리 + 길이 정보 (Sequence 프로토콜 준수)
func bufferPointerExample() {
    let array = [10, 20, 30, 40, 50]
    
    array.withUnsafeBufferPointer { buffer in
        // buffer.count == 5
        // buffer[0] == 10
        // for-in 루프 가능
        for element in buffer {
            print(element)
        }
        
        // baseAddress로 raw pointer 접근
        if let base = buffer.baseAddress {
            let third = base.advanced(by: 2)
            print(third.pointee)  // 30
        }
    }
}
```

### withUnsafePointer / withUnsafeBytes — 안전한 사용 패턴

Unsafe 포인터를 가장 안전하게 사용하는 방법은 `with~` 계열 클로저 안에서만 사용하는 것입니다. 클로저가 끝나면 포인터가 자동으로 무효화되므로 댕글링 포인터 위험이 줄어듭니다.

```swift
func safeUnsafePatterns() {
    var value: Int64 = 0x0102030405060708
    
    // withUnsafePointer: 값의 메모리에 직접 접근
    withUnsafePointer(to: &value) { pointer in
        print(pointer.pointee)  // 72623859790382856
    }
    // 이 시점에서 pointer는 더 이상 유효하지 않음
    
    // withUnsafeBytes: 바이트 단위로 메모리 접근
    withUnsafeBytes(of: &value) { rawBuffer in
        // rawBuffer: UnsafeRawBufferPointer
        print("바이트 수: \(rawBuffer.count)")  // 8
        for byte in rawBuffer {
            print(String(format: "%02x", byte), terminator: " ")
        }
        // 리틀 엔디안: 08 07 06 05 04 03 02 01
        print()
    }
    
    // Data와의 변환
    let data = withUnsafeBytes(of: &value) { Data($0) }
    print(data.count)  // 8
}
```

```swift
// ❌ 위험: 클로저 밖으로 포인터를 반환하지 마세요
func dangerousPattern() -> UnsafePointer<Int>? {
    var value = 42
    // 이 포인터는 클로저가 끝나면 무효화됩니다
    var escaped: UnsafePointer<Int>?
    withUnsafePointer(to: &value) { ptr in
        escaped = ptr  // ❌ 댕글링 포인터!
    }
    return escaped  // 이미 무효한 포인터
}

// ✅ 안전: 클로저 안에서 필요한 작업을 완료하세요
func safePattern() -> Int {
    var value = 42
    return withUnsafePointer(to: &value) { ptr in
        ptr.pointee * 2  // 값을 복사하여 반환
    }
}
```

### ManagedBuffer — 커스텀 참조 카운팅 버퍼

`ManagedBuffer`는 헤더와 연속된 요소 배열을 하나의 힙 할당으로 관리하는 저수준 타입입니다. Swift의 `Array`도 내부적으로 유사한 패턴을 사용합니다. 대량의 동일 타입 요소를 저장하면서 메타데이터(헤더)도 함께 두고 싶을 때 유용합니다.

```swift
/// 간단한 링 버퍼 구현 — ManagedBuffer 활용
final class RingBuffer<Element> {
    struct Header {
        var count: Int
        var head: Int      // 읽기 위치
        var tail: Int      // 쓰기 위치
        var capacity: Int
    }
    
    private var storage: ManagedBuffer<Header, Element>
    
    init(capacity: Int) {
        storage = ManagedBuffer<Header, Element>.create(
            minimumCapacity: capacity
        ) { buffer in
            Header(
                count: 0,
                head: 0,
                tail: 0,
                capacity: buffer.capacity  // 실제 할당된 용량
            )
        }
    }
    
    var count: Int { storage.header.count }
    var isEmpty: Bool { storage.header.count == 0 }
    var isFull: Bool { storage.header.count == storage.header.capacity }
    
    func enqueue(_ element: Element) -> Bool {
        guard !isFull else { return false }
        
        storage.withUnsafeMutablePointerToElements { elements in
            (elements + storage.header.tail).initialize(to: element)
        }
        storage.header.tail = (storage.header.tail + 1) % storage.header.capacity
        storage.header.count += 1
        return true
    }
    
    func dequeue() -> Element? {
        guard !isEmpty else { return nil }
        
        let element = storage.withUnsafeMutablePointerToElements { elements in
            let el = (elements + storage.header.head).move()
            return el
        }
        storage.header.head = (storage.header.head + 1) % storage.header.capacity
        storage.header.count -= 1
        return element
    }
    
    deinit {
        // 남아있는 요소들을 정리
        storage.withUnsafeMutablePointerToElements { elements in
            var idx = storage.header.head
            for _ in 0..<storage.header.count {
                (elements + idx).deinitialize(count: 1)
                idx = (idx + 1) % storage.header.capacity
            }
        }
    }
}
```

`ManagedBuffer`의 핵심 장점은 **단일 힙 할당**입니다. 헤더와 요소 배열이 같은 메모리 블록에 위치하므로 캐시 효율이 좋고, 할당/해제 횟수가 줄어듭니다.

### 메모리 정렬(Alignment)

메모리 정렬은 데이터가 메모리에서 특정 바이트 경계에 위치하도록 하는 것입니다. 왜 중요한가? CPU는 정렬된 주소에서 데이터를 더 효율적으로 읽습니다. 정렬되지 않은 접근은 추가 CPU 사이클이 필요하거나, 일부 아키텍처에서는 크래시를 유발합니다.

```swift
func memoryLayoutExamples() {
    // MemoryLayout<T>으로 크기, 정렬, stride 확인
    print(MemoryLayout<Bool>.size)       // 1
    print(MemoryLayout<Bool>.alignment)  // 1
    print(MemoryLayout<Bool>.stride)     // 1
    
    print(MemoryLayout<Int>.size)        // 8
    print(MemoryLayout<Int>.alignment)   // 8
    print(MemoryLayout<Int>.stride)      // 8
    
    print(MemoryLayout<Double>.size)     // 8
    print(MemoryLayout<Double>.alignment) // 8
    print(MemoryLayout<Double>.stride)   // 8
    
    // 구조체 패딩 관찰
    struct BadLayout {
        var a: Bool    // 1바이트
        // 7바이트 패딩 (b의 정렬 요구사항을 맞추기 위해)
        var b: Int     // 8바이트
        var c: Bool    // 1바이트
        // 7바이트 패딩 (stride를 맞추기 위해)
    }
    print(MemoryLayout<BadLayout>.size)      // 24
    print(MemoryLayout<BadLayout>.stride)    // 24
    print(MemoryLayout<BadLayout>.alignment) // 8
    
    // 필드 순서를 바꾸면 패딩이 줄어듦
    // (Swift 컴파일러가 자동으로 재배치하지 않음 — C와 동일)
    struct GoodLayout {
        var b: Int     // 8바이트
        var a: Bool    // 1바이트
        var c: Bool    // 1바이트
        // 6바이트 패딩
    }
    print(MemoryLayout<GoodLayout>.size)      // 10
    print(MemoryLayout<GoodLayout>.stride)    // 16
    print(MemoryLayout<GoodLayout>.alignment) // 8
}
```

> **Tip**: `size`는 실제 데이터가 차지하는 바이트 수, `stride`는 배열에서 연속된 요소 사이의 간격(패딩 포함), `alignment`는 시작 주소가 만족해야 하는 배수입니다. 성능에 민감한 구조체는 필드 순서를 정렬 크기 내림차순으로 배치하면 패딩을 줄일 수 있습니다.

### 실전 예제: C 라이브러리 Interop에서 포인터 변환

Swift에서 C 라이브러리를 호출할 때 가장 빈번하게 마주치는 포인터 변환 패턴들입니다:

```swift
import Foundation

// 패턴 1: Data → UnsafeRawPointer (C 함수에 바이트 버퍼 전달)
func sendToC(data: Data) {
    data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        // C 함수 호출: void process_buffer(const void *buf, size_t len)
        // process_buffer(baseAddress, rawBuffer.count)
        _ = baseAddress  // 예시용
    }
}

// 패턴 2: 구조체를 바이트로 직렬화
struct PacketHeader {
    var version: UInt8
    var type: UInt8
    var length: UInt16
    var sequence: UInt32
}

func serializeHeader(_ header: PacketHeader) -> Data {
    var mutableHeader = header
    return withUnsafeBytes(of: &mutableHeader) { Data($0) }
}

func deserializeHeader(from data: Data) -> PacketHeader? {
    guard data.count >= MemoryLayout<PacketHeader>.size else { return nil }
    return data.withUnsafeBytes { rawBuffer in
        rawBuffer.load(as: PacketHeader.self)
    }
}

// 패턴 3: rebind — 타입이 다른 포인터 간 변환
func reinterpretExample() {
    var floatValue: Float = 3.14
    let intBits = withUnsafePointer(to: &floatValue) { floatPtr in
        floatPtr.withMemoryRebound(to: UInt32.self, capacity: 1) { intPtr in
            intPtr.pointee
        }
    }
    print(String(format: "0x%08x", intBits))  // 0x4048f5c3
    // IEEE 754 부동소수점의 비트 패턴 확인
}
```

> **경고**: Unsafe 포인터 사용 시 메모리 안전성은 프로그래머의 책임입니다. `allocate`한 메모리는 반드시 `deallocate`하고, `initialize`한 메모리는 반드시 `deinitialize`해야 합니다. 이를 어기면 메모리 누수나 정의되지 않은 동작이 발생합니다.

---

## 4.6 컴파일러 최적화와 성능 분석

🔴 고급

Swift 코드의 성능은 컴파일러 최적화 수준에 따라 **수 배에서 수십 배**까지 달라질 수 있습니다. 왜 이것이 중요한가? 디버그 빌드에서 "느리다"고 느낀 코드가 릴리스 빌드에서는 충분히 빠를 수 있고, 반대로 릴리스 빌드에서도 최적화가 적용되지 않는 패턴이 있습니다. 최적화 동작을 이해하면 불필요한 수동 최적화를 피하고, 정말 필요한 곳에 집중할 수 있습니다.

### 최적화 레벨

Swift 컴파일러(`swiftc`)는 네 가지 최적화 레벨을 제공합니다:

| 플래그 | 이름 | 효과 |
|--------|------|------|
| `-Onone` | 최적화 없음 | 디버그 빌드 기본값. 모든 안전성 검사 포함. 가장 느림 |
| `-O` | 최적화 | 릴리스 빌드 기본값. 인라이닝, 특수화, ARC 최적화 등 |
| `-Osize` | 크기 최적화 | `-O`와 유사하지만 바이너리 크기를 우선 최적화 |
| `-Ounchecked` | 안전성 검사 제거 | `-O` + 배열 범위 검사, 오버플로 검사 등 제거. 위험 |

```swift
// -Onone vs -O 차이가 극적인 예
func sumArray(_ array: [Int]) -> Int {
    var sum = 0
    for element in array {
        sum += element
    }
    return sum
}

// 벤치마크 코드
func benchmark() {
    let array = Array(1...1_000_000)
    
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<100 {
        _ = sumArray(array)
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    
    print("소요 시간: \(elapsed)초")
    // -Onone: ~3.5초 (retain/release, 범위 검사, 디스패치 오버헤드)
    // -O:     ~0.05초 (인라이닝 + 벡터화 + 불필요한 검사 제거)
    // 약 70배 차이!
}
```

> **중요**: `-Ounchecked`는 배열 인덱스 범위 초과 시 크래시 대신 정의되지 않은 동작을 유발합니다. 프로덕션 코드에서는 `-O`를 사용하세요. `-Ounchecked`는 성능 벤치마크에서 "안전성 검사 비용이 얼마인가"를 측정할 때만 유용합니다.

### Whole Module Optimization (WMO)

기본적으로 Swift 컴파일러는 파일 단위로 컴파일합니다. **WMO**를 활성화하면 모듈 내 모든 파일을 한 번에 분석하여 파일 경계를 넘는 최적화를 수행합니다.

WMO가 가능하게 하는 최적화:
- **교차 파일 인라이닝**: 다른 파일에 정의된 함수도 인라이닝
- **교차 파일 제네릭 특수화**: 다른 파일의 제네릭 함수를 구체 타입으로 특수화
- **internal 접근 제어 활용**: `internal`(기본값)인 클래스를 `final`로 추론하여 가상 디스패치 제거

```swift
// FileA.swift
class Animal {
    func speak() -> String { "..." }
}

// FileB.swift
func makeAnimalSpeak(_ animal: Animal) -> String {
    animal.speak()  // 가상 디스패치 (vtable lookup)
}
```

파일 단위 컴파일에서는 `Animal`이 서브클래싱될 수 있으므로 가상 디스패치가 필요합니다. 하지만 WMO에서는 모듈 전체를 분석한 결과 `Animal`의 서브클래스가 없다면, `speak()`를 직접 호출(또는 인라이닝)할 수 있습니다.

Xcode에서 설정: Build Settings → Swift Compiler - Code Generation → Compilation Mode → **Whole Module**

### @inlinable / @usableFromInline

라이브러리(프레임워크, Swift Package)를 개발할 때, 함수 본문은 기본적으로 모듈 외부에 공개되지 않습니다. 즉, 외부 모듈에서 호출할 때 인라이닝이 불가능합니다. `@inlinable`을 사용하면 함수 본문을 모듈 인터페이스에 포함시켜 호출 측에서 인라이닝할 수 있게 합니다.

```swift
// MyLibrary 모듈
public struct Vector2D {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    // @inlinable: 호출하는 모듈에서 인라이닝 가능
    @inlinable
    public func length() -> Double {
        (x * x + y * y).squareRoot()
    }
    
    // @usableFromInline: @inlinable 함수 내에서 사용할 수 있지만
    // 직접 public은 아닌 내부 구현
    @usableFromInline
    internal func dotProduct(with other: Vector2D) -> Double {
        x * other.x + y * other.y
    }
    
    @inlinable
    public func angle(to other: Vector2D) -> Double {
        let dot = dotProduct(with: other)
        return (dot / (length() * other.length())).clamped(to: -1...1)
    }
}

extension Comparable {
    @inlinable
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

**트레이드오프**:
- 장점: 호출 측에서 인라이닝 → 함수 호출 오버헤드 제거, 추가 최적화 기회
- 단점: 함수 본문이 ABI의 일부가 됨 → 구현 변경 시 재컴파일 필요
- 가이드: 작고 성능에 민감한 함수(수학 연산, 간단한 접근자)에만 사용

### ContiguousArray vs Array

Swift의 `Array`는 Objective-C의 `NSArray`와 브리징될 수 있도록 설계되어 있습니다. 이 브리징 가능성 자체가 약간의 오버헤드를 유발합니다. 요소 타입이 클래스이거나 `@objc` 프로토콜일 때, `Array`는 내부적으로 `NSArray`와 공유 가능한 버퍼를 사용합니다.

`ContiguousArray`는 이 브리징 계층을 완전히 제거합니다:

```swift
import Foundation

// Array<NSObject>: NSArray와 브리징 가능 → 약간의 오버헤드
// ContiguousArray<NSObject>: 브리징 불가 → 순수 Swift 성능

class MyObject: NSObject {
    var value: Int
    init(value: Int) {
        self.value = value
        super.init()
    }
}

func benchmarkArrayTypes() {
    let count = 100_000
    
    // Array — NSArray 브리징 가능
    var array = Array<MyObject>()
    array.reserveCapacity(count)
    let start1 = CFAbsoluteTimeGetCurrent()
    for i in 0..<count {
        array.append(MyObject(value: i))
    }
    let elapsed1 = CFAbsoluteTimeGetCurrent() - start1
    
    // ContiguousArray — 브리징 없음
    var contiguous = ContiguousArray<MyObject>()
    contiguous.reserveCapacity(count)
    let start2 = CFAbsoluteTimeGetCurrent()
    for i in 0..<count {
        contiguous.append(MyObject(value: i))
    }
    let elapsed2 = CFAbsoluteTimeGetCurrent() - start2
    
    print("Array:           \(elapsed1)초")
    print("ContiguousArray: \(elapsed2)초")
    // 클래스 타입에서 ContiguousArray가 약 10-30% 빠를 수 있음
}
```

> **Tip**: 요소 타입이 `struct`처럼 non-class 타입이면 `Array`와 `ContiguousArray`의 성능 차이가 없습니다. 클래스 타입 배열에서 Objective-C 브리징이 필요 없다면 `ContiguousArray`를 사용하세요.

### lazy 컬렉션 연산

컬렉션의 `map`, `filter`, `reduce` 체인은 각 단계마다 **중간 배열**을 생성합니다. `lazy`를 사용하면 실제로 요소가 필요한 시점까지 연산을 지연시켜 중간 배열 생성을 방지합니다.

```swift
// ❌ 중간 배열 2개 생성
func eagerProcessing(data: [Int]) -> [String] {
    return data
        .filter { $0 % 2 == 0 }     // 중간 배열 1 생성
        .map { "값: \($0)" }         // 중간 배열 2 생성
}

// ✅ 중간 배열 없음 — 최종 결과만 배열로 변환
func lazyProcessing(data: [Int]) -> [String] {
    return Array(data.lazy
        .filter { $0 % 2 == 0 }     // LazyFilterSequence (배열 아님)
        .map { "값: \($0)" })        // LazyMapSequence → 마지막에 한 번만 배열 생성
}
```

`lazy`가 특히 효과적인 상황:

```swift
// 1. 대량 데이터에서 처음 몇 개만 필요한 경우
func firstThreeExpensiveResults(data: [Int]) -> [Int] {
    return Array(data.lazy
        .map { expensiveTransform($0) }     // 필요한 것만 변환
        .filter { $0 > threshold }           // 필요한 것만 필터
        .prefix(3))                          // 3개 찾으면 중단!
}

// 2. 체인이 긴 경우 — 중간 배열 수에 비례하여 절약
func longChain(data: [Int]) -> [Int] {
    return Array(data.lazy
        .filter { $0 > 0 }
        .map { $0 * 2 }
        .filter { $0 < 1000 }
        .map { $0 + 1 })
    // eager: 중간 배열 4개 vs lazy: 중간 배열 0개
}

func expensiveTransform(_ value: Int) -> Int { value * value }
let threshold = 100
```

> **주의**: `lazy`는 매번 재계산하므로, 같은 요소를 여러 번 접근하면 오히려 느려질 수 있습니다. `lazy`는 "한 번 순회"하는 패턴에 적합합니다.

---

## 4.7 String 내부 구조

🔴 고급

문자열은 Swift에서 가장 빈번하게 사용되는 타입 중 하나이지만, 내부 구조를 모르면 성능 함정에 빠지기 쉽습니다. 왜 이것이 중요한가? JSON 파싱, 로그 처리, 텍스트 검색 등 문자열 집약적인 작업에서 O(1)이라고 가정한 연산이 실제로는 O(n)인 경우가 빈번합니다.

### Small String Optimization

Swift의 `String`은 **15바이트 이하의 문자열을 힙 할당 없이 인라인으로 저장**합니다. 이를 Small String Optimization(SSO)이라 합니다.

```swift
func stringMemoryLayout() {
    print(MemoryLayout<String>.size)      // 16
    print(MemoryLayout<String>.stride)    // 16
    print(MemoryLayout<String>.alignment) // 8
    
    // String은 항상 16바이트를 차지합니다.
    // 작은 문자열: 16바이트 안에 내용물이 직접 저장됨 (힙 할당 없음)
    // 큰 문자열: 16바이트 안에 힙 버퍼를 가리키는 포인터와 메타데이터 저장
}
```

```
Small String (15바이트 이하):
┌──────────────────────────────────────────────────┐
│ [문자 데이터 ... 최대 15바이트] │ count + 플래그   │
│                                │ (1바이트)        │
└──────────────────────────────────────────────────┘
                   총 16바이트 (스택/인라인)

Large String:
┌──────────────────────────────────────────────────┐
│ [버퍼 포인터 (8바이트)] │ [count + 플래그 (8바이트)] │
└──────────────────────────────────────────────────┘
        │                  총 16바이트
        ▼
   ┌────────────────────────┐
   │ 힙에 할당된 UTF-8 버퍼  │
   └────────────────────────┘
```

```swift
func smallStringDemo() {
    // ASCII 15바이트 이하 → Small String (힙 할당 없음)
    let small = "Hello"           // 5바이트 — SSO
    let medium = "Hello, World!!"  // 14바이트 — SSO
    let boundary = "123456789012345" // 15바이트 — SSO (경계)
    let large = "1234567890123456"  // 16바이트 — 힙 할당
    
    // 한글은 UTF-8에서 3바이트이므로 5글자까지 SSO
    let korean = "안녕하세요"       // 15바이트 (3 x 5) — SSO
    let koreanLarge = "안녕하세요!"  // 18바이트 (3 x 5 + 3) — 힙 할당
    
    // 이모지는 4바이트이므로 3개까지 SSO
    let emoji = "😀😁😂"          // 12바이트 (4 x 3) — SSO
    let emojiLarge = "😀😁😂😃"    // 16바이트 (4 x 4) — 힙 할당
    
    _ = (small, medium, boundary, large, korean, koreanLarge, emoji, emojiLarge)
}
```

SSO 덕분에 짧은 문자열(변수명, 짧은 라벨, 키 등)은 힙 할당/해제 비용과 참조 카운팅 오버헤드가 전혀 없습니다.

### String의 UTF-8 Backing

Swift 5 이후, `String`은 내부적으로 **네이티브 UTF-8** 인코딩을 사용합니다. 이전 버전에서는 UTF-16이 사용되었습니다.

```swift
func utf8Backing() {
    let text = "Swift 🚀"
    
    // UTF-8 뷰: 네이티브 표현에 O(1) 접근
    print(text.utf8.count)          // 10 (5 + 1 + 4)
    for byte in text.utf8 {
        print(String(format: "%02x", byte), terminator: " ")
    }
    // 53 77 69 66 74 20 f0 9f 9a 80
    print()
    
    // UTF-16 뷰: UTF-8에서 변환 필요 (약간의 오버헤드)
    print(text.utf16.count)         // 7 (5 + 1 + 서로게이트 페어 1쌍)
    
    // Character 뷰: Extended Grapheme Cluster 기준
    print(text.count)               // 7 ("S", "w", "i", "f", "t", " ", "🚀")
}
```

C 문자열과의 상호운용에서도 UTF-8이 네이티브이므로 효율적입니다:

```swift
func cStringInterop() {
    let swiftString = "Hello"
    
    // String → C 문자열 (UTF-8 + null terminator)
    swiftString.withCString { cStr in
        // cStr: UnsafePointer<CChar>
        // 네이티브 UTF-8이므로 대부분의 경우 복사 없이 직접 전달
        print(strlen(cStr))  // 5
    }
}
```

### 문자열 성능 함정

**함정 1: String.Index의 O(n) 특성**

Swift의 `String`은 `Int` 인덱스로 접근할 수 없습니다. 이는 의도적인 설계입니다 — UTF-8은 가변 길이 인코딩이므로 n번째 문자의 위치를 알려면 처음부터 n개의 문자를 세어야 합니다.

```swift
func stringIndexPerformance() {
    let text = String(repeating: "가", count: 10_000)  // 한글 10,000자
    
    // ❌ O(n²) — 매 반복마다 처음부터 인덱스를 계산
    var result1 = ""
    for i in 0..<text.count {                     // text.count 자체도 O(n)!
        let index = text.index(text.startIndex, offsetBy: i)  // O(i)
        result1.append(text[index])
    }
    
    // ✅ O(n) — 이터레이터로 순차 접근
    var result2 = ""
    for char in text {
        result2.append(char)
    }
    
    // ✅ O(n) — 인덱스를 순차적으로 진행
    var result3 = ""
    var idx = text.startIndex
    while idx < text.endIndex {
        result3.append(text[idx])
        idx = text.index(after: idx)
    }
}
```

**함정 2: Substring과 메모리 공유**

`Substring`은 원본 `String`의 메모리를 공유합니다. 이는 슬라이싱이 O(1)이라는 장점이 있지만, 작은 `Substring`이 거대한 원본 `String`을 메모리에 유지시킬 수 있습니다.

```swift
func substringMemoryTrap() {
    // 1MB 크기의 큰 문자열
    let hugeString = String(repeating: "x", count: 1_000_000)
    
    // ❌ Substring이 원본 전체를 유지
    let firstFive: Substring = hugeString.prefix(5)
    // firstFive는 5글자만 참조하지만, 1MB 원본이 해제되지 않음
    
    // ✅ 독립적인 String으로 변환하여 원본 해제 허용
    let independent: String = String(hugeString.prefix(5))
    // 5바이트만 사용하는 새 String (SSO로 힙 할당도 없음!)
    
    _ = (firstFive, independent)
}
```

**함정 3: 문자열 연결 vs 보간 vs join**

```swift
func stringConcatenationPerformance() {
    let items = (0..<10_000).map { "item\($0)" }
    
    // ❌ 매우 느림 — 매번 새 String 할당
    var result1 = ""
    for item in items {
        result1 += item + ","
    }
    
    // ✅ reserveCapacity + append
    var result2 = ""
    result2.reserveCapacity(items.count * 10)
    for item in items {
        result2 += item
        result2 += ","
    }
    
    // ✅ joined(separator:) — 가장 간결하고 최적화됨
    let result3 = items.joined(separator: ",")
    
    _ = (result1, result2, result3)
}
```

---

## 4.8 성능 최적화 실전 기법

### 구조체 크기와 성능

구조체가 커지면 복사 비용이 증가합니다. 일반적인 가이드라인:

```swift
// ✅ 작은 구조체: 복사 비용 무시 가능
struct Color {
    var r: Float  // 4바이트
    var g: Float  // 4바이트
    var b: Float  // 4바이트
    var a: Float  // 4바이트
    // 총 16바이트: 스택에서 빠르게 복사
}

// ⚠️ 큰 구조체: COW 패턴 고려
struct ParticleSystem {
    var particles: [Particle]      // 내부적으로 COW
    var emitters: [Emitter]        // 내부적으로 COW
    var forces: [Force]            // 내부적으로 COW
    var config: SimulationConfig   // 값 복사
    var stats: SimulationStats     // 값 복사
    // Array는 이미 COW이므로 구조체 전체는 비교적 가벼움
    // 하지만 프로퍼티가 매우 많아지면 커스텀 COW 고려
}
```

### 불필요한 할당 줄이기

```swift
// ❌ 루프마다 새 문자열 할당
func buildReportBad(items: [Item]) -> String {
    var result = ""
    for item in items {
        result += "\(item.name): \(item.value)\n"
        // += 할 때마다 새 문자열 할당 가능
    }
    return result
}

// ✅ 예약된 용량으로 할당 최소화
func buildReportGood(items: [Item]) -> String {
    var result = ""
    result.reserveCapacity(items.count * 50)
    for item in items {
        result += "\(item.name): \(item.value)\n"
    }
    return result
}

struct Item { let name: String; let value: Int }
```

### Autoreleasepool 활용

🟡 중급

대량의 임시 객체를 생성하는 루프에서 메모리 피크를 줄입니다:

```swift
func processImages(urls: [URL]) throws -> [Data] {
    var results: [Data] = []
    results.reserveCapacity(urls.count)
    
    for url in urls {
        // autoreleasepool로 임시 객체의 수명을 제한
        try autoreleasepool {
            let imageData = try Data(contentsOf: url)
            let processed = processImage(imageData)
            results.append(processed)
            // imageData는 이 블록을 벗어나면 즉시 해제 대상
        }
    }
    
    return results
}

func processImage(_ data: Data) -> Data { data }
```

---

## 정리

- **ARC의 비용**: retain/release는 원자적 연산이며 비용이 있습니다. 값 타입을 사용하면 이 오버헤드를 피할 수 있습니다.

- **객체 메모리 구조**: 모든 클래스 인스턴스는 16바이트 헤더(metadata + refcount)를 가집니다. Side table은 weak 참조가 해제된 객체를 안전하게 감지하는 메커니즘입니다.

- **ARC 최적화**: 컴파일러는 guaranteed parameter, owned return, 로컬 변수 분석 등을 통해 불필요한 retain/release를 제거합니다.

- **의도치 않은 메모리 유지**: 클로저가 `self`를 통째로 캡처하면 필요보다 오래 메모리가 유지됩니다. 필요한 값만 캡처하거나 `[weak self]`를 사용하세요.

- **weak vs unowned**: 기본은 `weak`, 수명이 보장될 때만 `unowned`을 사용합니다. `unowned`는 해제 후 접근 시 크래시합니다.

- **Instruments 활용**: Memory Graph Debugger로 참조 관계를 시각적으로 확인하고, Allocations로 할당 패턴을 분석하고, Leaks로 순환 참조를 탐지합니다.

- **커스텀 COW**: 대용량 데이터를 가진 값 타입에 `isKnownUniquelyReferenced`를 활용하여 필요할 때만 복사하는 패턴을 구현합니다.

- **Unsafe 포인터**: C interop이나 극한의 성능 최적화에 필요하지만, 메모리 안전성은 프로그래머의 책임입니다. `with~` 계열 클로저 안에서 사용하는 것이 가장 안전합니다.

- **컴파일러 최적화**: `-O`와 WMO의 효과를 이해하고, `@inlinable`은 라이브러리의 작은 성능 민감 함수에만 사용합니다. `ContiguousArray`와 `lazy` 연산으로 불필요한 오버헤드를 제거합니다.

- **String 내부 구조**: SSO(15바이트 이하 인라인), UTF-8 네이티브 backing, `String.Index`의 O(n) 특성을 이해하면 문자열 성능 함정을 피할 수 있습니다.

다음 장에서는 **Swift Macro**를 다루며, 컴파일 타임에 코드를 생성하는 강력한 메타프로그래밍 기법을 배웁니다.
