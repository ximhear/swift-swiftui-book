# Chapter 2. 제네릭과 프로토콜 고급 패턴

> 제네릭(Generic)과 프로토콜(Protocol)은 Swift 타입 시스템의 양대 축입니다. 기본적인 사용법을 넘어, Associated Type의 제약 조건 설계, Type Erasure의 실전 구현, 그리고 Swift 5.7 이후 등장한 Primary Associated Type까지 — 이 장에서는 유연하면서도 타입 안전한 추상화를 설계하는 고급 기법을 다룹니다.

---

## 2.1 Associated Type 심화 — 프로토콜에 제네릭을 더하다

제네릭 함수와 제네릭 타입은 익숙할 것입니다. 하지만 프로토콜에는 `<T>` 문법을 쓸 수 없습니다. 대신 프로토콜은 **Associated Type**이라는 자체 메커니즘을 사용합니다.

### 왜 프로토콜에는 제네릭 매개변수가 없는가

```swift
// ❌ 이런 문법은 존재하지 않음
// protocol Repository<T> {
//     func findAll() -> [T]
// }

// ✅ Associated Type 사용
protocol Repository {
    associatedtype Item
    func findAll() -> [Item]
    func find(by id: String) -> Item?
    func save(_ item: Item) throws
}
```

이 설계에는 명확한 이유가 있습니다. 제네릭 매개변수를 사용하면 `Repository<User>`와 `Repository<Order>`는 서로 다른 프로토콜이 됩니다. 하나의 타입이 두 프로토콜을 동시에 채택해야 하는 상황이 발생할 수 있고, 이는 타입 시스템을 불필요하게 복잡하게 만듭니다.

Associated Type은 **채택하는 쪽이 구체 타입을 결정**합니다:

```swift
struct UserRepository: Repository {
    // Item이 User로 결정됨 (타입 추론)
    func findAll() -> [User] { /* ... */ [] }
    func find(by id: String) -> User? { /* ... */ nil }
    func save(_ item: User) throws { /* ... */ }
}

struct OrderRepository: Repository {
    // Item이 Order로 결정됨
    func findAll() -> [Order] { /* ... */ [] }
    func find(by id: String) -> Order? { /* ... */ nil }
    func save(_ item: Order) throws { /* ... */ }
}
```

### 명시적 typealias

타입 추론이 모호한 경우 `typealias`로 명시할 수 있습니다:

```swift
struct MultiRepository: Repository {
    typealias Item = User  // 명시적으로 지정
    
    func findAll() -> [User] { [] }
    func find(by id: String) -> User? { nil }
    func save(_ item: User) throws { }
}
```

### Associated Type에 제약 조건 걸기

Associated Type은 그 자체로 제약 조건을 가질 수 있습니다. 이를 통해 프로토콜 설계에 더 정교한 조건을 부여합니다.

```swift
protocol Repository {
    // Item은 반드시 Identifiable이어야 함
    associatedtype Item: Identifiable
    
    func findAll() -> [Item]
    func find(by id: Item.ID) -> Item?
    mutating func save(_ item: Item) throws
    mutating func delete(by id: Item.ID) throws
}
```

`Item`이 `Identifiable`을 준수해야 하므로, `id` 프로퍼티가 보장됩니다. 이제 `find(by:)`와 `delete(by:)` 메서드에서 `Item.ID` 타입을 안전하게 사용할 수 있습니다.

```swift
struct User: Identifiable {
    let id: UUID
    var name: String
    var email: String
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
```

### 다중 Associated Type

하나의 프로토콜이 여러 Associated Type을 가질 수 있습니다:

🟡 중급

```swift
protocol DataMapper {
    associatedtype Input
    associatedtype Output
    associatedtype Failure: Error
    
    func map(_ input: Input) throws(Failure) -> Output
}

// JSON → User 변환기
struct UserMapper: DataMapper {
    struct MappingError: Error {
        let field: String
    }
    
    func map(_ input: [String: Any])
        throws(MappingError) -> User {
        guard let name = input["name"] as? String else {
            throw MappingError(field: "name")
        }
        guard let email = input["email"] as? String else {
            throw MappingError(field: "email")
        }
        return User(
            id: UUID(),
            name: name,
            email: email
        )
    }
}
```

### where 절을 활용한 조건부 확장

