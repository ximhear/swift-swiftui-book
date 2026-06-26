# Chapter 10. 내비게이션 아키텍처(Navigation)

> SwiftUI의 내비게이션(Navigation)은 iOS 16에서 `NavigationStack`과 `NavigationSplitView` 도입으로 크게 개선되었습니다. 프로그래밍 방식의 내비게이션, 딥링크 처리, 복잡한 탭+내비게이션 복합 구조까지 — 이 장에서는 실무에서 만나는 모든 내비게이션 시나리오를 체계적으로 다룹니다.

> **Note**: 기존 `NavigationView`는 iOS 16에서 `NavigationStack`/`NavigationSplitView`가 도입되면서 deprecated되었습니다. 신규 코드는 이 장에서 다루는 두 API를 사용하고, 기존 코드는 점진적으로 마이그레이션하는 것이 좋습니다.

---

## 10.1 NavigationStack 심화

### 기본 구조와 path 관리

```swift
struct AppNavigationView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(
                    for: Product.self
                ) { product in
                    ProductDetailView(product: product)
                }
                .navigationDestination(
                    for: Category.self
                ) { category in
                    CategoryView(
                        category: category,
                        path: $path
                    )
                }
        }
    }
}
```

### 프로그래밍 방식 내비게이션

```swift
struct HomeView: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        List {
            Button("상품으로 이동") {
                path.append(Product(name: "MacBook"))
            }
            
            Button("카테고리 → 상품 순차 이동") {
                path.append(Category(name: "전자기기"))
                path.append(Product(name: "iPhone"))
            }
            
            Button("루트로 돌아가기") {
                path.removeLast(path.count)
            }
        }
        .navigationTitle("홈")
    }
}
```

> **Warning**: `NavigationPath`는 서로 다른 타입을 한 스택에 담을 수 있도록 요소 타입을 **타입 소거(type-erased)**합니다. 그래서 특정 인덱스의 값을 꺼내 읽거나 중간을 삭제할 수 없고, `removeLast(_:)`로 끝에서부터 제거하는 것만 가능합니다. 경로의 각 요소를 직접 조회·조작해야 한다면 `NavigationPath` 대신 `[AppRoute]`처럼 구체 타입 배열을 path로 쓰세요.

### 타입 안전한 내비게이션(Navigation) 경로

🟡 중급

```swift
// 내비게이션 경로를 열거형으로 정의
enum AppRoute: Hashable {
    case productList(Category)
    case productDetail(Product)
    case cart
    case checkout
    case orderConfirmation(orderId: String)
}

struct TypeSafeNavigation: View {
    @State private var path: [AppRoute] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(
                    for: AppRoute.self
                ) { route in
                    switch route {
                    case .productList(let category):
                        ProductListView(category: category)
                    case .productDetail(let product):
                        ProductDetailView(product: product)
                    case .cart:
                        CartView()
                    case .checkout:
                        CheckoutView()
                    case .orderConfirmation(let id):
                        OrderConfirmationView(orderId: id)
                    }
                }
        }
    }
}
```

---

## 10.2 NavigationSplitView — iPad와 macOS

데이터 기반 `List(_:selection:)`는 각 행을 요소의 `id`로 자동 태깅합니다. 따라서 selection 바인딩의 타입은 요소 자체(`Category`)가 아니라 **`id` 타입(`Category.ID?`)**이어야 선택이 런타임에 반영됩니다. 아래처럼 selection을 `id`로 받고, 상세 패널에서는 `id`로 원본을 조회합니다.

