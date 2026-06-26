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

// 액션 정의
enum TodoAction {
    case updateText(String)   // 텍스트 입력도 액션으로 처리
    case add(String)
    case toggle(UUID)
    case delete(UUID)
    case clearCompleted
}

// 상태 정의
struct TodoState {
    var items: [TodoItem] = []
    var newItemText = ""

    var activeCount: Int {
        items.filter { !$0.isCompleted }.count
    }
}

struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted = false
}

// ViewModel: 상태 + 액션 처리
@Observable
class TodoViewModel {
    private(set) var state = TodoState()

    func send(_ action: TodoAction) {
        switch action {
        case .updateText(let text):
            // 입력 변경도 ViewModel을 거치게 해 단방향 흐름 유지
            state.newItemText = text
        case .add(let title):
            guard !title.isEmpty else { return }
            state.items.append(TodoItem(title: title))
            state.newItemText = ""
        case .toggle(let id):
            guard let idx = state.items.firstIndex(
                where: { $0.id == id }) else { return }
            state.items[idx].isCompleted.toggle()
        case .delete(let id):
            state.items.removeAll { $0.id == id }
        case .clearCompleted:
            state.items.removeAll { $0.isCompleted }
        }
    }
}

// View: 상태를 읽고 액션을 보냄
struct TodoView: View {
    @State private var viewModel = TodoViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.state.items) { item in
                    HStack {
                        Image(systemName: item.isCompleted
                            ? "checkmark.circle.fill"
                            : "circle")
                            .onTapGesture {
                                viewModel.send(.toggle(item.id))
                            }
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = viewModel.state.items[index].id
                        viewModel.send(.delete(id))
                    }
                }
            }
            .navigationTitle(
                "할 일 (\(viewModel.state.activeCount))")
            .toolbar {
                Button("완료 항목 삭제") {
                    viewModel.send(.clearCompleted)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    // private(set) 캡슐화를 지키면서, 입력도
                    // send(_:)를 통해서만 상태를 바꾼다.
                    TextField(
                        "새 할 일",
                        text: Binding(
                            get: { viewModel.state.newItemText },
                            set: { viewModel.send(.updateText($0)) }
                        )
                    )
                    Button("추가") {
                        viewModel.send(
                            .add(viewModel.state.newItemText))
                    }
                }
                .padding()
            }
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