🔴 고급

Associated Type에 대한 `where` 절은 Swift 프로토콜 시스템의 가장 강력한 도구 중 하나입니다.

```swift
// 기본 Collection 확장
extension Collection where Element: Numeric {
    func sum() -> Element {
        reduce(0, +)
    }
}

[1, 2, 3, 4, 5].sum()       // 15
[1.5, 2.5, 3.0].sum()       // 7.0

// Associated Type에 대한 조건부 확장
extension Repository where Item: Codable {
    func exportJSON() throws -> Data {
        let items = findAll()
        return try JSONEncoder().encode(items)
    }
}

// Item이 Comparable할 때만 정렬 기능 추가
extension Repository where Item: Comparable {
    func findAllSorted() -> [Item] {
        findAll().sorted()
    }
}
```

이 패턴을 사용하면 **프로토콜을 채택하는 타입의 Associated Type이 특정 조건을 만족할 때만** 추가 기능을 제공할 수 있습니다. 코드의 재사용성과 타입 안전성을 동시에 높이는 강력한 기법입니다.

---

## 2.2 Primary Associated Type — 프로토콜의 새로운 가능성

Swift 5.7에서 도입된 **Primary Associated Type**은 프로토콜 사용 방식을 근본적으로 변화시켰습니다. 1장에서 잠깐 언급했던 이 기능을 본격적으로 살펴봅시다.

### 문제: 프로토콜을 타입으로 쓰기 어려웠던 이유

Swift 5.6까지, Associated Type이 있는 프로토콜은 타입 위치에서 사용하기 매우 까다로웠습니다.

```swift
protocol Container {
    associatedtype Element
    var count: Int { get }
    func item(at index: Int) -> Element
}

// ❌ 컴파일 에러 (Swift 5.6 이전)
// "Protocol 'Container' can only be used as a generic
//  constraint because it has Self or associated type
//  requirements"
// let container: Container = ...

// 제네릭으로만 사용 가능했음
func processContainer<C: Container>(
    _ container: C
) where C.Element == String {
    // ...
}
```

이 제약 때문에 많은 개발자가 Type Erasure 패턴에 의존해야 했습니다.

### Primary Associated Type 선언

Primary Associated Type은 프로토콜 이름 뒤에 꺾쇠 괄호로 가장 중요한 Associated Type을 표시합니다:

```swift
// Element가 Primary Associated Type
protocol Container<Element> {
    associatedtype Element
    var count: Int { get }
    func item(at index: Int) -> Element
}
```

> **Note**: 이것은 제네릭 문법과 비슷해 보이지만, 의미가 다릅니다. 제네릭 `<T>`는 호출자가 타입을 지정하고, Primary Associated Type은 채택자가 타입을 결정합니다. 꺾쇠 괄호는 **사용 시점에서 특정 Associated Type을 지정**하기 위한 문법입니다.

### some과 any에서 활용하기

Primary Associated Type의 진정한 가치는 `some`과 `any`와 결합할 때 드러납니다:

🟢 기본

```swift
// some + Primary Associated Type
// "Element가 String인 어떤 Container"
func processStrings(
    _ container: some Container<String>
) {
    for i in 0..<container.count {
        let str = container.item(at: i)
        // str은 String 타입으로 확정
        print(str.uppercased())
    }
}

// any + Primary Associated Type
// 이종 컬렉션에서도 Element 타입 지정 가능
let containers: [any Container<Int>] = [
    ArrayContainer([1, 2, 3]),
    RangeContainer(1...10)
]
```

### 표준 라이브러리의 Primary Associated Type

Swift 표준 라이브러리는 이미 많은 프로토콜에 Primary Associated Type을 적용했습니다:

```swift
// Collection<Element>
func printAll(_ items: some Collection<String>) {
    for item in items {
        print(item)
    }
}

// Sequence<Element>
func firstPositive(
    _ numbers: some Sequence<Int>
) -> Int? {
    numbers.first { $0 > 0 }
}

// Identifiable<ID> — Swift 5.7부터 ID도 Primary로 지정됨
// (stdlib에서: public protocol Identifiable<ID>)
func findOne(in items: some Collection<some Identifiable<UUID>>) {
    // ...
}
```

