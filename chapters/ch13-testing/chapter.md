# Chapter 13. 테스트 전략

> 테스트 없는 코드는 기술 부채입니다. SwiftUI 앱에서는 Preview를 활용한 시각적 테스트, Swift Testing 프레임워크를 활용한 단위 테스트, Snapshot 테스트까지 — 다양한 수준의 테스트 전략을 조합하여 품질을 보장할 수 있습니다.

---

## 13.1 SwiftUI Preview를 활용한 시각적 테스트

### Preview는 첫 번째 테스트다

```swift
struct UserCard: View {
    let user: User
    
    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                Text(user.email).font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// 다양한 시나리오를 Preview로 확인
#Preview("기본") {
    UserCard(user: .preview)
}

#Preview("긴 이름") {
    UserCard(user: User(
        name: "매우 긴 이름을 가진 사용자입니다 테스트",
        email: "very.long.email@example.com",
        avatarURL: nil
    ))
}

#Preview("다크 모드") {
    UserCard(user: .preview)
        .preferredColorScheme(.dark)
}

#Preview("큰 글씨") {
    UserCard(user: .preview)
        .dynamicTypeSize(.accessibility3)
}
```

### Preview용 Mock 데이터

```swift
extension User {
    static let preview = User(
        name: "홍길동",
        email: "hong@example.com",
        avatarURL: URL(string: "https://example.com/avatar.jpg")
    )
    
    static let previewList: [User] = [
        User(name: "김철수", email: "kim@example.com",
             avatarURL: nil),
        User(name: "이영희", email: "lee@example.com",
             avatarURL: nil),
        User(name: "박민수", email: "park@example.com",
             avatarURL: nil),
    ]
}
```

---

## 13.2 Swift Testing 프레임워크

### 기본 사용법

```swift
import Testing

@Suite("TodoViewModel 테스트")
struct TodoViewModelTests {
    let viewModel: TodoViewModel
    
    init() {
        viewModel = TodoViewModel()
    }
    
    @Test("할 일 추가")
    func addTodo() {
        viewModel.send(.add("테스트 항목"))
        
        #expect(viewModel.state.items.count == 1)
        #expect(viewModel.state.items.first?.title
                == "테스트 항목")
    }
    
    @Test("빈 문자열은 추가되지 않음")
    func addEmptyTodo() {
        viewModel.send(.add(""))
        
        #expect(viewModel.state.items.isEmpty)
    }
    
    @Test("할 일 완료 토글")
    func toggleTodo() {
        viewModel.send(.add("테스트"))
        let id = viewModel.state.items.first!.id
        
        viewModel.send(.toggle(id))
        
        #expect(viewModel.state.items.first?.isCompleted
                == true)
    }
    
    @Test("완료된 항목 삭제")
    func clearCompleted() {
        viewModel.send(.add("항목 1"))
        viewModel.send(.add("항목 2"))
        let id = viewModel.state.items.first!.id
        viewModel.send(.toggle(id))
        
        viewModel.send(.clearCompleted)
        
        #expect(viewModel.state.items.count == 1)
        #expect(viewModel.state.items.first?.title
                == "항목 2")
    }
}
```

### 비동기 테스트

```swift
@Suite("ArticleListViewModel 테스트")
struct ArticleListViewModelTests {
    @Test("기사 로드 성공")
    func loadArticles() async {
        let mock = MockArticleRepository(articles: [
            Article(id: UUID(), title: "테스트",
                    body: "내용", isBookmarked: false,
                    publishedAt: .now)
        ])
        let viewModel = ArticleListViewModel(
            repository: mock)
        
        await viewModel.loadArticles()
        
        #expect(viewModel.articles.count == 1)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
    }
    
    @Test("북마크 토글 — 네트워크 실패 시 롤백")
    func toggleBookmarkRollback() async {
        let failingRepo = FailingArticleRepository()
        let viewModel = ArticleListViewModel(
            repository: failingRepo)
        viewModel.articles = [
            Article(id: UUID(), title: "테스트",
                    body: "내용", isBookmarked: false,
                    publishedAt: .now)
        ]
        
        let article = viewModel.articles.first!
        await viewModel.toggleBookmark(article)
        
        // 실패 시 원래 상태로 롤백
        #expect(viewModel.articles.first?.isBookmarked
                == false)
    }
}
```

