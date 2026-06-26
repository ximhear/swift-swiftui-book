# Chapter 9. 애니메이션과 트랜지션 심화

> SwiftUI의 애니메이션은 선언적이고 간결하지만, 내부 동작을 이해하지 않으면 원하는 효과를 만들기 어렵습니다. 이 장에서는 애니메이션의 내부 원리부터 `AnimatableData`, `matchedGeometryEffect`, `PhaseAnimator`, `KeyframeAnimator`까지 — 고급 애니메이션 기법을 체계적으로 다룹니다.

---

## 9.1 애니메이션의 내부 동작 원리

### SwiftUI 애니메이션의 핵심 개념

SwiftUI의 애니메이션은 **상태 변화를 시간에 따라 보간(interpolation)**하는 것입니다.

```swift
struct SimpleAnimation: View {
    @State private var scale = 1.0
    
    var body: some View {
        Circle()
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .onTapGesture {
                withAnimation(.spring(
                    duration: 0.5,
                    bounce: 0.3
                )) {
                    scale = scale == 1.0 ? 1.5 : 1.0
                }
            }
    }
}
// scale이 1.0 → 1.5로 변할 때
// SwiftUI는 매 프레임(1/60초 또는 1/120초)마다
// 중간값을 계산하여 화면을 업데이트
```

### 암시적 vs 명시적 애니메이션

```swift
struct AnimationTypes: View {
    @State private var offset: CGFloat = 0
    @State private var opacity = 1.0
    
    var body: some View {
        VStack(spacing: 40) {
            // 암시적 애니메이션: .animation 수정자
            Circle()
                .fill(.blue)
                .frame(width: 50, height: 50)
                .offset(x: offset)
                .animation(.spring, value: offset)
                // offset이 변할 때만 애니메이션 적용
            
            // 명시적 애니메이션: withAnimation
            Circle()
                .fill(.red)
                .frame(width: 50, height: 50)
                .opacity(opacity)
            
            Button("이동") {
                offset = offset == 0 ? 100 : 0
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = opacity == 1.0 ? 0.3 : 1.0
                }
            }
        }
    }
}
```

> **Note**: `.animation(_, value:)` 형태를 항상 사용하세요. `value` 없는 `.animation()`은 deprecated되었고, 의도치 않은 애니메이션을 유발합니다.

### 트랜잭션(Transaction)과 애니메이션 제어

🟡 중급

```swift
struct TransactionExample: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue)
                .frame(
                    width: isExpanded ? 300 : 100,
                    height: isExpanded ? 300 : 100
                )
                // 특정 수정자에 대한 애니메이션 비활성화
                .transaction { transaction in
                    if !isExpanded {
                        // 축소할 때는 애니메이션 없이
                        transaction.animation = nil
                    }
                }
            
            Button("토글") {
                withAnimation(.spring) {
                    isExpanded.toggle()
                }
            }
        }
    }
}
```

---

## 9.2 커스텀 AnimatableData 구현

### Animatable 프로토콜

SwiftUI가 View나 Shape를 애니메이션하려면, 변화하는 값이 `VectorArithmetic`을 준수해야 합니다. `Double`, `CGFloat`, `Float`가 대표적인 `VectorArithmetic` 준수 타입입니다.

`CGPoint`·`CGSize`·`CGRect`는 흔히 오해하는 지점인데, 이 타입들은 `VectorArithmetic`이 **아니라** `Animatable`을 준수합니다. 내부적으로는 두 개의 `CGFloat`를 묶은 `AnimatablePair<CGFloat, CGFloat>`를 `animatableData`로 사용해 보간됩니다. 즉 "여러 개의 스칼라 값을 묶어 한꺼번에 애니메이션하는" 패턴인데, 바로 아래 `PieSegment`가 두 각도를 `AnimatablePair<Double, Double>`로 묶는 방식과 정확히 동일합니다.

> **Note**: `VectorArithmetic`은 스칼라 곱셈(`scale(by:)`)과 크기(`magnitudeSquared`)를 요구하는 좁은 프로토콜이라 `Double`·`CGFloat`·`Float`와 `AnimatablePair`·`EmptyAnimatableData`만 표준 준수합니다. 2개 이상의 값을 애니메이션하려면 직접 `VectorArithmetic`을 구현하지 말고 `AnimatablePair`로 중첩해 묶으세요.

