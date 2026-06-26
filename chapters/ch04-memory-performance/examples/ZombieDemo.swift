// Ch04 - 좀비 객체(zombie object) 관찰 데모
//
// 빌드 및 실행:
//   swiftc -parse-as-library ZombieDemo.swift -o /tmp/ZombieDemo
//   /tmp/ZombieDemo
//
// 핵심:
//   - Strong RC = 0 → deinit 호출 + 저장 프로퍼티 해제 (논리적 파괴)
//   - Unowned RC = 0 → 객체 헤더 자체 free (물리적 해제)
//   - 두 시점이 분리되어 있어, deinit된 후에도 헤더 메모리는 잠시 남는다 = 좀비
//
// [4]의 주석을 풀면 좀비 접근 시 정의된 트랩이 발생하는 것을 확인할 수 있다.

import Foundation

final class Big {
    var buffer = [UInt8](repeating: 0xAB, count: 1_000_000)  // 1MB 콘텐츠
    let id: Int

    init(_ id: Int) {
        self.id = id
        print("  init(\(id))  → 1MB buffer 할당")
    }

    deinit {
        // 들어왔다는 건 strong RC = 0이라는 뜻
        // buffer를 포함한 저장 프로퍼티가 곧 해제됨
        print("  deinit(\(id)) → 1MB buffer 해제 (객체 헤더는 아직 살아있음)")
    }
}

final class UnownedHolder {
    unowned let ref: Big   // strong이 아니므로 strong RC를 올리지 않음
    init(_ b: Big) { self.ref = b }
    deinit { print("  UnownedHolder.deinit → 이제서야 객체 헤더가 free됨") }
}

func address(_ obj: AnyObject) -> UnsafeMutableRawPointer {
    Unmanaged.passUnretained(obj).toOpaque()
}

@main
struct ZombieDemo {
    static func main() {
        print("=== 좀비 객체 데모 ===\n")

        print("[1] 객체 생성")
        var strong: Big? = Big(42)
        let addr = address(strong!)
        print("  객체 주소: \(addr)\n")

        print("[2] unowned 참조 생성 (strong RC = 1, unowned RC = 2)")
        let holder = UnownedHolder(strong!)
        print("  holder.ref.id = \(holder.ref.id)  ← 정상 접근\n")

        print("[3] strong = nil → strong RC = 0")
        strong = nil
        // deinit이 호출됨. 1MB buffer는 이 시점에 풀린다.
        // 하지만 holder.ref가 unowned로 잡고 있으므로 객체 헤더는 그 자리에 남는다.
        // = 좀비 상태
        print("  ↑ deinit이 호출됐지만 주소(\(addr))는 아직 재사용 금지\n")

        print("[4] 좀비 객체에 unowned로 접근하면?")
        // 아래 주석을 풀면 즉시 트랩 발생:
        //   "Attempted to read an unowned reference but object <addr> was already destroyed"
        // 헤더가 살아있기 때문에 런타임이 트랩을 보장할 수 있다.
        // print("  값: \(holder.ref.id)")  // ← 풀면 런타임 크래시
        print("  (주석을 풀면 정의된 크래시)\n")

        print("[5] holder 스코프 종료 → unowned RC = 0 → 헤더 free")
        // main 종료 직전에 holder가 deinit되면서 비로소 객체 헤더 메모리도 반환된다.
    }
}