### 매개변수화된 테스트

🟡 중급

```swift
@Suite("이메일 유효성 검사")
struct EmailValidationTests {
    @Test("유효한 이메일", arguments: [
        "user@example.com",
        "first.last@domain.co.kr",
        "user+tag@gmail.com"
    ])
    func validEmails(_ email: String) {
        #expect(EmailValidator.isValid(email))
    }
    
    @Test("유효하지 않은 이메일", arguments: [
        "not-an-email",
        "@missing-local.com",
        "missing-at-sign.com",
        ""
    ])
    func invalidEmails(_ email: String) {
        #expect(!EmailValidator.isValid(email))
    }
}
```

---

## 13.3 Snapshot 테스트

### swift-snapshot-testing 활용

```swift
import SnapshotTesting
import XCTest
import SwiftUI

final class UserCardSnapshotTests: XCTestCase {
    func testDefaultAppearance() {
        let view = UserCard(user: .preview)
            .frame(width: 375)
        
        assertSnapshot(of: view, as: .image)
    }
    
    func testDarkMode() {
        let view = UserCard(user: .preview)
            .frame(width: 375)
            .preferredColorScheme(.dark)
        
        assertSnapshot(of: view, as: .image)
    }
    
    func testLargeText() {
        let view = UserCard(user: .preview)
            .frame(width: 375)
            .dynamicTypeSize(.accessibility3)
        
        assertSnapshot(of: view, as: .image)
    }
}
```

---

## 13.4 접근성 테스트

### accessibilityLabel / accessibilityHint 검증

뷰에 적절한 접근성 정보가 설정되었는지 확인하는 것은 품질 보증의 핵심입니다. `ViewInspector`를 사용하면 SwiftUI 뷰의 접근성 속성을 단위 테스트 수준에서 검증할 수 있습니다.

```swift
import Testing
import ViewInspector
@testable import MyApp

@Suite("접근성 레이블 테스트")
struct AccessibilityLabelTests {

    @Test("프로필 이미지에 접근성 레이블이 설정됨")
    func profileImageLabel() throws {
        let view = UserCard(user: .preview)
        let image = try view.inspect().find(ViewType.Image.self)

        let label = try image.accessibilityLabel().string()
        #expect(label == "프로필 사진")
    }

    @Test("삭제 버튼에 레이블과 힌트가 모두 있음")
    func deleteButtonLabelAndHint() throws {
        let view = TodoRowView(
            item: TodoItem(title: "테스트", isCompleted: false)
        )
        let button = try view.inspect()
            .find(button: "삭제")

        let label = try button.accessibilityLabel().string()
        let hint = try button.accessibilityHint().string()

        #expect(label == "삭제")
        #expect(hint == "이 할 일을 삭제합니다")
    }

    @Test("완료 상태에 따라 접근성 값이 변경됨")
    func completionAccessibilityValue() throws {
        let completed = TodoRowView(
            item: TodoItem(title: "운동", isCompleted: true)
        )
        let incomplete = TodoRowView(
            item: TodoItem(title: "운동", isCompleted: false)
        )

        let completedValue = try completed.inspect()
            .find(ViewType.HStack.self)
            .accessibilityValue().string()
        let incompleteValue = try incomplete.inspect()
            .find(ViewType.HStack.self)
            .accessibilityValue().string()

        #expect(completedValue == "완료됨")
        #expect(incompleteValue == "미완료")
    }
}
```

### AccessibilityAudit (Xcode 15+)

