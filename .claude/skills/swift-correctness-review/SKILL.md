---
name: swift-correctness-review
description: 서적 본문의 Swift/SwiftUI 기술 정확성을 Swift 6.1 / Xcode 16 기준으로 검증한다. Strict Concurrency(Sendable, Actor 격리, @MainActor), 최신 SwiftUI API(@Observable 등), 타입 시스템(값/참조, COW, any/some) 설명의 사실 여부를 검수. "기술 검토", "정확성 검증", "동시성 검토", "Swift 6 맞는지 확인" 요청 시 사용할 것.
---

# Swift 기술 정확성 검증

swift-tech-reviewer 에이전트가 사용하는 스킬. 본문의 기술적 주장이 사실인지 검증한다.

## 검증 차원

### 1. Concurrency (Swift 6.1 strict)
- `Sendable` / `@Sendable` 적용이 정확한가 — 비-Sendable 타입을 actor 경계로 넘기는 설명은 없는가
- Actor 격리 설명: 격리된 상태 접근, `nonisolated`, actor reentrancy, hop 비용
- `@MainActor` 사용과 UI 업데이트 설명이 Swift 6 격리 모델과 맞는가
- data race가 컴파일 타임에 잡히는 시나리오를 정확히 기술했는가
- region-based isolation, `sending` 등 6.x 신규 개념의 정확성

### 2. 최신 API
- `@Observable`(Observation) vs `ObservableObject` — 마이그레이션 설명이 정확한가
- deprecated API(`.onChange(of:perform:)` 구형 시그니처 등)를 권장하고 있지 않은가
- async/await, `TaskGroup`, `AsyncStream` 패턴의 정확성

### 3. 타입 시스템
- 값/참조 타입 성능 특성, COW 트리거 조건
- existential(`any`) vs opaque(`some`)의 동작과 성능 차이
- 제네릭/연관 타입/primary associated type 설명

## 검증 방법
1. 본문 주장을 읽고, **설명과 실제 컴파일러 동작을 교차 비교**한다.
2. 버전에 민감하거나 불확실한 주장은 추측하지 말고:
   - `swiftc -strict-concurrency=complete -swift-version 6 -typecheck`로 최소 스니펫을 만들어 확인 (swift 6.3 툴체인 사용 가능)
   - 또는 WebSearch/WebFetch로 공식 문서(Swift Evolution, developer.apple.com) 확인
3. 확정할 수 없으면 "확인 불가 — 근거 필요"로 표기 (임의 통과/탈락 금지)

## 심각도 분류
- 🔴 **오류**: 사실과 다름. 그대로 두면 독자가 틀린 지식을 얻음
- 🟡 **부정확**: 오해의 소지가 있거나 버전 한정 사실을 일반화
- 🟢 **개선**: 더 정확하거나 최신인 표현 제안

## 출력
`_workspace/NN_tech_review_chXX.md`:
```
# 기술 검증: chXX
- [🔴] 섹션명/대략적 위치 — 문제 설명 — 근거(컴파일 결과/문서 링크) — 권장 수정
- [🟡] ...
검증 통과 항목: (있으면 명시)
```
지적이 없으면 "기술 검증 통과"를 명시한다. 본문을 직접 수정하지 않는다.
