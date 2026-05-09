# 부록 B. SwiftUI API 버전별 변경 이력

## SwiftUI 1.0 (iOS 13, 2019)
- SwiftUI 최초 도입
- 기본 View: `Text`, `Image`, `Button`, `Toggle`, `Slider`, `TextField`
- 레이아웃: `VStack`, `HStack`, `ZStack`, `List`, `ScrollView`
- 상태 관리: `@State`, `@Binding`, `@ObservedObject`, `@EnvironmentObject`
- `NavigationView`, `TabView`

## SwiftUI 2.0 (iOS 14, 2020)
- `@StateObject` — View가 소유하는 ObservableObject
- `LazyVStack`, `LazyHStack`, `LazyVGrid`, `LazyHGrid`
- `@SceneStorage`, `@AppStorage`
- `Map`, `ProgressView`, `Label`, `Link`
- `matchedGeometryEffect`
- `App` 프로토콜 — 앱 진입점
- Widget 지원

## SwiftUI 3.0 (iOS 15, 2021)
- `.task` 수정자 — 비동기 작업 지원
- `AsyncImage`
- `FocusState`
- `searchable` 수정자
- `.refreshable` — Pull to refresh
- `confirmationDialog`
- Material 배경 (`.ultraThinMaterial` 등)
- `Canvas` — 고성능 2D 드로잉
- `TimelineView`

## SwiftUI 4.0 (iOS 16, 2022)
- `NavigationStack`, `NavigationSplitView` — 새 내비게이션
- `NavigationPath` — 프로그래밍 방식 내비게이션
- **Layout 프로토콜** — 커스텀 레이아웃
- `Grid` — 고정 그리드 레이아웃
- `AnyLayout` — 조건부 레이아웃 전환
- `Charts` 프레임워크
- `ShareLink`, `PhotosPicker`
- `Gauge`, `MultiDatePicker`
- `ViewThatFits` — 공간에 맞는 View 자동 선택

## SwiftUI 5.0 (iOS 17, 2023)
- **`@Observable` 매크로** — ObservableObject 대체
- `@Bindable` — @Observable 객체에 대한 Binding 생성
- `containerRelativeFrame` — 부모 컨테이너 기준 프레임 설정
- `.symbolEffect` — SF Symbol 애니메이션 효과 수정자
- **PhaseAnimator**, **KeyframeAnimator**
- `#Preview` 매크로 — 간결한 Preview 문법
- `contentTransition(.numericText())`
- `scrollTargetBehavior`, `scrollPosition`
- `TipKit` 통합
- `sensoryFeedback` 수정자
- `onChange(of:initial:)` — 새로운 onChange API
- `mapKit` SwiftUI 통합 강화
- Inspector 수정자

## SwiftUI 6.0 (iOS 18, 2024)
- **Tab API 개선** — `Tab` 구조체, 사이드바 탭
- `@Entry` 매크로 — `EnvironmentValues`, `FocusValues`, `ContainerValues` 등에 커스텀 키를 보일러플레이트 없이 선언
- `MeshGradient` — 메시 그라디언트
- `CustomTextEffect`
- `ScrollView` 개선 — `onScrollGeometryChange`, `onScrollPhaseChange`
- Zoom 트랜지션
- SF Symbol 애니메이션 개선
- 새로운 색상 혼합 API

## SwiftUI 7.0 (iOS 19/26, 2025)
- **Liquid Glass** 디자인 시스템
- 새로운 내비게이션 바 스타일
- 탭 바 디자인 업데이트
- 글래스 소재 확장
- 개선된 애니메이션 API