Xcode 15부터 `XCUIApplication`에 `performAccessibilityAudit` 메서드가 추가되었습니다. 자동화된 접근성 감사를 통해 WCAG 기준에 부합하지 않는 요소를 찾아냅니다.

```swift
import XCTest

final class AccessibilityAuditTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// 메인 화면 전체에 대한 접근성 감사를 수행합니다.
    func testMainScreenAccessibilityAudit() throws {
        // 기본 감사 — 모든 카테고리 검사
        try app.performAccessibilityAudit()
    }

    /// 특정 카테고리만 선택하여 감사할 수 있습니다.
    func testAuditWithSpecificCategories() throws {
        try app.performAccessibilityAudit(
            for: [.dynamicType, .contrast, .hitRegion]
        )
    }

    /// 알려진 문제를 무시하면서 감사를 수행합니다.
    func testAuditIgnoringKnownIssues() throws {
        try app.performAccessibilityAudit(
            for: .all
        ) { issue in
            // 서드파티 라이브러리의 알려진 이슈는 무시
            var shouldIgnore = false
            if issue.auditType == .contrast,
               issue.element?.label == "Ad Banner" {
                shouldIgnore = true
            }
            return shouldIgnore
        }
    }

    /// 특정 화면으로 이동 후 감사합니다.
    func testSettingsScreenAudit() throws {
        app.tabBars.buttons["설정"].tap()
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .contrast
        ])
    }
}
```

> **팁**: `performAccessibilityAudit`는 `.dynamicType`, `.contrast`, `.hitRegion`, `.sufficientElementDescription`, `.textClipped` 등 다양한 감사 카테고리를 지원합니다. CI 파이프라인에 포함시키면 접근성 회귀를 자동으로 탐지할 수 있습니다.

### 테스트 피라미드

```text
        /  E2E / UI  \          ← 느리지만 실제 사용자 흐름 검증
       /   Snapshot   \         ← 시각적 회귀 방지
      /  Integration   \        ← ViewModel + Repository 통합
     /   Unit Tests    \        ← 빠르고 많이 작성
    /     Preview       \       ← 개발 중 실시간 확인
   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
```

---

## 13.5 Swift Testing 고급 기능

🔴 고급

Swift Testing 프레임워크는 `@Test`와 `#expect` 외에도 테스트의 표현력과 유지보수성을 높여주는 고급 기능을 제공합니다.

### `#require` — 필수 조건 검증

`#require`는 조건이 충족되지 않으면 테스트를 **즉시 실패**시킵니다. 옵셔널 언래핑에 특히 유용하며, `#expect`와 달리 실패 시 이후 코드가 실행되지 않습니다.

```swift
import Testing
@testable import MyApp

@Suite("장바구니 테스트")
struct CartTests {

    @Test("상품 추가 후 첫 번째 항목 확인")
    func addProduct() throws {
        let cart = ShoppingCart()
        cart.add(Product(name: "키보드", price: 89_000))

        // nil이면 테스트가 즉시 실패하며,
        // 이후 코드는 실행되지 않습니다.
        let firstItem = try #require(cart.items.first)
        #expect(firstItem.name == "키보드")
        #expect(firstItem.price == 89_000)
    }

    @Test("JSON 디코딩 필수 필드 존재 확인")
    func decodeUser() throws {
        let json = """
        {"id": 1, "name": "홍길동", "email": "hong@test.com"}
        """.data(using: .utf8)!

        let user = try #require(
            try? JSONDecoder().decode(User.self, from: json)
        )
        #expect(user.name == "홍길동")
    }
}
```

### `withKnownIssue` — 알려진 이슈 표시

아직 수정되지 않은 버그가 있을 때, `withKnownIssue`로 감싸면 해당 실패가 "예상된 실패"로 처리됩니다. 버그가 수정되면 테스트 러너가 알려줍니다.