🟡 중급

```swift
// 파이 차트 세그먼트 — 각도를 애니메이션
struct PieSegment: Shape {
    var startAngle: Double
    var endAngle: Double
    
    // 애니메이션할 데이터 지정
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct AnimatedPieChart: View {
    @State private var progress = 0.0
    let values: [Double] = [30, 25, 20, 15, 10]
    let colors: [Color] = [.blue, .green, .orange,
                            .red, .purple]
    
    var body: some View {
        ZStack {
            ForEach(0..<values.count, id: \.self) { i in
                let start = values[0..<i].reduce(0, +)
                    / values.reduce(0, +) * 360
                let end = values[0...i].reduce(0, +)
                    / values.reduce(0, +) * 360
                
                PieSegment(
                    startAngle: start * progress,
                    endAngle: end * progress
                )
                .fill(colors[i])
            }
        }
        .frame(width: 200, height: 200)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                progress = 1.0
            }
        }
    }
}
```

### 숫자 카운터 애니메이션

`View` 자체에 `Animatable`을 채택하면, `animatableData`로 지정한 값이 보간되는 매 프레임마다 `body`가 다시 그려집니다. 카운터처럼 숫자가 부드럽게 올라가는 효과를 만들 때 유용합니다.

```swift
struct AnimatableNumber: View, @MainActor Animatable {
    var value: Double
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    var body: some View {
        Text("\(Int(value))")
            .font(.system(size: 48, weight: .bold,
                          design: .rounded))
            .monospacedDigit()
    }
}

struct CounterView: View {
    @State private var count = 0.0
    
    var body: some View {
        VStack {
            AnimatableNumber(value: count)
            
            Button("1000까지") {
                withAnimation(.easeOut(duration: 2)) {
                    count = 1000
                }
            }
        }
    }
}
```

> **Warning**: `View`에 `Animatable`을 채택할 때는 `@MainActor Animatable`로 명시해야 합니다. `View`는 `@MainActor`로 격리되어 멤버인 `animatableData`도 메인 액터에 격리되는데, `Animatable.animatableData`는 `nonisolated` 요구사항이라 격리 경계가 충돌합니다. Swift 6.2+에서는 `#ConformanceIsolation` 진단으로 "conformance ... crosses into main actor-isolated code" 컴파일 에러가 납니다(ch06에서 `View`에 `Equatable`을 채택할 때 `nonisolated static func ==`로 풀었던 것과 같은 격리 문제입니다). 적합성 자체를 `@MainActor`로 격리하면 해결되며, Swift 6.1에서도 안전하게 컴파일됩니다. 한편 `Shape`는 `Sendable`을 요구하지 않아 위 `PieSegment`처럼 별도 표기 없이 통과합니다.

---

## 9.3 matchedGeometryEffect 고급 활용

### 기본 원리

`matchedGeometryEffect`는 서로 다른 View 사이에서 **위치와 크기의 연속적인 전환**을 만듭니다.

```swift
struct HeroAnimation: View {
    @State private var isExpanded = false
    @Namespace private var animation
    
    var body: some View {
        VStack {
            if isExpanded {
                // 확장된 상태
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue)
                    .matchedGeometryEffect(
                        id: "card", in: animation)
                    .frame(height: 300)
                    .onTapGesture {
                        withAnimation(.spring(
                            duration: 0.4,
                            bounce: 0.2
                        )) {
                            isExpanded = false
                        }
                    }
                
                Spacer()
            } else {
                Spacer()
                
                // 축소된 상태
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue)
                    .matchedGeometryEffect(
                        id: "card", in: animation)
                    .frame(width: 80, height: 80)
                    .onTapGesture {
                        withAnimation(.spring(
                            duration: 0.4,
                            bounce: 0.2
                        )) {
                            isExpanded = true
                        }
                    }
            }
        }
        .padding()
    }
}
```

> **Warning**: `matchedGeometryEffect`는 **적용된 지점의 지오메트리**를 기준으로 매칭합니다. 따라서 `.matchedGeometryEffect(id:in:)`와 `.frame(...)`의 순서가 결과 크기에 영향을 줍니다. 위 예제처럼 `frame` 앞에 두면 콘텐츠 고유 크기 기준으로, `frame` 뒤(상위)에 두면 지정한 프레임 크기 기준으로 매칭됩니다. 의도한 전환 크기에 맞춰 순서를 정하세요.

