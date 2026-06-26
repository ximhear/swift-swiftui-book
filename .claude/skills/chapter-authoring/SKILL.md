---
name: chapter-authoring
description: Swift/SwiftUI 서적의 장(chapter) 집필과 검증 피드백 통합을 수행한다. 새 장/섹션 작성, 기존 장 확장, 그리고 tech/code/editorial 검증가의 피드백을 받아 chapter.md와 examples/*.swift를 수정하는 통합 작업에 사용. "장 써줘", "섹션 확장", "피드백 반영", "검증 결과 통합" 요청 시 사용할 것.
---

# 장 집필 및 피드백 통합

chapter-author 에이전트가 사용하는 스킬. 집필과 통합 두 가지 작업 모드를 다룬다.

## 시작 전 필수 로딩
1. 프로젝트 `CLAUDE.md` — 집필 원칙(Why→How, 코드 우선, pitfall)과 마크다운 서식 규칙
2. `style-guide.md` — 문체, 용어표, 난이도 표시(🟢🟡🔴), 분량 가이드
3. `outline.md` — 대상 장의 위치와 전후 맥락

## 모드 A: 집필 (새 장/섹션 작성·확장)

전개 순서를 지킨다:
1. **도입부** — 이 장을 왜 배워야 하는지 동기 부여 (`> 한두 문장 요약` 포함)
2. **핵심 개념** — Why를 먼저, 그다음 How
3. **실습 예제** — 최소 완전 예제(MCE). 본문 코드는 `examples/`의 `.swift` 파일과 1:1 대응시킨다
4. **심화** — 공식 문서에 없는 실무 인사이트·함정
5. **정리** — 핵심 포인트 불릿

작성 규칙:
- 본문 한국어, 코드 주석 한국어(식별자는 영문), 기술 용어는 한글(영문) 병기
- 잘못된 코드(❌) → 올바른 코드(✅) 비교 패턴을 적극 활용
- 코드는 Swift 6.1 / Xcode 16 기준, strict concurrency 통과 가능하게
- 새 예제는 `chapters/chXX-*/examples/`에 `.swift` 파일로도 저장
- 그림이 필요하면 `[그림: 설명]` 플레이스홀더 또는 Mermaid 사용

## 모드 B: 피드백 통합

검증가 피드백을 받아 원고를 수정한다.

1. `_workspace/`의 피드백 파일을 **출처별로** 읽는다:
   - `*_tech_review_chXX.md` — 기술 정확성
   - `*_code_review_chXX.md` — 컴파일/예제 정합성
   - `*_editorial_review_chXX.md` — 문체/용어/서식
2. 심각도 순으로 처리: 🔴 → 🟡 → 🟢
3. 우선순위: 기술 수정(tech/code) 먼저, 문체 수정(editorial)은 의미 보존 선에서
4. **상충 처리**: 검증가 간 지적이 충돌하면 한쪽을 임의로 버리지 말고, 선택 근거를 변경 요약에 병기
5. 본문 코드를 고치면 대응되는 `examples/*.swift`도 함께 고쳐 정합성 유지

## 출력
- 수정된 `chapter.md` / `examples/*.swift`
- `_workspace/NN_author_chXX_changes.md`에 변경 요약:
  - 반영한 지적 목록(출처·심각도별)
  - 반영하지 않은 지적과 사유
  - 상충 지적과 선택 근거

## 자가 점검
- 변경 후에도 Why→How 흐름과 장 구조가 유지되는가?
- 본문 코드와 `examples/` 파일이 여전히 일치하는가?
- style-guide 용어표를 어긴 표현을 새로 만들지 않았는가?