```swift
@Suite("결제 모듈 테스트")
struct PaymentTests {

    @Test("소수점 반올림 이슈 — JIRA-1234")
    func roundingIssue() {
        withKnownIssue("JIRA-1234: 소수점 셋째 자리 반올림 오류") {
            let result = PaymentCalculator.calculate(
                price: 1000, taxRate: 0.033
            )
            // 현재 33.29 대신 33.30을 반환하는 알려진 버그
            #expect(result.tax == 33)
        }
    }

    @Test("특정 조건에서만 알려진 이슈 발생")
    func conditionalKnownIssue() {
        let locale = Locale.current
        withKnownIssue(
            "한국 로캘에서 통화 형식 오류",
            isIntermittent: true
        ) {
            let formatted = CurrencyFormatter.format(
                1000, locale: locale
            )
            #expect(formatted == "₩1,000")
        }
    }
}
```

### `Tag`를 이용한 테스트 필터링

테스트에 태그를 부착하면 특정 태그만 선택적으로 실행하거나 제외할 수 있습니다. CI 환경에서 느린 테스트를 분리할 때 유용합니다.

```swift
import Testing

// 프로젝트 전역에서 사용할 태그를 정의합니다.
extension Tag {
    @Tag static var network: Self
    @Tag static var database: Self
    @Tag static var uiLogic: Self
    @Tag static var slow: Self
}

@Suite("사용자 서비스 테스트")
struct UserServiceTests {

    @Test("프로필 조회", .tags(.network))
    func fetchProfile() async throws {
        let service = UserService(client: MockHTTPClient())
        let profile = try await service.fetchProfile(id: 42)
        #expect(profile.name == "홍길동")
    }

    @Test("캐시된 프로필 반환", .tags(.database))
    func cachedProfile() async throws {
        let service = UserService(
            client: MockHTTPClient(),
            cache: InMemoryCache()
        )
        _ = try await service.fetchProfile(id: 42)
        let cached = try await service.fetchProfile(id: 42)
        #expect(cached.name == "홍길동")
    }

    @Test("UI 표시 이름 생성", .tags(.uiLogic))
    func displayName() {
        let user = User(name: "홍길동", email: "hong@test.com")
        #expect(user.displayName == "홍길동")
    }
}
```

터미널에서 태그를 기준으로 필터링하여 실행할 수 있습니다.

```bash
# network 태그만 실행
swift test --filter tag:network

# slow 태그 제외
swift test --skip tag:slow
```

### `confirmation`을 이용한 이벤트 발생 검증

비동기 이벤트, 콜백, 또는 Combine/AsyncSequence 기반 이벤트가 정확히 기대한 횟수만큼 발생하는지 검증합니다.

```swift
@Suite("알림 매니저 테스트")
struct NotificationManagerTests {

    @Test("이벤트가 정확히 한 번 발생함")
    func singleEvent() async {
        let manager = NotificationManager()

        await confirmation("알림 전송됨") { confirm in
            manager.onNotificationSent = { _ in
                confirm()
            }
            await manager.send(
                Notification(title: "테스트", body: "내용")
            )
        }
    }

    @Test("여러 이벤트 발생 횟수 검증")
    func multipleEvents() async {
        let manager = EventBus()

        await confirmation(
            "이벤트 수신",
            expectedCount: 3
        ) { confirm in
            manager.onEvent = { _ in
                confirm()
            }
            await manager.emit(.userLoggedIn)
            await manager.emit(.dataRefreshed)
            await manager.emit(.settingsChanged)
        }
    }
}
```

---

## 13.6 UI 테스트 (XCUITest)

🔴 고급

UI 테스트는 앱을 별도 프로세스로 실행하여 실제 사용자 상호작용을 시뮬레이션합니다. 단위 테스트가 개별 컴포넌트를 검증한다면, UI 테스트는 전체 흐름을 통합적으로 검증합니다.

### 기본 UI 테스트 작성