> **Note**: Swift 5.7에서 표준 라이브러리의 많은 프로토콜이 Primary Associated Type을 갖도록 업데이트되었습니다. `Identifiable`, `Sequence`, `Collection`, `IteratorProtocol`, `AsyncSequence` 등 거의 모든 핵심 프로토콜이 해당됩니다. 다만 모든 Associated Type이 Primary일 필요는 없습니다 — 다음 절에서 선택 기준을 다룹니다.

### 직접 프로토콜 설계 시 Primary Associated Type 선택 기준

🟡 중급

모든 Associated Type을 Primary로 만들 필요는 없습니다. Primary로 지정할 기준:

```swift
// 좋은 예: 가장 핵심적인 타입만 Primary로
protocol Cache<Value> {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) -> Value?
    mutating func set(_ key: Key, value: Value)
}

// 사용: Value만 지정하면 되는 경우가 많음
func warmUp(_ cache: some Cache<UIImage>) {
    // Key의 구체 타입은 몰라도 됨
}
```

```swift
// 나쁜 예: 모든 것을 Primary로
// protocol Cache<Key, Value, Policy, Serializer> {
//     ... 너무 많은 Primary는 가독성을 해침
// }
```

**선택 기준:**
1. 사용자가 가장 자주 지정하고 싶어하는 타입인가?
2. 이 타입 없이 프로토콜을 의미있게 사용할 수 있는가?
3. `some`이나 `any`와 함께 쓸 때 자연스러운가?

---

## 2.3 프로토콜 합성과 제약 조건 설계

실무에서는 하나의 프로토콜만으로 충분하지 않은 경우가 많습니다. 여러 프로토콜을 조합하여 정확한 요구사항을 표현하는 방법을 알아봅니다.

### 프로토콜 합성(Protocol Composition)

`&` 연산자로 여러 프로토콜을 합성합니다:

```swift
protocol Storable {
    func save() throws
}

protocol Loadable {
    static func load(from id: String) throws -> Self
}

protocol Cacheable {
    var cacheKey: String { get }
    var expiresAt: Date? { get }
}

// 세 프로토콜을 모두 만족하는 타입만 허용
func syncToCloud<T: Storable & Loadable & Cacheable>(
    _ item: T
) throws {
    if let expiresAt = item.expiresAt,
       expiresAt < Date.now {
        let refreshed = try T.load(from: item.cacheKey)
        try refreshed.save()
    } else {
        try item.save()
    }
}
```

### 프로토콜 합성 + 클래스 제약

특정 클래스를 상속한 타입으로 제한할 수도 있습니다:

```swift
import UIKit

// UIViewController이면서 Loadable인 타입
func present<T: UIViewController & Loadable>(
    _ controller: T
) {
    // UIViewController의 API와 Loadable의 API 모두 사용 가능
}
```

### typealias로 합성 프로토콜에 이름 붙이기

자주 사용하는 합성 조합에는 `typealias`로 이름을 붙일 수 있습니다:

```swift
// 자주 쓰는 합성 조합
typealias Persistable = Storable & Loadable & Codable
typealias SyncableEntity = Persistable & Cacheable & Sendable

struct UserProfile: SyncableEntity {
    var cacheKey: String { "user_\(id)" }
    var expiresAt: Date? { nil }
    
    let id: String
    var name: String
    var email: String
    
    func save() throws { /* ... */ }
    
    static func load(from id: String) throws -> UserProfile {
        // ...
        UserProfile(id: id, name: "", email: "")
    }
}
```

### 제약 조건 설계 — 최소 권한 원칙

🟡 중급

프로토콜 제약은 **꼭 필요한 만큼만** 요구해야 합니다. 과도한 제약은 재사용성을 떨어뜨립니다.

```swift
// ❌ 과도한 제약: 정렬만 하면 되는데 너무 많이 요구함
func sortItems<T: Comparable & Hashable & Codable>(
    _ items: [T]
) -> [T] {
    items.sorted()
}

// ✅ 최소한의 제약: 정렬에 필요한 것만 요구
func sortItems<T: Comparable>(_ items: [T]) -> [T] {
    items.sorted()
}
```

