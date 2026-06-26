// Chapter 3 — Region-based Isolation 예제 (Builder 패턴)
//
// 빌드 및 실행:
//   swiftc -swift-version 6 -parse-as-library RegionBasedIsolation.swift -o /tmp/RegionBasedIsolation
//   /tmp/RegionBasedIsolation
//
// 핵심: FormBuilder는 Sendable이 아니지만, Swift 6 region 분석 덕분에
//       세 가지 패턴 모두 컴파일을 통과한다.

import Foundation

// MARK: - Sendable이 아닌 빌더

final class FormBuilder {
    var fields: [String: String] = [:]
    var attachments: [Data] = []

    func setField(_ key: String, _ value: String) {
        fields[key] = value
    }

    func addAttachment(_ data: Data) {
        attachments.append(data)
    }
}

// MARK: - 폼을 받아 큐잉하는 actor

actor SubmissionService {
    private var queue: [FormBuilder] = []

    func submit(_ form: FormBuilder) {
        // actor 내부에서는 격리되어 안전하게 사용 가능
        queue.append(form)
        print(
            "  ✓ submitted: fields=\(form.fields.count), " +
            "attachments=\(form.attachments.count)"
        )
    }

    var pending: Int { queue.count }
}

// MARK: - 실행

@main
struct Demo {
    static func main() async {
        let service = SubmissionService()

        print("=== Region-based Isolation 데모 ===\n")

        // ✅ 케이스 1 — 로컬에서 만들고 actor에 넘긴 뒤 사용 안 함
        print("[1] 로컬 생성 후 핸드오프")
        do {
            let form = FormBuilder()
            form.setField("name", "Alice")
            form.setField("email", "alice@example.com")
            form.addAttachment(Data([0x01, 0x02]))
            await service.submit(form)
            // form 변수의 region이 여기서 종료됨
            // print(form.fields)  // ← 주석 풀면 컴파일 에러 (region 위반)
        }

        // ✅ 케이스 2 — 분기로 구성된 객체 전달
        print("\n[2] 조건부로 구성된 객체 핸드오프")
        let needsExtra = true
        do {
            let form = FormBuilder()
            form.setField("name", "Bob")
            if needsExtra {
                form.addAttachment(Data(repeating: 0, count: 1024))
            }
            await service.submit(form)
        }

        // ✅ 케이스 3 — 함수가 sending으로 반환한 객체 전달
        print("\n[3] sending 반환으로 받은 객체 핸드오프")
        func buildForm(name: String) -> sending FormBuilder {
            let f = FormBuilder()
            f.setField("name", name)
            return f
        }
        await service.submit(buildForm(name: "Charlie"))

        let total = await service.pending
        print("\n총 pending: \(total)")
        print("\n(세 케이스 모두 FormBuilder가 Sendable이 아니어도 통과)")
    }
}