```swift
struct SplitNavigation: View {
    @State private var selectedCategoryID: Category.ID?
    @State private var selectedProductID: Product.ID?
    
    var body: some View {
        NavigationSplitView {
            // 사이드바 — selection은 요소의 id 타입이어야 한다
            List(categories, selection: $selectedCategoryID) {
                category in
                Text(category.name)
            }
            .navigationTitle("카테고리")
        } content: {
            // 중간 패널 — 선택된 id로 카테고리를 조회
            if let category = categories.first(
                where: { $0.id == selectedCategoryID }
            ) {
                List(category.products,
                     selection: $selectedProductID) {
                    product in
                    Text(product.name)
                }
                .navigationTitle(category.name)
            } else {
                Text("카테고리를 선택하세요")
            }
        } detail: {
            // 상세 패널 — 선택된 id로 상품을 조회
            if let category = categories.first(
                   where: { $0.id == selectedCategoryID }),
               let product = category.products.first(
                   where: { $0.id == selectedProductID }) {
                ProductDetailView(product: product)
            } else {
                Text("상품을 선택하세요")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

> **Warning**: selection 바인딩을 `Category?`처럼 **요소 타입**으로 주면 컴파일은 통과하지만, `List`가 행에 부여하는 태그(`Category.ID`)와 타입이 달라 **선택이 반영되지 않습니다**. 요소 자체로 selection을 받으려면 각 행에 `.tag(category)`를 명시해야 합니다.

---

## 10.3 딥링크 처리 전략

🔴 고급

딥링크 파싱에서 가장 흔한 함정은 **커스텀 스킴과 Universal Link의 URL 구조가 다르다**는 점입니다. 커스텀 스킴 `myapp://product/12345`에서는 `product`가 `host`로 파싱되고 `12345`만 path에 남습니다. 반면 Universal Link `https://myapp.com/product/12345`에서는 `host`가 도메인(`myapp.com`)이고 `product/12345`가 path에 들어갑니다. 따라서 `pathComponents`만으로 파싱하면 커스텀 스킴이 동작하지 않습니다. 두 형태를 모두 지원하려면 스킴을 구분해 `host()`와 path를 함께 조립해야 합니다.

```swift
// 커스텀 스킴:     myapp://product/12345  (host="product", path="/12345")
// Universal Link: https://myapp.com/product/12345
//                 (host="myapp.com", path="/product/12345")

enum DeepLink {
    case product(id: String)
    case category(id: String)
    case cart
    case settings
    
    init?(url: URL) {
        let pathTokens = url.pathComponents
            .filter { $0 != "/" }
        
        // 커스텀 스킴은 host가 첫 경로 토큰이고,
        // Universal Link는 host가 도메인이므로 path만 사용한다.
        let segments: [String]
        if url.scheme == "https" || url.scheme == "http" {
            segments = pathTokens
        } else {
            segments = (url.host().map { [$0] } ?? [])
                + pathTokens
        }
        
        guard let first = segments.first else {
            return nil
        }
        
        switch first {
        case "product":
            guard let id = segments.dropFirst().first
            else { return nil }
            self = .product(id: id)
        case "category":
            guard let id = segments.dropFirst().first
            else { return nil }
            self = .category(id: id)
        case "cart":
            self = .cart
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}

@Observable
class NavigationCoordinator {
    var tabSelection: MainTab = .home
    var homePath: [AppRoute] = []
    
    func handle(_ deepLink: DeepLink) {
        // 현재 경로 초기화
        homePath.removeAll()
        
        switch deepLink {
        case .product(let id):
            tabSelection = .home
            homePath.append(.productDetail(
                Product(id: id, name: "")))
        case .category(let id):
            tabSelection = .home
            homePath.append(.productList(
                Category(id: id, name: "")))
        case .cart:
            tabSelection = .cart
        case .settings:
            tabSelection = .settings
        }
    }
}
```

> **Note**: `Tab("...", systemImage:value:)` 문법은 **iOS 18+**에서 사용할 수 있습니다. iOS 17 이하에서는 `.tabItem { Label(...) }` 문법을 사용하세요. (이 표기는 아래 §10.4의 `MainTabView`에도 동일하게 적용됩니다.)

> **Note**: `NavigationPath`는 `codable` 표현을 통해 상태 복원이 가능합니다. `path.codable`로 직렬화 가능한 표현을 꺼내 `SceneStorage`에 저장하고, 복원 시 `NavigationPath(codable:)`로 되살리면 앱 재실행 후에도 경로를 유지할 수 있습니다(단, 경로에 담긴 타입이 모두 `Codable`이어야 합니다).

