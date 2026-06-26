// Ch06 - View Identity와 생명주기

import SwiftUI

// MARK: - Structural Identity

struct ParentView: View {
    @State private var name = "SwiftUI"
    @State private var counter = 0

    var body: some View {
        let _ = print("ParentView body 호출")
        VStack {
            ChildView(name: name)
            Button("카운터: \(counter)") {
                counter += 1
            }
        }
    }
}

struct ChildView: View {
    let name: String

    var body: some View {
        let _ = print("ChildView body 호출: \(name)")
        Text("Hello, \(name)")
    }
}

// MARK: - if-else와 Identity 문제

struct ProfileView: View {
    @State private var isEditing = false
    @State private var name = "Swift"

    var body: some View {
        VStack {
            if isEditing {
                // Identity A
                TextField("이름", text: $name)
                    .textFieldStyle(.roundedBorder)
            } else {
                // Identity B — 다른 View로 인식됨
                Text(name).font(.title)
            }
            Toggle("편집 모드", isOn: $isEditing)
        }
    }
}

// MARK: - Explicit Identity

struct AnimatedCounter: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.largeTitle)
                .id(count)  // count마다 새 Identity
                .transition(.push(from: .bottom))

            Button("증가") {
                withAnimation { count += 1 }
            }
        }
    }
}

// MARK: - ForEach Identity

struct Item: Identifiable {
    let id = UUID()
    var name: String
}

struct ItemListView: View {
    @State private var items: [Item] = [
        Item(name: "사과"),
        Item(name: "바나나"),
        Item(name: "체리")
    ]

    var body: some View {
        List {
            // ✅ Identifiable의 id 사용
            ForEach(items) { item in
                Text(item.name)
            }
        }
    }
}

// MARK: - View 생명주기

struct LifecycleView: View {
    @State private var data: [String] = []

    init() {
        // ⚠️ 부모가 이 View를 다시 생성할 때마다(부모 body 재평가 시)
        // init이 호출될 수 있음 — 무거운 작업을 여기서 하지 마세요!
        print("init 호출")
    }

    var body: some View {
        List(data, id: \.self) { Text($0) }
            .onAppear { print("onAppear") }
            .onDisappear { print("onDisappear") }
            .task {
                // onAppear의 async 버전, View가 사라지면 자동 취소
                data = await loadData()
            }
    }

    func loadData() async -> [String] {
        try? await Task.sleep(for: .seconds(1))
        return ["항목 1", "항목 2", "항목 3"]
    }
}