```swift
import XCTest

final class TodoAppUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// 할 일 추가 흐름을 검증합니다.
    func testAddTodo() throws {
        // 텍스트 필드에 입력
        let textField = app.textFields["새로운 할 일"]
        textField.tap()
        textField.typeText("Swift Testing 공부하기")

        // 추가 버튼 탭
        app.buttons["추가"].tap()

        // 결과 확인 — 리스트에 항목이 나타남
        let cell = app.staticTexts["Swift Testing 공부하기"]
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
    }

    /// 할 일 완료 토글을 검증합니다.
    func testToggleTodo() throws {
        // 이미 항목이 있다고 가정하고 추가
        let textField = app.textFields["새로운 할 일"]
        textField.tap()
        textField.typeText("테스트 항목")
        app.buttons["추가"].tap()

        // 체크 버튼 탭
        let checkButton = app.buttons["toggle_테스트 항목"]
        XCTAssertTrue(checkButton.waitForExistence(timeout: 2))
        checkButton.tap()

        // 완료 상태 확인
        let completedImage = app.images["checkmark.circle.fill"]
        XCTAssertTrue(completedImage.waitForExistence(timeout: 2))
    }

    /// 할 일 삭제를 검증합니다.
    func testDeleteTodo() throws {
        // 항목 추가
        let textField = app.textFields["새로운 할 일"]
        textField.tap()
        textField.typeText("삭제할 항목")
        app.buttons["추가"].tap()

        // 스와이프하여 삭제
        let cell = app.staticTexts["삭제할 항목"]
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
        cell.swipeLeft()
        app.buttons["삭제"].tap()

        // 항목이 사라졌는지 확인
        XCTAssertFalse(cell.exists)
    }
}
```

### 접근성 식별자를 활용한 요소 찾기

UI 요소를 안정적으로 찾으려면 텍스트 기반 검색 대신 접근성 식별자(`accessibilityIdentifier`)를 사용합니다. 다국어 지원 시에도 테스트가 깨지지 않습니다.

```swift
// ── 프로덕션 코드 (SwiftUI View) ──
struct TodoInputView: View {
    @Binding var text: String
    var onAdd: () -> Void

    var body: some View {
        HStack {
            TextField("새로운 할 일", text: $text)
                .accessibilityIdentifier("todo_input_field")

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityIdentifier("todo_add_button")
            .accessibilityLabel("할 일 추가")
        }
    }
}

struct TodoRowView: View {
    let item: TodoItem

    var body: some View {
        HStack {
            Image(systemName: item.isCompleted
                  ? "checkmark.circle.fill"
                  : "circle")
                .accessibilityIdentifier(
                    "todo_toggle_\(item.id)"
                )
            Text(item.title)
        }
        .accessibilityIdentifier("todo_row_\(item.id)")
    }
}

// ── UI 테스트 ──
final class TodoAccessibilityIDTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAddTodoUsingIdentifiers() throws {
        let input = app.textFields["todo_input_field"]
        let addButton = app.buttons["todo_add_button"]

        input.tap()
        input.typeText("식별자로 찾기")
        addButton.tap()

        // 동적 식별자로 생성된 행을 찾음
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH 'todo_row_'"
        )
        let row = app.descendants(matching: .any)
            .matching(predicate)
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
    }
}
```

### 네트워크 목 없이 UI 테스트하기 — Launch Arguments 활용

UI 테스트에서는 네트워크 목(mock) 라이브러리를 직접 주입할 수 없습니다. 대신 **launch arguments**로 앱에 테스트 모드를 알려주고, 앱 내부에서 목 데이터를 반환하도록 분기합니다.

