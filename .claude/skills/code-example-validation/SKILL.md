---
name: code-example-validation
description: 서적의 코드 예제를 실제 swiftc로 컴파일하여 검증한다. examples/*.swift 파일과 본문 ```swift 코드 블록이 Swift 6.1 strict concurrency에서 컴파일되는지, 본문과 예제 파일이 일치하는지 확인. "코드 컴파일 검증", "예제 돌려봐", "컴파일 되는지 확인", "본문 코드와 예제 일치 확인" 요청 시 사용할 것.
---

# 코드 예제 컴파일 검증

code-example-validator 에이전트가 사용하는 스킬. 설명이 맞아도 코드가 안 돌면
독자가 신뢰를 잃는다 — 실제 컴파일이 최우선이다.

## 환경
- 툴체인: `swiftc` (Apple Swift 6.3, Swift 6.1 코드 호환 컴파일 가능)
- 임시 작업 공간: scratchpad 디렉토리 사용 (프로젝트를 오염시키지 않는다)

## 검증 절차

### 1. examples/*.swift 파일 컴파일
```bash
# 순수 Swift 예제 — 컴파일 + 가능하면 실행
swiftc -swift-version 6 -strict-concurrency=complete <file>.swift -o /dev/null

# SwiftUI/UIKit 의존 — 타입 체크만 (실행 바이너리 불필요)
swiftc -swift-version 6 -strict-concurrency=complete -typecheck <file>.swift
```
- 컴파일 에러 → 🔴, strict concurrency 경고 → 🟡
- 결과(에러/경고 메시지)를 **그대로 인용**한다

### 2. 본문 ↔ 예제 파일 정합성 교차 비교
- `chapter.md`의 ```swift 코드 블록을 추출해 `examples/`의 대응 파일과 비교
- 불일치 패턴: 시그니처 차이, 누락된 import, 오타, 본문엔 있고 파일엔 없는 코드(또는 반대)

### 3. 의도된 "잘못된 코드" 처리
- 본문이 ❌(잘못된 예)로 명시한 코드는 컴파일 실패해도 정상 — 오류로 처리하지 않는다
- 단, "왜 실패하는지" 설명이 본문에 있는지 확인하고, 없으면 🟡로 지적

### 4. MCE 원칙 점검
- 예제가 최소 완전 예제인가 — 불필요한 의존성 없이 그 자체로 의미가 통하는가

## 한계 명시
- 툴체인/의존성으로 컴파일 불가 시 환경 한계를 명시하고 수동 검토로 대체. **임의 통과 금지.**

## 출력
`_workspace/NN_code_review_chXX.md`:
```
# 코드 검증: chXX
검증한 파일: examples/A.swift, examples/B.swift ...
사용한 명령: swiftc -swift-version 6 ...

- [🔴] examples/A.swift:12 — 컴파일 에러: "<인용>" — 권장 수정
- [🟡] 본문 §실습 코드블록 vs examples/B.swift — 시그니처 불일치 — ...
정합성/컴파일 통과 항목: (명시)
```
지적이 없으면 "코드 검증 통과"를 명시한다. 코드를 직접 수정하지 않는다.