### 실전: 그리드 → 상세 전환

🔴 고급

```swift
struct Photo: Identifiable {
    let id = UUID()
    let color: Color
    let title: String
}

struct PhotoGallery: View {
    @State private var selectedPhoto: Photo?
    @Namespace private var namespace
    
    let photos = [
        Photo(color: .blue, title: "바다"),
        Photo(color: .green, title: "숲"),
        Photo(color: .orange, title: "석양"),
        Photo(color: .purple, title: "밤하늘"),
    ]
    
    var body: some View {
        ZStack {
            // 그리드
            LazyVGrid(
                columns: [GridItem(.adaptive(
                    minimum: 150))],
                spacing: 16
            ) {
                ForEach(photos) { photo in
                    if selectedPhoto?.id != photo.id {
                        PhotoThumbnail(
                            photo: photo,
                            namespace: namespace
                        )
                        .onTapGesture {
                            withAnimation(.spring(
                                duration: 0.4)) {
                                selectedPhoto = photo
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 150)
                    }
                }
            }
            .padding()
            
            // 상세 뷰
            if let photo = selectedPhoto {
                PhotoDetail(
                    photo: photo,
                    namespace: namespace
                )
                .onTapGesture {
                    withAnimation(.spring(
                        duration: 0.4)) {
                        selectedPhoto = nil
                    }
                }
                .zIndex(1)
            }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo
    let namespace: Namespace.ID
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(photo.color)
            .frame(height: 150)
            .matchedGeometryEffect(
                id: photo.id, in: namespace)
            .overlay {
                Text(photo.title)
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(
                        id: "\(photo.id)-title",
                        in: namespace)
            }
    }
}

struct PhotoDetail: View {
    let photo: Photo
    let namespace: Namespace.ID
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(photo.color)
            .matchedGeometryEffect(
                id: photo.id, in: namespace)
            .overlay(alignment: .topLeading) {
                Text(photo.title)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .padding()
                    .matchedGeometryEffect(
                        id: "\(photo.id)-title",
                        in: namespace)
            }
            .padding()
    }
}
```

> **Warning**: `matchedGeometryEffect`에서 가장 흔한 함정 두 가지입니다. 첫째, **같은 `id`와 `@Namespace` 짝은 한 시점에 하나의 View에만** 부여해야 합니다. 위 예제가 `if selectedPhoto?.id != photo.id`로 썸네일을 숨기고 상세 뷰만 남기는 이유입니다. 둘째, 동일한 `id`를 가진 View가 화면에 **둘 다 존재**하면(예: `if/else`로 분기하지 않고 두 View를 모두 렌더) SwiftUI가 어느 쪽을 기준 지오메트리로 삼을지 모호해져 깜빡임이나 위치 점프가 발생합니다. 전환되는 두 View 중 한쪽만 계층에 남도록 분기하세요.

---

## 9.4 PhaseAnimator와 KeyframeAnimator

### PhaseAnimator — 단계별 애니메이션

iOS 17+에서 도입된 `PhaseAnimator`는 여러 단계를 순차적으로 진행하는 애니메이션을 쉽게 만듭니다:

```swift
enum BouncePhase: CaseIterable {
    case initial, up, down
    
    var scale: Double {
        switch self {
        case .initial: 1.0
        case .up: 1.3
        case .down: 0.9
        }
    }
    
    var rotation: Double {
        switch self {
        case .initial: 0
        case .up: -10
        case .down: 5
        }
    }
}

struct BouncingEmoji: View {
    var body: some View {
        PhaseAnimator(BouncePhase.allCases) { phase in
            Text("🚀")
                .font(.system(size: 80))
                .scaleEffect(phase.scale)
                .rotationEffect(.degrees(phase.rotation))
        } animation: { phase in
            switch phase {
            case .initial: .spring(duration: 0.3)
            case .up: .spring(duration: 0.2, bounce: 0.5)
            case .down: .spring(duration: 0.4)
            }
        }
    }
}
```

### KeyframeAnimator — 정밀한 타이밍 제어

🔴 고급

