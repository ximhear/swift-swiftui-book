# Swift/SwiftUI 심화 가이드

Swift 및 SwiftUI 중고급 개발자를 대상으로 한 한국어 기술 서적의 원고 저장소입니다.

> 작업 상태: 📝 초안 작성 중 · Swift 6.1 / Xcode 16 기준

## 누구를 위한 책인가

- Swift 기본 문법은 이해하지만 **왜(Why)** 그렇게 동작하는지 더 깊이 알고 싶은 개발자
- SwiftUI로 간단한 앱을 만들어봤지만 **렌더링/상태 관리/성능**의 내부 동작이 궁금한 개발자
- 공식 문서에는 없는 **실무 인사이트와 함정(pitfall)**을 찾는 개발자

## 목차

### Part 1. Swift 심화
- **Ch01.** [Swift 타입 시스템의 깊은 이해](chapters/ch01-swift-type-system/chapter.md) — 값/참조 타입, COW, Existential, `any` vs `some`
- **Ch02.** [제네릭과 프로토콜 고급 패턴](chapters/ch02-generics-protocols/chapter.md) — Associated Type, Type Erasure, Opaque Return Type
- **Ch03.** [Swift Concurrency 완전 정복](chapters/ch03-swift-concurrency/chapter.md) — Structured Concurrency, Actor, Sendable, MainActor
- **Ch04.** [메모리 관리와 성능 최적화](chapters/ch04-memory-performance/chapter.md) — ARC 심화, weak/unowned, COW 커스텀 구현
- **Ch05.** [Swift Macro](chapters/ch05-swift-macro/chapter.md) — Freestanding/Attached Macro, SwiftSyntax

### Part 2. SwiftUI 아키텍처
- **Ch06.** [SwiftUI 렌더링 엔진의 이해](chapters/ch06-swiftui-rendering/chapter.md) — body 호출 시점, View Identity, 생명주기
- **Ch07.** [상태 관리 마스터 클래스](chapters/ch07-state-management/chapter.md) — `@State`/`@Binding`/`@Environment`, `@Observable` 마이그레이션
- **Ch08.** [커스텀 레이아웃과 그래픽](chapters/ch08-custom-layout/chapter.md) — Layout 프로토콜, Canvas, Shape
- **Ch09.** [애니메이션과 트랜지션 심화](chapters/ch09-animation/chapter.md) — AnimatableData, matchedGeometryEffect, PhaseAnimator
- **Ch10.** [Navigation 아키텍처](chapters/ch10-navigation/chapter.md) — NavigationStack/SplitView, 딥링크

### Part 3. 실무 패턴과 아키텍처
- **Ch11.** [SwiftUI 앱 아키텍처](chapters/ch11-architecture/chapter.md) — MVVM을 넘어서, TCA, 모듈화
- **Ch12.** [네트워크와 데이터 계층](chapters/ch12-network-data/chapter.md) — async/await, 캐싱, SwiftData
- **Ch13.** [테스트 전략](chapters/ch13-testing/chapter.md) — Swift Testing, ViewInspector, Snapshot 테스트
- **Ch14.** [성능 프로파일링과 최적화](chapters/ch14-profiling/chapter.md) — Instruments, Lazy 컨테이너, 이미지 최적화

### 부록
- **A.** [Swift 6.1 주요 변경 사항](appendix/appendix-a-swift61.md)
- **B.** [SwiftUI API 버전별 변경 이력](appendix/appendix-b-swiftui-versions.md)
- **C.** [유용한 도구와 라이브러리](appendix/appendix-c-tools.md)
- **D.** [참고 자료 및 커뮤니티](appendix/appendix-d-resources.md)

전체 구성은 [`outline.md`](outline.md), 문체/서식 규칙은 [`style-guide.md`](style-guide.md)를 참고하세요.

## 디렉토리 구조

```
swift-swiftui-book/
├── chapters/         # 장별 본문(chapter.md)과 예제 코드(examples/)
├── appendix/         # 부록 A~D
├── epub/             # EPUB 빌드 입력 (metadata, parts, css, images)
├── scripts/          # 자동화 스크립트 (EPUB 메일 발송 등)
├── outline.md        # 전체 목차
├── style-guide.md    # 문체/서식 가이드
└── CLAUDE.md         # 집필 에이전트 지침
```

## EPUB 빌드

[pandoc](https://pandoc.org/)이 설치되어 있어야 합니다.

```bash
brew install pandoc

cd epub/build
pandoc ../metadata.yaml part1.md ch01.md ch02.md ... appD.md \
  --css=../style.css \
  --toc --toc-depth=2 --resource-path=. \
  -o ../../swift-swiftui-심화가이드.epub
```

> `epub/build/` 와 결과물 `*.epub` 은 `.gitignore` 처리되어 있습니다.

## 기여

오타·사실 관계 오류·코드 개선 제안은 **Issue** 또는 **Pull Request**로 환영합니다. 코드 예제는 Swift 6.1 / Xcode 16에서 컴파일되어야 하며, Strict Concurrency를 기본으로 합니다.

## 라이선스

원고와 코드의 라이선스는 추후 공지합니다. 그 전까지 인용 시 출처를 명시해 주세요.