```swift
// 실무 예: 네트워크 응답을 캐시하는 함수
// Decodable은 파싱에, Cacheable은 캐싱에 필요
func fetchAndCache<T: Decodable & Cacheable>(
    from url: URL
) async throws -> T {
    let data = try await URLSession.shared.data(from: url).0
    let decoded = try JSONDecoder().decode(T.self, from: data)
    // decoded.cacheKey를 활용한 캐싱 로직
    return decoded
}
```

### 조건부 준수(Conditional Conformance)

🔴 고급

조건부 준수는 Swift 제네릭 시스템의 핵심 기능입니다. "원소가 특정 프로토콜을 만족할 때만 컬렉션도 해당 프로토콜을 만족한다"는 조건을 표현합니다.

```swift
// Array<Element>는 Element가 Equatable일 때만 Equatable
// 이것은 표준 라이브러리에 이미 구현되어 있음:
// extension Array: Equatable where Element: Equatable { }

// 직접 만든 타입에 조건부 준수 적용
struct Pair<First, Second> {
    var first: First
    var second: Second
}

// First와 Second가 모두 Equatable일 때만
// Pair도 Equatable
extension Pair: Equatable
    where First: Equatable, Second: Equatable {
    static func == (lhs: Pair, rhs: Pair) -> Bool {
        lhs.first == rhs.first && lhs.second == rhs.second
    }
}

// First와 Second가 모두 Hashable일 때만
// Pair도 Hashable
extension Pair: Hashable
    where First: Hashable, Second: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(first)
        hasher.combine(second)
    }
}

// First와 Second가 모두 Codable일 때만
// Pair도 Codable
extension Pair: Codable
    where First: Codable, Second: Codable { }

// 사용
let pair = Pair(first: "hello", second: 42)
let set: Set = [pair]  // Hashable이므로 Set에 넣을 수 있음
```

조건부 준수는 **합성적(compositional)**입니다. `Pair<String, Int>`는 자동으로 `Equatable`, `Hashable`, `Codable`이 됩니다. 왜냐하면 `String`과 `Int` 모두 이 세 프로토콜을 준수하기 때문입니다.

```swift
// 중첩도 자동으로 작동!
let nestedPair = Pair(
    first: Pair(first: "a", second: 1),
    second: Pair(first: "b", second: 2)
)
// Pair<Pair<String, Int>, Pair<String, Int>>
// → 자동으로 Equatable, Hashable, Codable
```

---

## 2.4 Type Erasure — 존재적 타입의 한계를 넘어서

Type Erasure(타입 소거)는 구체 타입 정보를 지우고 프로토콜 인터페이스만 노출하는 기법입니다. Swift 5.7 이전에는 Associated Type이 있는 프로토콜을 다루기 위해 거의 필수적이었고, 이후에도 여전히 유용한 패턴입니다.

### 왜 Type Erasure가 필요한가

1장에서 살펴봤듯이, `any` 키워드로 existential type을 사용할 수 있지만 한계가 있습니다:

```swift
protocol EventHandler {
    associatedtype Event
    func handle(_ event: Event)
}

struct TapHandler: EventHandler {
    func handle(_ event: TapEvent) { /* ... */ }
}

struct SwipeHandler: EventHandler {
    func handle(_ event: SwipeEvent) { /* ... */ }
}

// any EventHandler는 Event 타입을 알 수 없으므로
// handle 메서드를 호출할 수 없음
// let handler: any EventHandler = TapHandler()
// handler.handle(???)  // Event가 뭔지 모름!
```

### 클래식 Type Erasure: AnyXxx 패턴

🟡 중급

Swift 표준 라이브러리의 `AnyHashable`, `AnySequence` 등이 이 패턴을 사용합니다.

```swift
protocol Renderer {
    associatedtype Output
    func render(content: String) -> Output
}

struct HTMLRenderer: Renderer {
    func render(content: String) -> String {
        "<p>\(content)</p>"
    }
}

struct PDFRenderer: Renderer {
    func render(content: String) -> Data {
        content.data(using: .utf8)!
    }
}

// Type Erasure 래퍼
struct AnyRenderer<Output> {
    private let _render: (String) -> Output
    
    init<R: Renderer>(_ renderer: R)
        where R.Output == Output {
        _render = renderer.render
    }
    
    func render(content: String) -> Output {
        _render(content)
    }
}

// 사용: Output이 String인 모든 렌더러를 통합
let renderers: [AnyRenderer<String>] = [
    AnyRenderer(HTMLRenderer()),
    // AnyRenderer(PDFRenderer())  // ❌ Output이 Data라 불가
]
```

