// Ch06 - body 재호출 최적화

import SwiftUI

// MARK: - _printChanges 디버깅

struct DebuggableView: View {
    @State private var count = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let _ = Self._printChanges()
        VStack {
            Text("카운트: \(count)")
            Button("+1") { count += 1 }
        }
    }
}

// MARK: - 전략 1: View 분리

struct SmallCounterView: View {
    @State private var counter = 0

    var body: some View {
        let _ = print("SmallCounterView body")
        VStack {
            Text("카운터: \(counter)")
            Button("+1") { counter += 1 }
        }
    }
}

struct ListItem: Identifiable {
    let id = UUID()
    var name: String
}

struct OptimizedContentView: View {
    @State private var items = [
        ListItem(name: "A"), ListItem(name: "B")
    ]

    var body: some View {
        let _ = print("ContentView body")
        VStack {
            SmallCounterView()
            // counter가 바뀌어도 이 List는 재평가 안 됨
            List(items) { item in
                Text(item.name)
            }
        }
    }
}

// MARK: - 전략 2: Equatable View

struct ExpensiveRow: View, Equatable {
    let title: String
    let subtitle: String

    var body: some View {
        let _ = print("ExpensiveRow body: \(title)")
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
    }
}

// MARK: - 전략 3: @Observable 세밀한 추적

@Observable
class AppState {
    var userName = "Swift"
    var notificationCount = 0
    var theme = "light"
}

struct HeaderView: View {
    let state: AppState

    var body: some View {
        let _ = print("HeaderView body")
        // userName만 읽음 → 다른 프로퍼티 변경 시 무반응
        Text("Hello, \(state.userName)")
    }
}

struct BadgeView: View {
    let state: AppState

    var body: some View {
        let _ = print("BadgeView body")
        // notificationCount만 읽음
        if state.notificationCount > 0 {
            Image(systemName: "bell.badge")
        } else {
            Image(systemName: "bell")
        }
    }
}
