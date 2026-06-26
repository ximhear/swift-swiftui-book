// Ch10 - Navigation 아키텍처 예제

import SwiftUI

// MARK: - 도메인 모델

struct Product: Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
}

struct Category: Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var products: [Product] = []
}

// MARK: - 타입 안전 경로

enum AppRoute: Hashable {
    case productList(Category)
    case productDetail(Product)
    case cart
    case checkout
    case orderConfirmation(orderId: String)
}

// MARK: - 프로그래밍 방식 내비게이션

struct TypeSafeNavigationDemo: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Button("상품 상세") {
                    path.append(.productDetail(
                        Product(name: "MacBook")))
                }
                Button("루트로") {
                    path.removeAll()
                }
            }
            .navigationTitle("홈")
            .navigationDestination(
                for: AppRoute.self
            ) { route in
                switch route {
                case .productList(let cat):
                    Text("카테고리: \(cat.name)")
                case .productDetail(let prod):
                    Text("상품: \(prod.name)")
                case .cart:
                    Text("장바구니")
                case .checkout:
                    Text("결제")
                case .orderConfirmation(let orderId):
                    Text("주문 완료: \(orderId)")
                }
            }
        }
    }
}

// MARK: - 딥링크

enum DeepLink {
    case product(id: String)
    case category(id: String)
    case cart
    case settings

    init?(url: URL) {
        // 커스텀 스킴은 host가 첫 경로 토큰이고,
        // Universal Link는 host가 도메인이므로 path만 사용한다.
        // - myapp://product/12345  → host="product", path="/12345"
        // - https://myapp.com/product/12345 → path="/product/12345"
        let pathTokens = url.pathComponents.filter { $0 != "/" }
        let segments: [String]
        if url.scheme == "https" || url.scheme == "http" {
            segments = pathTokens
        } else {
            segments = (url.host().map { [$0] } ?? []) + pathTokens
        }

        guard let first = segments.first else { return nil }
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

// MARK: - 탭 + 내비게이션 (재탭 시 루트로 이동)

enum AppTab: Hashable {
    case home, search, profile
}

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
                value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    Text("홈 화면")
                        .navigationTitle("홈")
                }
            }
            Tab("검색", systemImage: "magnifyingglass",
                value: AppTab.search) {
                NavigationStack(path: $searchPath) {
                    Text("검색")
                        .navigationTitle("검색")
                }
            }
            Tab("프로필", systemImage: "person",
                value: AppTab.profile) {
                NavigationStack(path: $profilePath) {
                    Text("프로필")
                        .navigationTitle("프로필")
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

#Preview { TypeSafeNavigationDemo() }
