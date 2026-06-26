// Ch13 - Swift Testing 프레임워크 예제

import Testing
import Foundation
import Observation

// MARK: - 테스트 대상 (간략화)

struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted = false
}

// @Observable ViewModel은 SwiftUI에서 통상 MainActor에 격리됩니다.
// 본문 §13.2는 Redux식 send(.add) 단방향 패턴을 보여주지만,
// 여기서는 실행 가능한 최소 예제를 위해 메서드를 직접 호출하는
// 단순화된 형태(SimpleTodoVM.add 등)를 사용합니다.
@MainActor
@Observable
final class SimpleTodoVM {
    var items: [TodoItem] = []

    func add(_ title: String) {
        guard !title.isEmpty else { return }
        items.append(TodoItem(title: title))
    }

    func toggle(_ id: UUID) {
        guard let idx = items.firstIndex(
            where: { $0.id == id }) else { return }
        items[idx].isCompleted.toggle()
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted }
    }
}

// MARK: - 테스트

// VM이 MainActor 격리이므로 Suite에도 @MainActor를 명시합니다.
// (그래야 동기 테스트에서 vm 프로퍼티에 안전하게 접근할 수 있습니다.)
@MainActor
@Suite("TodoVM 테스트")
struct TodoVMTests {
    let vm = SimpleTodoVM()

    @Test("할 일 추가")
    func addItem() {
        vm.add("테스트")
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.title == "테스트")
    }

    @Test("빈 문자열 무시")
    func addEmpty() {
        vm.add("")
        #expect(vm.items.isEmpty)
    }

    @Test("토글")
    func toggle() {
        vm.add("항목")
        let id = vm.items.first!.id
        vm.toggle(id)
        #expect(vm.items.first?.isCompleted == true)
    }

    @Test("완료 항목 삭제")
    func clearCompleted() {
        vm.add("A")
        vm.add("B")
        vm.toggle(vm.items.first!.id)
        vm.clearCompleted()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.title == "B")
    }
}

// MARK: - 매개변수화 테스트

struct EmailValidator {
    static func isValid(_ email: String) -> Bool {
        // "@"를 기준으로 local/domain 부분을 나눠 각각을 검사합니다.
        // 빈 부분을 살리기 위해 omittingEmptySubsequences: false 사용.
        let parts = email.split(
            separator: "@",
            omittingEmptySubsequences: false
        )
        guard parts.count == 2 else { return false }

        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, !domain.isEmpty else { return false }

        // 도메인은 점(.)으로 나뉜 라벨이 2개 이상이고,
        // 각 라벨이 비어 있지 않아야 합니다. ("@.com" 같은 값 거름)
        let labels = domain.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy { !$0.isEmpty }
    }
}

@Suite("이메일 유효성")
struct EmailTests {
    @Test("유효한 이메일", arguments: [
        "user@example.com",
        "first.last@domain.co.kr",
        "user+tag@gmail.com"
    ])
    func valid(_ email: String) {
        #expect(EmailValidator.isValid(email))
    }

    @Test("유효하지 않은 이메일", arguments: [
        "not-an-email",
        "@missing-local.com",
        "missing-at-sign.com",
        "@.com",
        ""
    ])
    func invalid(_ email: String) {
        #expect(!EmailValidator.isValid(email))
    }
}
