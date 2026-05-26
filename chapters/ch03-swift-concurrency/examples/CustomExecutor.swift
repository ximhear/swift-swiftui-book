// Chapter 3 — Custom Executor 예제
//
// 빌드 및 실행:
//   swiftc -swift-version 6 -parse-as-library CustomExecutor.swift -o /tmp/CustomExecutor
//   /tmp/CustomExecutor
//
// 예상 출력: 모든 insert가 동일한 NSThread 번호로 찍힘 (= 커스텀 큐가 정상 동작)

import Foundation

// MARK: - Custom SerialExecutor

/// 특정 DispatchQueue에서 직렬로 실행되는 Custom SerialExecutor
final class DispatchQueueExecutor: SerialExecutor {
    private let queue: DispatchQueue

    init(label: String) {
        self.queue = DispatchQueue(label: label)
    }

    /// 런타임이 실행해달라고 넘기는 ExecutorJob을 큐로 디스패치
    func enqueue(_ job: consuming ExecutorJob) {
        // ExecutorJob은 move-only 타입이라 클로저에 직접 캡처할 수 없다.
        // UnownedJob으로 변환해 캡처하고, 클로저 안에서 동기 실행시킨다.
        let unownedJob = UnownedJob(job)
        let unownedExecutor = asUnownedSerialExecutor()
        queue.async {
            unownedJob.runSynchronously(on: unownedExecutor)
        }
    }

    /// 런타임이 이 executor를 가리키는 unowned 핸들을 만드는 표준 방식
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}

// MARK: - Custom Executor를 사용하는 Actor

actor DatabaseActor {
    private let _executor: DispatchQueueExecutor

    init() {
        self._executor = DispatchQueueExecutor(label: "com.app.database")
    }

    /// Actor의 실행 컨텍스트를 커스텀 executor로 지정
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        _executor.asUnownedSerialExecutor()
    }

    private var rows: [String] = []

    func insert(_ row: String) {
        // 항상 "com.app.database" 큐(=동일 백그라운드 스레드)에서 실행됨
        let threadInfo = Thread.current.description
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(60)
        rows.append(row)
        print("  [thread: \(threadInfo)] insert(\"\(row)\") → total=\(rows.count)")
    }

    func count() -> Int { rows.count }
}

// MARK: - 실행

@main
struct CustomExecutorDemo {
    static func main() async {
        print("=== Custom Executor 데모 ===")
        print("모든 insert 호출이 동일한 백그라운드 스레드(=커스텀 큐)에서 직렬 실행되는지 확인\n")

        let db = DatabaseActor()
        await db.insert("alice")
        await db.insert("bob")
        await db.insert("charlie")

        let total = await db.count()
        print("\n최종 row 개수: \(total)")
        print("(모든 insert가 같은 스레드 번호로 찍혔다면 ✓)")
    }
}
