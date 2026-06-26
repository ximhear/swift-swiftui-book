---
name: book-harness
description: Swift/SwiftUI 서적의 집필·검증·품질 강화를 조율하는 오케스트레이터. 장(chapter) 검증("ch03 검토", "동시성 장 정확성 확인"), 품질 강화("코드 컴파일되는지 다 확인", "용어 일관성 맞춰줘"), 집필("새 섹션 써줘"), 그리고 검증→수정 통합 전 과정을 에이전트 팀으로 수행. "장 검토/검증", "품질 강화", "코드 예제 검증", "편집 점검", "다시 검증", "재실행", "이전 결과 보완", "피드백 반영" 등 서적 작업 요청 시 반드시 이 스킬을 사용할 것. 단순 단일 질문은 직접 응답 가능.
---

# Book Harness — 서적 집필·검증 오케스트레이터

Swift/SwiftUI 서적 프로젝트의 작업을 **에이전트 팀**으로 조율한다.
패턴: **생성-검증(generation-verification)** + 검증 팬아웃. 검증·품질 강화가 주력.

## 팀 구성 (model: opus 고정)
| 에이전트 | 타입 | 역할 | 스킬 |
|----------|------|------|------|
| chapter-author | general-purpose | 집필 + 피드백 통합 | chapter-authoring |
| swift-tech-reviewer | general-purpose | Swift 6.1 기술 정확성 | swift-correctness-review |
| code-example-validator | general-purpose | 실제 컴파일 검증 | code-example-validation |
| editorial-reviewer | general-purpose | 문체·용어·서식 | editorial-consistency |

> 모든 Agent 호출에 반드시 `model: "opus"` 명시. 에이전트는 `.claude/agents/{name}.md`에 정의됨.

## Phase 0: 컨텍스트 확인 (항상 먼저)
1. 대상 장/범위를 파악한다 (사용자가 "ch03", "동시성 장" 등으로 지정).
2. `_workspace/` 존재 여부와 사용자 의도로 실행 모드를 판별:
   - `_workspace/` 없음 → **초기 실행**
   - `_workspace/` 있음 + 부분 수정 요청("editorial만 다시") → **부분 재실행** (해당 에이전트만 재호출)
   - `_workspace/` 있음 + 새 장/새 입력 → **새 실행** (기존 `_workspace/`를 `_workspace_prev/`로 이동 후 시작)
3. 작업 디렉토리 하위에 `_workspace/` 생성. 파일명 컨벤션: `{NN}_{agent}_{artifact}.md`.

## Phase 1: 검증 (팬아웃 — 병렬)
**실행 모드: 에이전트 팀**

1. `TeamCreate`로 팀 구성, `TaskCreate`로 대상 장 검증 작업 할당.
2. 세 검증가를 **병렬**로 실행 — 서로 독립적이므로 동시 진행:
   - swift-tech-reviewer → `_workspace/01_tech_review_chXX.md`
   - code-example-validator → `_workspace/02_code_review_chXX.md`
   - editorial-reviewer → `_workspace/03_editorial_review_chXX.md`
3. tech-reviewer와 code-validator의 코드 지적이 겹치면 SendMessage로 조율 (컴파일 사실은 code-validator 우선).
4. 각 검증가는 본문/코드를 **직접 수정하지 않는다** — 피드백 파일만 작성.

## Phase 2: 통합 (수정)
**실행 모드: 에이전트 팀 (author 단독 작업)**

1. chapter-author가 세 피드백 파일을 출처별로 읽고 심각도순(🔴→🟡→🟢)으로 반영.
2. 본문 코드 수정 시 대응 `examples/*.swift`도 함께 수정 (정합성).
3. 상충 지적은 임의로 버리지 않고 선택 근거를 변경 요약에 병기.
4. 출력: 수정된 `chapter.md`/`examples/`, `_workspace/04_author_chXX_changes.md`.

## Phase 3: 재검증 (선택)
- 🔴 지적이 많았거나 사용자가 요청하면, 수정된 장을 검증가에게 1회 재검증시킨다 (incremental QA).
- 재검증가는 이전 검증 파일을 읽고 해소된 항목은 제외, 신규/잔존 이슈만 보고.

## 집필 모드 (검증이 아닌 작성 요청 시)
"새 장/섹션 써줘" 요청이면 순서를 바꾼다: chapter-author가 먼저 집필(chapter-authoring 모드 A) → Phase 1 검증 → Phase 2 통합. 빈 장 확장도 동일.

## 데이터 전달 프로토콜
- **태스크 기반**(TaskCreate/TaskUpdate): 진행상황·의존관계 추적
- **파일 기반**(`_workspace/`): 피드백·변경 요약 등 산출물. 중간 파일 보존(감사 추적)
- **메시지 기반**(SendMessage): 검증가 간 조율, author↔검증가 명확화 질의
- 최종 산출물은 `chapters/chXX-*/`에 직접 반영. `_workspace/`는 보존.

## 에러 핸들링
- 에이전트 1회 재시도 후 재실패 → 해당 검증 없이 진행하되, 최종 보고에 **누락 명시**.
- 컴파일 환경 한계로 검증 불가 → 임의 통과 금지, 수동 검토로 대체하고 한계 명시.
- 검증가 간 상충 → 데이터 삭제 금지, 출처 병기 후 author가 판단.
- 대상 파일/장이 모호 → 추측 금지, 사용자에게 정확한 장 번호/범위 질의.

## 완료 후
1. 사용자에게 결과 요약 보고: 장별 🔴/🟡/🟢 건수, 반영/미반영 항목, 누락된 검증.
2. **피드백 기회 제공**: "검증 깊이나 팀 구성에서 바꾸고 싶은 점이 있나요?"
3. 반복 피드백(같은 유형 2회+)이나 에이전트 반복 실패 패턴이 보이면 하네스 진화를 제안하고, CLAUDE.md 변경 이력에 기록.

## 테스트 시나리오
**정상 흐름**: "ch03 동시성 장 검증해줘"
→ Phase 0(초기 실행, `_workspace/` 생성) → Phase 1(3검증가 병렬, 3개 피드백 파일) → Phase 2(author 통합, ch03/chapter.md + examples 수정, 변경요약) → 결과 보고.

**에러 흐름**: "ch08 전체 코드 컴파일 확인" 중 일부 예제가 SwiftUI 의존으로 단독 컴파일 불가
→ code-validator가 `-typecheck`로 가능 범위까지 검증 → 실행 불가 항목은 환경 한계 명시 + 수동 검토 → 최종 보고에 "컴파일 미검증 N건(환경 한계)" 명시. 임의 통과하지 않음.
