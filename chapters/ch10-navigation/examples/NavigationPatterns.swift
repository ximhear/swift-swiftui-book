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

    init?(url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let first = parts.first else { return nil }
        switch first {
        case "product":
            guard let id = parts.dropFirst().first
            else { return nil }
            self = .product(id: id)
        case "category":
            guard let id = parts.dropFirst().first
            else { return nil }
            self = .category(id: id)
        case "cart":
            self = .cart
        default:
            return nil
        }
    }
}

// MARK: - 탭 + 내비게이션

enum TabItem: Hashable {
    case home, search, profile
}

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var homePath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("홈", systemImage: "house",
                value: TabItem.home) {
                NavigationStack(path: $homePath) {
                    Text("홈 화면")
                        .navigationTitle("홈")
                }
            }
            Tab("검색", systemImage: "magnifyingglass",
                value: TabItem.search) {
                NavigationStack {
                    Text("검색")
                        .navigationTitle("검색")
                }
            }
        }
    }
}

#Preview { TypeSafeNavigationDemo() }