```swift
struct RootView: View {
    @State private var coordinator = NavigationCoordinator()
    
    var body: some View {
        TabView(selection: $coordinator.tabSelection) {
            Tab("홈", systemImage: "house",
                value: .home) {
                NavigationStack(
                    path: $coordinator.homePath
                ) {
                    HomeView()
                }
            }
            Tab("장바구니", systemImage: "cart",
                value: .cart) {
                CartView()
            }
            Tab("설정", systemImage: "gear",
                value: .settings) {
                SettingsView()
            }
        }
        .environment(coordinator)
        .onOpenURL { url in
            if let deepLink = DeepLink(url: url) {
                coordinator.handle(deepLink)
            }
        }
    }
}

enum MainTab: Hashable {
    case home, cart, settings
}
```

---

## 10.4 탭 기반 + 내비게이션 복합 구조

### 각 탭의 독립적 NavigationStack

흔히 "이미 선택된 탭을 다시 누르면 해당 탭을 루트로 되돌린다"는 동작을 구현하려고 `onChange(of: selectedTab)` 안에서 `oldTab == newTab`을 검사합니다. 하지만 이는 **절대 동작하지 않습니다**. `onChange(of:)`는 값이 바뀔 때만 호출되며, 그때는 항상 `oldValue != newValue`이기 때문입니다. 같은 탭을 다시 누르면 `selectedTab` 값 자체가 변하지 않으므로 콜백이 호출되지 않습니다.

재탭을 감지하려면 `TabView(selection:)`에 **커스텀 Binding**을 주입해 `set` 클로저에서 "새 값이 현재 값과 같은지"를 직접 가로채야 합니다. `set`은 같은 탭을 다시 눌러도 호출되기 때문에 여기서 재탭을 잡아낼 수 있습니다.

```swift
struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    
    var body: some View {
        // 커스텀 Binding으로 재탭(같은 탭 다시 누르기)을 가로챈다.
        let selection = Binding<AppTab>(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    popToRoot(newTab)   // 같은 탭 재탭 → 루트로
                }
                selectedTab = newTab
            }
        )
        
        return TabView(selection: selection) {
            Tab("홈", systemImage: "house",
                value: .home) {
                NavigationStack(path: $homePath) {
                    HomeContentView()
                }
            }
            Tab("검색", systemImage: "magnifyingglass",
                value: .search) {
                NavigationStack(path: $searchPath) {
                    SearchContentView()
                }
            }
            Tab("프로필", systemImage: "person",
                value: .profile) {
                NavigationStack(path: $profilePath) {
                    ProfileContentView()
                }
            }
        }
    }
    
    private func popToRoot(_ tab: AppTab) {
        switch tab {
        case .home: homePath.removeLast(homePath.count)
        case .search: searchPath.removeLast(searchPath.count)
        case .profile: profilePath.removeLast(profilePath.count)
        }
    }
}

enum AppTab: Hashable {
    case home, search, profile
}
```

> **Warning**: `onChange(of: selectedTab) { old, new in if old == new { ... } }` 패턴은 재탭 감지에 쓸 수 없습니다. `onChange`는 값이 실제로 바뀔 때만 호출되어 `old == new`인 경우가 없으므로, 해당 블록은 영원히 실행되지 않는 데드 코드입니다. 반드시 커스텀 Binding의 `set`에서 가로채세요.

---

## 정리

- **NavigationStack**: `NavigationPath`로 프로그래밍 방식의 내비게이션을 구현합니다. 열거형 경로를 사용하면 타입 안전성을 확보할 수 있습니다.

- **NavigationSplitView**: iPad/macOS의 다중 컬럼 레이아웃에 적합합니다. iPhone에서는 자동으로 단일 스택처럼 동작합니다.

- **딥링크**: URL을 파싱하여 `DeepLink` 열거형으로 변환하고, `NavigationCoordinator`가 경로를 설정하는 패턴이 효과적입니다.

- **탭 + 내비게이션**: 각 탭에 독립적인 `NavigationStack`을 부여하고, 같은 탭 재탭 시 루트로 이동하는 패턴을 구현합니다.

다음 Part 3에서는 **실무 패턴과 아키텍처**를 다룹니다.
