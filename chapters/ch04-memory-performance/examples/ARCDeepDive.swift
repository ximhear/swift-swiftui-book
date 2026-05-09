// Ch04 - ARC 심화와 weak/unowned

import Foundation

// MARK: - 클로저 캡처 주의사항

class DataProcessor {
    var data: [Int] = Array(repeating: 0, count: 100_000)

    // ❌ self 전체가 캡처됨
    func processAsyncBad() {
        DispatchQueue.global().async {
            let count = self.data.count
            print("처리 완료: \(count)건")
        }
    }

    // ✅ 필요한 값만 캡처
    func processAsyncGood() {
        let count = data.count
        DispatchQueue.global().async {
            print("처리 완료: \(count)건")
        }
    }
}

// MARK: - weak 참조

class Parent {
    var child: Child?
    let name: String
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

class Child {
    weak var parent: Parent?
    let name: String
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

// MARK: - unowned 참조

class Customer {
    var card: CreditCard?
    let name: String
    init(name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

class CreditCard {
    unowned let owner: Customer
    let number: String

    init(owner: Customer, number: String) {
        self.owner = owner
        self.number = number
    }
    deinit { print("카드 \(number) 해제") }
}

// MARK: - 일반적인 누수 패턴과 수정

class SearchController {
    var debounceTimer: Timer?

    deinit { print("SearchController 해제") }

    // ✅ weak self로 순환 참조 방지
    func setupSearch() {
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: true
        ) { [weak self] _ in
            self?.performSearch()
        }
    }

    func performSearch() { }
}

// delegate는 반드시 weak
protocol DataSourceDelegate: AnyObject {
    func didLoadData(_ data: [String])
}

class DataSource {
    weak var delegate: DataSourceDelegate?
}