이 패턴의 핵심은 **클로저를 사용하여 구체 타입을 캡처**하는 것입니다. 클로저는 구체 타입을 알고 있지만, 외부에서는 `AnyRenderer<Output>`만 보입니다.

### 더 정교한 Type Erasure: Box 패턴

🔴 고급

메서드가 여러 개인 프로토콜에서는 Box 패턴이 더 깔끔합니다:

```swift
protocol DataSource {
    associatedtype Item: Identifiable
    
    var items: [Item] { get }
    func item(at index: Int) -> Item
    func search(query: String) -> [Item]
}

// 내부 추상 클래스 (Box)
private class AnyDataSourceBox<Item: Identifiable> {
    func getItems() -> [Item] { fatalError() }
    func item(at index: Int) -> Item { fatalError() }
    func search(query: String) -> [Item] { fatalError() }
}

// 구체 타입을 감싸는 Box
private class DataSourceBox<
    Source: DataSource
>: AnyDataSourceBox<Source.Item> {
    private let source: Source
    
    init(_ source: Source) {
        self.source = source
    }
    
    override func getItems() -> [Source.Item] {
        source.items
    }
    
    override func item(at index: Int) -> Source.Item {
        source.item(at: index)
    }
    
    override func search(
        query: String
    ) -> [Source.Item] {
        source.search(query: query)
    }
}

// 공개 Type Erasure 래퍼
struct AnyDataSource<Item: Identifiable> {
    private let box: AnyDataSourceBox<Item>
    
    init<Source: DataSource>(
        _ source: Source
    ) where Source.Item == Item {
        box = DataSourceBox(source)
    }
    
    var items: [Item] { box.getItems() }
    
    func item(at index: Int) -> Item {
        box.item(at: index)
    }
    
    func search(query: String) -> [Item] {
        box.search(query: query)
    }
}
```

### Swift 5.7+ 대안: Primary Associated Type으로 Type Erasure 줄이기

Swift 5.7 이후, 많은 경우 Type Erasure 없이도 문제를 해결할 수 있습니다:

```swift
protocol DataSource<Item> {
    associatedtype Item: Identifiable
    
    var items: [Item] { get }
    func item(at index: Int) -> Item
    func search(query: String) -> [Item]
}

// Type Erasure 없이 any + Primary Associated Type 사용
class ViewModel {
    // 구체 타입을 몰라도 Item이 User임을 알 수 있음
    private var dataSource: any DataSource<User>
    
    init(dataSource: any DataSource<User>) {
        self.dataSource = dataSource
    }
    
    func loadUsers() -> [User] {
        dataSource.items
    }
    
    // 런타임에 DataSource 교체 가능
    func switchToRemote(
        _ remote: any DataSource<User>
    ) {
        dataSource = remote
    }
}
```

> **Note**: `any DataSource<User>`는 내부적으로 existential type이므로 동적 디스패치 비용이 있습니다. 성능이 중요한 경로에서는 제네릭이나 `some`을 사용하세요. 하지만 대부분의 앱 로직에서 이 비용은 무시할 수 있는 수준입니다.

### 언제 어떤 방식을 선택하는가

| 상황 | 추천 방식 |
|------|-----------|
| Swift 5.7+, 단순 heterogeneous 컬렉션 | `any Protocol<Type>` |
| Swift 5.7+, 성능 중요 경로 | `some Protocol<Type>` 또는 제네릭 |
| 복잡한 프로토콜, 캡슐화 필요 | 클로저 기반 Type Erasure |
| 라이브러리 공개 API | Box 패턴 Type Erasure |
| Associated Type이 없는 프로토콜 | `any` 직접 사용 |

---

## 2.5 Opaque Return Type 활용 전략

`some` 키워드를 반환 타입에 사용하는 Opaque Return Type은 1장에서 기본 개념을 살펴봤습니다. 이 절에서는 실무에서의 활용 전략과 주의점을 깊이 다룹니다.

### Opaque Return Type의 핵심 규칙: 타입 일관성

`some`을 반환 타입으로 사용하면, **모든 반환 경로에서 같은 구체 타입**을 반환해야 합니다:

