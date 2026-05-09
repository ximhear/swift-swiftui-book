# Swift/SwiftUI 중고급 서적 - 목차 (초안)

> 작업 상태: 📝 초안 작성 중

## Part 1: Swift 심화

### Ch01. Swift 타입 시스템의 깊은 이해
- 값 타입 vs 참조 타입의 성능 특성
- Copy-on-Write 메커니즘
- Existential Type과 성능 영향
- `any` vs `some` — 언제, 왜 사용하는가

### Ch02. 제네릭과 프로토콜 고급 패턴
- Associated Type과 Primary Associated Type
- 프로토콜 합성과 제약 조건 설계
- Type Erasure의 필요성과 구현
- Opaque Return Type 활용 전략

### Ch03. Swift Concurrency 완전 정복
- Structured Concurrency의 설계 철학
- Actor와 데이터 격리(Data Isolation)
- Sendable과 @Sendable의 실무 적용
- Task, TaskGroup, AsyncStream 패턴
- MainActor와 UI 업데이트 전략

### Ch04. 메모리 관리와 성능 최적화
- ARC 심화: 순환 참조를 넘어서
- weak/unowned 선택 기준
- Instruments를 활용한 메모리 프로파일링
- Copy-on-Write 커스텀 구현

### Ch05. Swift Macro
- Macro의 종류와 동작 원리
- Freestanding Macro vs Attached Macro
- 실무에서 유용한 매크로 작성
- SwiftSyntax 활용

## Part 2: SwiftUI 아키텍처

### Ch06. SwiftUI 렌더링 엔진의 이해
- View 프로토콜과 body 호출 시점
- Structural Identity vs Explicit Identity
- View의 생명주기와 상태 보존
- 디버깅: 왜 body가 다시 호출되는가?

### Ch07. 상태 관리 마스터 클래스
- @State, @Binding, @Environment 깊이 파기
- @Observable vs @ObservableObject — 마이그레이션 전략
- 단방향 데이터 흐름 설계
- 상태 공유 패턴과 의존성 주입

### Ch08. 커스텀 레이아웃과 그래픽
- Layout 프로토콜 완전 정복
- GeometryReader의 올바른 사용법
- Canvas와 Shape를 활용한 커스텀 드로잉
- 성능을 고려한 레이아웃 설계

### Ch09. 애니메이션과 트랜지션 심화
- 애니메이션의 내부 동작 원리
- 커스텀 AnimatableData 구현
- matchedGeometryEffect 고급 활용
- PhaseAnimator와 KeyframeAnimator
- 성능 최적화와 60fps 유지 전략

### Ch10. Navigation 아키텍처
- NavigationStack/NavigationSplitView 심화
- 프로그래밍 방식 네비게이션 패턴
- 딥링크 처리 전략
- 탭 기반 + 네비게이션 복합 구조

## Part 3: 실무 패턴과 아키텍처

### Ch11. SwiftUI 앱 아키텍처
- MVVM을 넘어서: SwiftUI에 맞는 아키텍처
- The Composable Architecture(TCA) 소개
- 모듈화와 의존성 관리
- 테스트 가능한 구조 설계

### Ch12. 네트워크와 데이터 계층
- URLSession + async/await 패턴
- 에러 처리와 재시도 전략
- 캐싱과 오프라인 지원
- SwiftData 통합

### Ch13. 테스트 전략
- SwiftUI Preview를 활용한 시각적 테스트
- ViewInspector를 활용한 View 테스트
- Swift Testing 프레임워크 활용
- Snapshot 테스트와 접근성 테스트

### Ch14. 성능 프로파일링과 최적화
- SwiftUI 성능 병목 찾기
- Lazy 컨테이너 최적화
- 이미지/미디어 처리 최적화
- Instruments 활용 실전 가이드

## 부록

### A. Swift 6.1 주요 변경 사항
### B. SwiftUI API 버전별 변경 이력
### C. 유용한 도구와 라이브러리
### D. 참고 자료 및 커뮤니티