```swift
struct KeyframeExample: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            KeyframeAnimator(
                initialValue: AnimationValues(),
                trigger: isAnimating
            ) { values in
                Circle()
                    .fill(.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(values.scale)
                    .offset(y: values.verticalOffset)
                    .rotationEffect(values.rotation)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.5, duration: 0.3)
                    SpringKeyframe(1.0, duration: 0.2)
                    SpringKeyframe(1.2, duration: 0.2)
                    SpringKeyframe(1.0, duration: 0.3)
                }
                
                KeyframeTrack(\.verticalOffset) {
                    LinearKeyframe(-100, duration: 0.3)
                    LinearKeyframe(0, duration: 0.4)
                    LinearKeyframe(-30, duration: 0.2)
                    LinearKeyframe(0, duration: 0.3)
                }
                
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(
                        .degrees(360), duration: 1.0)
                }
                
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.5, duration: 0.2)
                    LinearKeyframe(1.0, duration: 0.3)
                }
            }
            
            Button("애니메이션") {
                isAnimating.toggle()
            }
        }
    }
}

struct AnimationValues {
    var scale = 1.0
    var verticalOffset = 0.0
    var rotation = Angle.zero
    var opacity = 1.0
}
```

---

## 9.5 트랜지션(Transition) 심화

### 기본 트랜지션

View가 나타나거나 사라질 때 적용되는 애니메이션입니다:

```swift
struct TransitionBasics: View {
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            Button("토글") {
                withAnimation(.spring(duration: 0.4)) {
                    showDetail.toggle()
                }
            }
            
            if showDetail {
                Text("상세 내용")
                    .padding()
                    .background(.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(
                        cornerRadius: 12))
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity))
            }
        }
    }
}
```

### 비대칭 트랜지션

나타날 때와 사라질 때 다른 효과를 적용합니다:

```swift
.transition(.asymmetric(
    insertion: .scale.combined(with: .opacity),
    removal: .move(edge: .trailing)
))
```

### 커스텀 Transition (iOS 17+)

🔴 고급

iOS 17에서 도입된 `Transition` 프로토콜로 완전한 커스텀 트랜지션을 구현합니다. `body(content:phase:)`에서 현재 `phase`에 따라 `content`를 변형하면 됩니다:

```swift
struct BlurTransition: Transition {
    func body(
        content: Content,
        phase: TransitionPhase
    ) -> some View {
        content
            // phase.isIdentity == true면 완전히 나타난 상태
            .blur(radius: phase.isIdentity ? 0 : 20)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.8)
    }
}

// 사용 — Transition 값을 그대로 .transition(_:)에 전달
struct CustomTransitionDemo: View {
    @State private var showContent = false

    var body: some View {
        VStack {
            Button("토글") {
                withAnimation(.spring(duration: 0.4)) {
                    showContent.toggle()
                }
            }

            if showContent {
                Text("새 콘텐츠")
                    .padding()
                    .transition(BlurTransition())
            }
        }
    }
}
```

> **Note**: iOS 17 이전에는 `AnyTransition.modifier(active:identity:)`에 두 가지 상태의 `ViewModifier`를 넘기는 방식을 썼습니다. iOS 17+에서는 위처럼 `Transition` 프로토콜 하나로 `phase`에 따라 분기하는 편이 간결합니다. 두 API를 한 트랜지션에 섞지 마세요.

`TransitionPhase`는 세 가지 상태를 제공합니다:
- `.willAppear` — 나타나기 직전
- `.identity` — 완전히 나타난 상태
- `.didDisappear` — 사라진 직후

### contentTransition — 콘텐츠 전환

🟡 중급

```swift
struct ScoreView: View {
    @State private var score = 0
    
    var body: some View {
        VStack {
            Text("\(score)")
                .font(.system(size: 60, weight: .bold,
                              design: .rounded))
                .contentTransition(.numericText(
                    value: Double(score)))
            
            Button("+ 10점") {
                withAnimation(.spring) {
                    score += 10
                }
            }
        }
    }
}
```

### symbolEffect — SF Symbol 애니메이션

iOS 17에서 도입된 SF Symbol 전용 애니메이션:

```swift
struct NotificationBell: View {
    @State private var hasNotification = false
    
    var body: some View {
        Image(systemName: "bell.fill")
            .font(.title)
            .symbolEffect(.bounce, value: hasNotification)
        
        // 다른 효과들:
        // .symbolEffect(.pulse)      — 반복 맥동
        // .symbolEffect(.variableColor) — 색상 변화
        // .symbolEffect(.replace)    — 심볼 교체 시
    }
}
```

---