```swift
protocol Theme {
    var primaryColor: String { get }
    var fontSize: Int { get }
}

struct LightTheme: Theme {
    var primaryColor = "#000000"
    var fontSize = 16
}

struct DarkTheme: Theme {
    var primaryColor = "#FFFFFF"
    var fontSize = 16
}

// ❌ 컴파일 에러: 서로 다른 타입을 반환
// func currentTheme(isDark: Bool) -> some Theme {
//     if isDark {
//         return DarkTheme()   // DarkTheme
//     } else {
//         return LightTheme()  // LightTheme
//     }
// }

// ✅ 해결책 1: any 사용
func currentTheme(isDark: Bool) -> any Theme {
    isDark ? DarkTheme() : LightTheme()
}

// ✅ 해결책 2: 하나의 타입으로 통합
struct AdaptiveTheme: Theme {
    var isDark: Bool
    var primaryColor: String {
        isDark ? "#FFFFFF" : "#000000"
    }
    var fontSize: Int { 16 }
}

func currentTheme(isDark: Bool) -> some Theme {
    AdaptiveTheme(isDark: isDark)
}
```

### 매개변수 위치의 some (Swift 5.7+)

Swift 5.7부터 매개변수에도 `some`을 사용할 수 있습니다. 이는 제네릭의 간결한 표현입니다:

```swift
// 이 두 함수는 완전히 동일
func process(_ items: some Collection<Int>) -> Int {
    items.reduce(0, +)
}

func process<C: Collection<Int>>(_ items: C) -> Int {
    items.reduce(0, +)
}
```

하지만 **제네릭이 필요한 상황**이 있습니다:

```swift
// 같은 타입을 여러 매개변수에 요구할 때
// some은 각각 독립적인 타입을 의미!
func merge(
    _ a: some Collection<Int>,
    _ b: some Collection<Int>
) {
    // a와 b는 서로 다른 타입일 수 있음
    // [1, 2, 3]과 Set([4, 5, 6]) 가능
}

// 같은 타입을 요구하려면 제네릭 사용
func merge<C: Collection<Int>>(
    _ a: C, _ b: C
) {
    // a와 b는 반드시 같은 타입이어야 함
}
```

### Opaque Return Type과 API 설계

🟡 중급

라이브러리나 모듈의 공개 API에서 `some`을 사용하면 **구현 상세를 숨기면서 성능을 유지**할 수 있습니다:

```swift
// 공개 API: 내부 구현을 숨김
public struct NetworkClient {
    // 내부에서 어떤 Publisher를 쓰는지 노출하지 않음
    public func fetchUsers()
        -> some AsyncSequence<User, Error> {
        AsyncThrowingStream { continuation in
            // 구현 상세...
            continuation.finish()
        }
    }
}

// 호출자는 AsyncSequence 프로토콜의 API만 사용
let client = NetworkClient()
for try await user in client.fetchUsers() {
    print(user.name)
}
```

이 접근법의 장점:
1. **내부 구현 변경이 자유로움** — `AsyncThrowingStream` 대신 다른 `AsyncSequence`로 바꿔도 API가 깨지지 않음
2. **정적 디스패치** — `any AsyncSequence`와 달리 성능 비용 없음
3. **타입 추론 가능** — 호출자가 `for try await`에서 자동으로 `User` 타입을 얻음

### 다중 Opaque Return Type (Swift 5.9+)

🔴 고급

Swift 5.9부터 동일한 프로토콜의 서로 다른 opaque type을 구분할 수 있습니다:

```swift
struct AnimationLibrary {
    // 각각 다른 구체 타입을 반환하지만
    // 외부에서는 some Animation으로만 보임
    func fadeIn() -> some Animation {
        FadeAnimation(direction: .in)
    }
    
    func slideUp() -> some Animation {
        SlideAnimation(direction: .up)
    }
    
    // 반환된 opaque type은 서로 다른 타입으로 취급됨
    // type(of: fadeIn()) != type(of: slideUp())
}
```

---

## 2.6 실전 설계 사례: 플러그인 아키텍처

이 장에서 다룬 모든 개념을 종합하여, 실무에서 자주 필요한 **플러그인 아키텍처**를 설계해봅니다.

🔴 고급