```swift
// ── UI 테스트에서 launch arguments 설정 ──
final class ArticleListUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "--ui-testing",
            "--mock-articles"
        ]
        app.launchEnvironment = [
            "MOCK_DELAY": "0"   // 지연 없이 즉시 응답
        ]
        app.launch()
    }

    func testArticleListLoads() throws {
        let firstArticle = app.staticTexts["테스트 기사 1"]
        XCTAssertTrue(
            firstArticle.waitForExistence(timeout: 5)
        )
    }

    func testPullToRefresh() throws {
        let list = app.tables.firstMatch
        list.swipeDown()

        // 새로고침 후에도 데이터가 표시됨
        let article = app.staticTexts["테스트 기사 1"]
        XCTAssertTrue(
            article.waitForExistence(timeout: 5)
        )
    }
}

// ── 앱 측 분기 처리 (App Entry Point) ──
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.articleRepository,
                    Self.makeRepository()
                )
        }
    }

    static func makeRepository() -> any ArticleRepository {
        if CommandLine.arguments.contains("--mock-articles") {
            return MockArticleRepository(articles: [
                Article(id: UUID(), title: "테스트 기사 1",
                        body: "본문 1", isBookmarked: false,
                        publishedAt: .now),
                Article(id: UUID(), title: "테스트 기사 2",
                        body: "본문 2", isBookmarked: true,
                        publishedAt: .now),
            ])
        }
        return LiveArticleRepository()
    }
}
```

### Page Object 패턴으로 유지보수성 높이기

UI 테스트가 많아지면 요소 검색과 상호작용 로직이 중복됩니다. **Page Object 패턴**은 각 화면을 객체로 추상화하여 테스트의 가독성과 유지보수성을 크게 높입니다.

```swift
// ── Page Object 정의 ──

/// 할 일 목록 화면을 나타내는 Page Object
struct TodoListPage {
    let app: XCUIApplication

    // MARK: - Elements

    var inputField: XCUIElement {
        app.textFields["todo_input_field"]
    }

    var addButton: XCUIElement {
        app.buttons["todo_add_button"]
    }

    var todoList: XCUIElement {
        app.tables["todo_list"]
    }

    var emptyStateLabel: XCUIElement {
        app.staticTexts["empty_state_label"]
    }

    // MARK: - Actions

    @discardableResult
    func addTodo(_ title: String) -> Self {
        inputField.tap()
        inputField.typeText(title)
        addButton.tap()
        return self
    }

    @discardableResult
    func deleteTodo(at index: Int) -> Self {
        let cell = todoList.cells
            .element(boundBy: index)
        cell.swipeLeft()
        app.buttons["삭제"].tap()
        return self
    }

    @discardableResult
    func toggleTodo(at index: Int) -> Self {
        let cell = todoList.cells
            .element(boundBy: index)
        let toggle = cell.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'todo_toggle_'"
            )
        ).firstMatch
        toggle.tap()
        return self
    }

    func tapTodo(at index: Int) -> TodoDetailPage {
        todoList.cells.element(boundBy: index).tap()
        return TodoDetailPage(app: app)
    }

    // MARK: - Assertions

    func assertTodoExists(
        _ title: String,
        timeout: TimeInterval = 3
    ) {
        let text = app.staticTexts[title]
        XCTAssertTrue(text.waitForExistence(timeout: timeout))
    }

    func assertTodoCount(_ count: Int) {
        XCTAssertEqual(todoList.cells.count, count)
    }

    func assertEmptyState() {
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2)
        )
    }
}

/// 상세 화면 Page Object
struct TodoDetailPage {
    let app: XCUIApplication

    var titleLabel: XCUIElement {
        app.staticTexts["detail_title"]
    }

    var editButton: XCUIElement {
        app.buttons["detail_edit"]
    }

    func goBack() -> TodoListPage {
        app.navigationBars.buttons.firstMatch.tap()
        return TodoListPage(app: app)
    }
}

// ── Page Object를 사용하는 테스트 ──

final class TodoFlowUITests: XCTestCase {
    let app = XCUIApplication()
    var todoPage: TodoListPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
        todoPage = TodoListPage(app: app)
    }

    func testFullWorkflow() throws {
        // 빈 상태 확인
        todoPage.assertEmptyState()

        // 항목 추가
        todoPage
            .addTodo("첫 번째 할 일")
            .addTodo("두 번째 할 일")

        todoPage.assertTodoCount(2)
        todoPage.assertTodoExists("첫 번째 할 일")

        // 완료 토글
        todoPage.toggleTodo(at: 0)

        // 상세 화면 진입 후 복귀
        let detailPage = todoPage.tapTodo(at: 1)
        XCTAssertTrue(
            detailPage.titleLabel
                .waitForExistence(timeout: 2)
        )
        todoPage = detailPage.goBack()

        // 삭제
        todoPage.deleteTodo(at: 0)
        todoPage.assertTodoCount(1)
    }

    func testAddAndDeleteMultiple() throws {
        todoPage
            .addTodo("A")
            .addTodo("B")
            .addTodo("C")

        todoPage.assertTodoCount(3)

        todoPage
            .deleteTodo(at: 2)
            .deleteTodo(at: 1)

        todoPage.assertTodoCount(1)
        todoPage.assertTodoExists("A")
    }
}
```