## 9.6 성능 최적화와 60fps 유지 전략

### 애니메이션 성능 원칙

애니메이션 비용을 가르는 핵심 기준은 흔히 말하는 "GPU냐 CPU냐"가 아니라 **레이아웃 패스(layout pass)를 다시 유발하는가**입니다. `offset`·`scaleEffect`·`rotationEffect`·`opacity`는 레이아웃을 다시 계산하지 않고 렌더링 단계의 변형(transform)·합성으로 적용되므로 저렴합니다. 반면 `frame`을 애니메이션하면 부모·형제 View의 레이아웃 패스가 매 프레임 다시 트리거되어 비싸집니다(GPU 가속 여부는 렌더링 백엔드에 따라 다르므로 비용의 본질이 아닙니다).

```swift
// ✅ 레이아웃 불변 — 저렴 (transform/합성 단계에서 적용)
// opacity, scaleEffect, rotationEffect, offset

// ❌ 레이아웃 패스 유발 — 비쌈
// frame, clipShape, overlay/background with complex views
// 텍스트 내용 변경, 리스트 아이템 추가/삭제

struct PerformantAnimation: View {
    @State private var isActive = false
    
    var body: some View {
        // ✅ offset은 레이아웃을 다시 계산하지 않는다
        Circle()
            .fill(.blue)
            .frame(width: 50, height: 50)
            .offset(x: isActive ? 200 : 0)
            .animation(.spring, value: isActive)
        
        // ❌ frame 변경은 레이아웃 재계산을 유발한다
        // Rectangle()
        //     .frame(width: isActive ? 300 : 100)
        //     .animation(.spring, value: isActive)
    }
}
```

> **Tip**: 위치를 옮기는 애니메이션은 `frame`이나 패딩 대신 `offset`으로, 크기 변화는 가능하면 `scaleEffect`로 표현하세요. 둘 다 레이아웃 패스를 건너뛰어 60fps를 유지하기 쉽습니다. 단, `scaleEffect`는 실제 레이아웃 크기를 바꾸지 않으므로 주변 뷰 배치까지 함께 변해야 한다면 `frame` 애니메이션이 불가피할 수 있습니다.

### drawingGroup으로 복잡한 애니메이션 가속

```swift
struct ParticleEffect: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size,
                           height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .drawingGroup()  // Metal 렌더링으로 전환
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
```

> **Tip**: `drawingGroup()`은 하위 뷰 계층을 하나의 오프스크린 Metal 레이어로 평탄화해 합성 비용을 줄입니다. 입자 수백 개처럼 단순한 도형이 많을 때 효과적입니다. 다만 무조건 쓰면 오히려 손해입니다. 뷰가 적거나 텍스트·이미지가 섞이면 오프스크린 버퍼 생성 비용이 더 클 수 있고, 별도 레이어로 분리되어 일부 접근성·블렌딩 동작이 달라질 수 있으니 실제 프로파일링으로 개선을 확인한 뒤 적용하세요.

---

## 정리

- **애니메이션 원리**: 상태 변화를 시간에 따라 보간합니다. `.animation(_, value:)` 또는 `withAnimation`으로 적용합니다.

- **AnimatableData**: 커스텀 Shape와 View를 애니메이션하려면 `animatableData`를 구현합니다. `AnimatablePair`로 여러 값을 동시에 애니메이션할 수 있습니다.

- **matchedGeometryEffect**: 서로 다른 View 간의 연속적인 전환을 만듭니다. `@Namespace`와 함께 사용하며, hero 애니메이션에 적합합니다.

- **PhaseAnimator/KeyframeAnimator**: iOS 17+에서 단계별, 키프레임별 정밀한 애니메이션 제어가 가능합니다.

- **성능**: 레이아웃 패스를 유발하지 않는 `offset`·`opacity`·`scaleEffect`를 `frame` 애니메이션보다 우선하고, 입자처럼 단순한 도형이 많은 화면은 `drawingGroup()`으로 합성 비용을 줄입니다.

다음 장에서는 **내비게이션 아키텍처(Navigation)**를 다룹니다. `NavigationStack`과 값 기반 라우팅으로 화면 전환을 선언적으로 관리하는 방법을 살펴보며, 이 장에서 익힌 트랜지션·`matchedGeometryEffect`가 화면 간 전환에서 어떻게 이어지는지 확인합니다.