```swift
// MARK: - 프로토콜 설계

// Primary Associated Type으로 핵심 타입 노출
protocol Plugin<Configuration> {
    associatedtype Configuration: PluginConfig
    associatedtype Output
    
    var name: String { get }
    var version: String { get }
    
    func configure(with config: Configuration) throws
    func execute() async throws -> Output
}

protocol PluginConfig: Codable {
    static var `default`: Self { get }
}

// MARK: - 플러그인 레지스트리

// Type Erasure: 플러그인의 구체 타입을 숨김
struct AnyPlugin {
    let name: String
    let version: String
    private let _execute: () async throws -> Any
    
    init<P: Plugin>(_ plugin: P) {
        name = plugin.name
        version = plugin.version
        _execute = { try await plugin.execute() }
    }
    
    func execute() async throws -> Any {
        try await _execute()
    }
}

// 플러그인 매니저
actor PluginManager {
    private var plugins: [String: AnyPlugin] = [:]
    
    func register<P: Plugin>(_ plugin: P) {
        let erased = AnyPlugin(plugin)
        plugins[erased.name] = erased
    }
    
    func executeAll() async throws -> [String: Any] {
        var results: [String: Any] = [:]
        for (name, plugin) in plugins {
            results[name] = try await plugin.execute()
        }
        return results
    }
}

// MARK: - 구체 플러그인 구현

struct AnalyticsConfig: PluginConfig {
    var trackingId: String
    var sampleRate: Double
    
    static var `default`: Self {
        AnalyticsConfig(
            trackingId: "default",
            sampleRate: 1.0
        )
    }
}

struct AnalyticsPlugin: Plugin {
    var name: String { "analytics" }
    var version: String { "2.1.0" }
    
    private var config: AnalyticsConfig
    
    init() {
        config = .default
    }
    
    func configure(
        with config: AnalyticsConfig
    ) throws {
        // 설정 검증 및 적용
    }
    
    func execute() async throws -> [String: Int] {
        // 분석 데이터 수집
        ["pageViews": 1234, "sessions": 567]
    }
}

// MARK: - 조건부 확장으로 기능 추가

// Output이 Codable이면 JSON으로 내보내기 가능
extension Plugin where Output: Codable {
    func exportResult() async throws -> Data {
        let output = try await execute()
        return try JSONEncoder().encode(output)
    }
}

// Configuration에 특정 프로토콜이 있을 때만
// 추가 기능 제공
protocol Validatable {
    func validate() throws
}

extension Plugin where Configuration: Validatable {
    func safeExecute() async throws -> Output {
        let config = Configuration.default
        try config.validate()
        try configure(with: config)
        return try await execute()
    }
}
```

---

## 정리

이 장에서 다룬 핵심 내용을 정리합니다:

- **Associated Type**: 프로토콜에 제네릭 매개변수 역할을 합니다. 제약 조건과 `where` 절을 통해 정교한 타입 요구사항을 표현할 수 있습니다.

- **Primary Associated Type**: Swift 5.7에서 도입되어, `some Container<String>`, `any DataSource<User>` 같은 간결한 문법을 가능하게 합니다. 프로토콜 설계 시 가장 핵심적인 Associated Type만 Primary로 지정하세요.

- **프로토콜 합성**: `&`로 여러 프로토콜을 조합하고, `typealias`로 자주 쓰는 조합에 이름을 붙입니다. 제약 조건은 **최소 권한 원칙**을 따릅니다.

- **조건부 준수**: `extension Pair: Equatable where First: Equatable, ...` 패턴으로 타입의 프로토콜 준수를 조건부로 선언합니다. 합성적으로 작동하여 중첩된 제네릭 타입에도 자동 적용됩니다.

- **Type Erasure**: 클로저 캡처 방식과 Box 패턴이 있습니다. Swift 5.7+에서는 `any Protocol<Type>`으로 많은 경우를 대체할 수 있지만, 복잡한 캡슐화에는 여전히 유용합니다.

- **Opaque Return Type**: `some`은 모든 반환 경로에서 같은 타입을 반환해야 합니다. API 설계에서 구현 상세를 숨기면서 성능을 유지하는 핵심 도구입니다.

다음 장에서는 Swift의 **동시성(Concurrency)** 시스템을 완전히 정복합니다. Actor, Sendable, Structured Concurrency의 설계 철학부터 실무 패턴까지 깊이 다룹니다.