---

## 13.7 Mock / Stub / Spy 패턴

🟡 중급

테스트에서 외부 의존성을 대체하는 객체를 **테스트 더블(Test Double)**이라 합니다. 목적에 따라 Mock, Stub, Spy로 나뉩니다.

### 테스트 더블 비교

| 구분 | 목적 | 검증 대상 | 반환값 |
|------|------|-----------|--------|
| **Stub** | 고정된 응답을 반환 | 반환값을 소비하는 쪽 | 미리 설정한 값 |
| **Mock** | 호출 자체를 검증 | 메서드가 올바르게 호출되었는지 | 필요 시 설정 |
| **Spy** | 호출을 기록하면서 실제 동작도 수행 가능 | 호출 횟수, 인자 등 | 실제 또는 설정값 |

### Protocol 기반 Mock 구현

의존성을 프로토콜로 추상화하면 테스트 시 쉽게 대체할 수 있습니다.

```swift
// ── 프로토콜 정의 ──
protocol ArticleRepository: Sendable {
    func fetchAll() async throws -> [Article]
    func save(_ article: Article) async throws
    func delete(id: UUID) async throws
}

// ── Stub: 항상 고정 데이터를 반환 ──
struct StubArticleRepository: ArticleRepository {
    var articles: [Article] = []
    var saveError: Error?
    var deleteError: Error?

    func fetchAll() async throws -> [Article] {
        articles
    }

    func save(_ article: Article) async throws {
        if let error = saveError { throw error }
    }

    func delete(id: UUID) async throws {
        if let error = deleteError { throw error }
    }
}

// ── Mock: 호출 여부와 인자를 검증 ──
final class MockArticleRepository: ArticleRepository,
                                    @unchecked Sendable {
    // 호출 기록
    private(set) var fetchAllCallCount = 0
    private(set) var savedArticles: [Article] = []
    private(set) var deletedIDs: [UUID] = []

    // Stub 응답
    var articlesToReturn: [Article] = []
    var saveError: Error?

    func fetchAll() async throws -> [Article] {
        fetchAllCallCount += 1
        return articlesToReturn
    }

    func save(_ article: Article) async throws {
        if let error = saveError { throw error }
        savedArticles.append(article)
    }

    func delete(id: UUID) async throws {
        deletedIDs.append(id)
    }
}

// ── Spy: 실제 구현을 감싸며 호출을 기록 ──
final class SpyArticleRepository: ArticleRepository,
                                   @unchecked Sendable {
    private let real: any ArticleRepository
    private(set) var callLog: [String] = []

    init(wrapping real: any ArticleRepository) {
        self.real = real
    }

    func fetchAll() async throws -> [Article] {
        callLog.append("fetchAll")
        return try await real.fetchAll()
    }

    func save(_ article: Article) async throws {
        callLog.append("save(\(article.id))")
        try await real.save(article)
    }

    func delete(id: UUID) async throws {
        callLog.append("delete(\(id))")
        try await real.delete(id: id)
    }
}
```

