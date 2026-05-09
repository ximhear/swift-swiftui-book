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

@Observable
class SimpleTodoVM {
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
        email.contains("@") && email.contains(".")
            && !email.isEmpty
    }
}

@Suite("이메일 유효성")
struct EmailTests {
    @Test("유효한 이메일", arguments: [
        "user@example.com",
        "a@b.co"
    ])
    func valid(_ email: String) {
        #expect(EmailValidator.isValid(email))
    }

    @Test("유효하지 않은 이메일", arguments: [
        "no-at-sign",
        "",
        "@.com"
    ])
    func invalid(_ email: String) {
        #expect(!EmailValidator.isValid(email))
    }
}
