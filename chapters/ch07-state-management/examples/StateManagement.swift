// Ch07 - 상태 관리 종합 예제

import SwiftUI

// MARK: - @State + @Binding

struct RatingView: View {
    @Binding var rating: Int
    let maxRating: Int

    var body: some View {
        HStack {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating
                    ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .onTapGesture { rating = star }
            }
        }
    }
}

struct ReviewView: View {
    @State private var userRating = 0

    var body: some View {
        VStack {
            Text("평점을 선택하세요")
            RatingView(rating: $userRating, maxRating: 5)
            Text("선택: \(userRating)")
        }
    }
}

// MARK: - @Observable + 단방향 데이터 흐름

enum TodoAction {
    case add(String)
    case toggle(UUID)
    case delete(UUID)
    case clearCompleted
}

struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted = false
}

@Observable
class TodoViewModel {
    var items: [TodoItem] = []
    var newItemText = ""

    var activeCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    func send(_ action: TodoAction) {
        switch action {
        case .add(let title):
            guard !title.isEmpty else { return }
            items.append(TodoItem(title: title))
            newItemText = ""
        case .toggle(let id):
            guard let idx = items.firstIndex(
                where: { $0.id == id }) else { return }
            items[idx].isCompleted.toggle()
        case .delete(let id):
            items.removeAll { $0.id == id }
        case .clearCompleted:
            items.removeAll { $0.isCompleted }
        }
    }
}

// MARK: - 커스텀 Environment

struct AppTheme {
    var primaryColor: Color
    var cornerRadius: CGFloat
    var spacing: CGFloat

    static let standard = AppTheme(
        primaryColor: .blue, cornerRadius: 12, spacing: 16)
    static let compact = AppTheme(
        primaryColor: .blue, cornerRadius: 8, spacing: 8)
}

struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.standard
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

struct ThemedButton: View {
    @Environment(\.appTheme) var theme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(theme.spacing)
                .background(theme.primaryColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(
                    cornerRadius: theme.cornerRadius))
        }
    }
}

// MARK: - 의존성 주입

@Observable
class AuthService {
    var currentUser: String?
    var isAuthenticated: Bool { currentUser != nil }

    func signIn(name: String) { currentUser = name }
    func signOut() { currentUser = nil }
}