### Swift Testing + Async Mock 조합 예제

위에서 만든 Mock을 Swift Testing과 함께 사용하는 실전 예제입니다.

```swift
import Testing
@testable import MyApp

@Suite("ArticleListViewModel 테스트 — Mock 활용")
struct ArticleViewModelMockTests {
    let mock: MockArticleRepository
    let viewModel: ArticleListViewModel

    init() {
        mock = MockArticleRepository()
        mock.articlesToReturn = [
            Article(id: UUID(), title: "Mock 기사",
                    body: "내용", isBookmarked: false,
                    publishedAt: .now)
        ]
        viewModel = ArticleListViewModel(repository: mock)
    }

    @Test("로드 시 fetchAll이 정확히 1회 호출됨")
    func fetchCallCount() async {
        await viewModel.loadArticles()

        #expect(mock.fetchAllCallCount == 1)
        #expect(viewModel.articles.count == 1)
    }

    @Test("저장 시 올바른 Article이 전달됨")
    func saveArticle() async throws {
        let article = Article(
            id: UUID(), title: "새 기사",
            body: "본문", isBookmarked: false,
            publishedAt: .now
        )

        try await viewModel.saveArticle(article)

        let saved = try #require(mock.savedArticles.first)
        #expect(saved.title == "새 기사")
    }

    @Test("저장 실패 시 에러 상태가 설정됨")
    func saveFailure() async {
        mock.saveError = URLError(.notConnectedToInternet)

        let article = Article(
            id: UUID(), title: "실패 기사",
            body: "본문", isBookmarked: false,
            publishedAt: .now
        )

        await viewModel.saveArticle(article)

        #expect(viewModel.error != nil)
    }

    @Test("삭제 시 올바른 ID가 전달됨")
    func deleteArticle() async throws {
        let id = UUID()
        try await viewModel.deleteArticle(id: id)

        let deletedID = try #require(
            mock.deletedIDs.first
        )
        #expect(deletedID == id)
    }
}
```

---

## 정리

- **Preview**: 가장 빠른 피드백 루프. 다양한 시나리오(다크 모드, 큰 글씨, 긴 텍스트)를 Preview로 확인합니다.

- **Swift Testing**: `@Test`, `#expect`로 간결하고 읽기 쉬운 테스트를 작성합니다. 매개변수화된 테스트로 중복을 줄입니다.

- **Swift Testing 고급**: `#require`로 필수 조건을 검증하고, `withKnownIssue`로 알려진 버그를 관리하며, `Tag`와 `confirmation`으로 테스트 구성과 이벤트 검증을 수행합니다.

- **비동기 테스트**: Mock Repository를 주입하여 ViewModel의 비동기 로직과 에러 처리를 검증합니다.

- **Snapshot 테스트**: UI 회귀를 자동으로 감지합니다. 라이트/다크 모드, 다양한 Dynamic Type 크기를 포함합니다.

- **접근성 테스트**: `accessibilityLabel`, `accessibilityHint` 검증과 `performAccessibilityAudit`를 통해 접근성 품질을 보장합니다.

- **UI 테스트**: XCUITest로 실제 사용자 흐름을 검증합니다. 접근성 식별자, launch arguments, Page Object 패턴을 조합하여 안정적이고 유지보수하기 쉬운 UI 테스트를 작성합니다.

- **테스트 더블**: Mock, Stub, Spy를 목적에 맞게 사용합니다. Protocol 기반으로 설계하면 프로덕션 코드 변경 없이 테스트 더블을 주입할 수 있습니다.

- **테스트 피라미드**: Preview → Unit → Integration → Snapshot → UI 순으로 피드백 속도와 커버리지를 균형 있게 구성합니다.

다음 장에서는 **성능 프로파일링과 최적화**를 다룹니다.
