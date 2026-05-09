# Chapter 10. Navigation 아키텍처

> SwiftUI의 Navigation은 iOS 16에서 `NavigationStack`과 `NavigationSplitView` 도입으로 크게 개선되었습니다. 프로그래밍 방식의 내비게이션, 딥링크 처리, 복잡한 탭+내비게이션 복합 구조까지 — 이 장에서는 실무에서 만나는 모든 내비게이션 시나리오를 체계적으로 다룹니다.

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

### 타입 안전한 Navigation 경로

🟡 중급

```swift
// Navigation 경로를 열거형으로 정의
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

```swift
struct SplitNavigation: View {
    @State private var selectedCategory: Category?
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(categories, selection: $selectedCategory) {
                category in
                Text(category.name)
            }
            .navigationTitle("카테고리")
        } content: {
            // 중간 패널
            if let category = selectedCategory {
                List(category.products,
                     selection: $selectedProduct) {
                    product in
                    Text(product.name)
                }
                .navigationTitle(category.name)
            } else {
                Text("카테고리를 선택하세요")
            }
        } detail: {
            // 상세 패널
            if let product = selectedProduct {
                ProductDetailView(product: product)
            } else {
                Text("상품을 선택하세요")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

---

## 10.3 딥링크 처리 전략

🔴 고급

```swift
// URL 스킴: myapp://product/12345
// Universal Link: https://myapp.com/product/12345

enum DeepLink {
    case product(id: String)
    case category(id: String)
    case cart
    case settings
    
    init?(url: URL) {
        let components = url.pathComponents
            .filter { $0 != "/" }
        
        guard let first = components.first else {
            return nil
        }
        
        switch first {
        case "product":
            guard let id = components.dropFirst().first
            else { return nil }
            self = .product(id: id)
        case "category":
            guard let id = components.dropFirst().first
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
    var searchPath: [AppRoute] = []
    
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

/// > **Note**: `Tab("...", systemImage:value:)` 문법은 **iOS 18+**에서 사용 가능합니다.
/// > iOS 17 이하에서는 `.tabItem { Label(...) }` 문법을 사용하세요.

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

## 10.4 탭 기반 + 네비게이션 복합 구조

### 각 탭의 독립적 NavigationStack

```swift
/// > **Note**: `Tab("...", systemImage:value:)` 문법은 **iOS 18+**에서 사용 가능합니다.
/// > iOS 17 이하에서는 `.tabItem { Label(...) }` 문법을 사용하세요.

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    
    var body: some View {
        TabView(selection: $selectedTab) {
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
        .onChange(of: selectedTab) { oldTab, newTab in
            // 같은 탭을 다시 탭하면 루트로 이동
            if oldTab == newTab {
                switch newTab {
                case .home: homePath.removeLast(homePath.count)
                case .search: searchPath.removeLast(searchPath.count)
                case .profile: profilePath.removeLast(profilePath.count)
                }
            }
        }
    }
}

enum AppTab: Hashable {
    case home, search, profile
}
```

---

## 정리

- **NavigationStack**: `NavigationPath`로 프로그래밍 방식의 내비게이션을 구현합니다. 열거형 경로를 사용하면 타입 안전성을 확보할 수 있습니다.

- **NavigationSplitView**: iPad/macOS의 다중 컬럼 레이아웃에 적합합니다. iPhone에서는 자동으로 단일 스택처럼 동작합니다.

- **딥링크**: URL을 파싱하여 `DeepLink` 열거형으로 변환하고, `NavigationCoordinator`가 경로를 설정하는 패턴이 효과적입니다.

- **탭 + 내비게이션**: 각 탭에 독립적인 `NavigationStack`을 부여하고, 같은 탭 재탭 시 루트로 이동하는 패턴을 구현합니다.

다음 Part 3에서는 **실무 패턴과 아키텍처**를 다룹니다.
