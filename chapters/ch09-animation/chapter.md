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

SwiftUI가 View나 Shape를 애니메이션하려면, 변화하는 값이 `VectorArithmetic`을 준수해야 합니다. `CGFloat`, `Double`, `CGPoint` 등이 이미 준수하고 있습니다.

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

```swift
struct AnimatableNumber: View, Animatable {
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

iOS 17에서 도입된 `Transition` 프로토콜로 완전한 커스텀 트랜지션을 구현합니다:

```swift
struct BlurTransition: Transition {
    func body(
        content: Content,
        phase: TransitionPhase
    ) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 20)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.8)
    }
}

extension AnyTransition {
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 20, opacity: 0),
            identity: BlurModifier(radius: 0, opacity: 1)
        )
    }
}

// 사용
Text("새 콘텐츠")
    .transition(BlurTransition())
```

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

```swift
// ✅ GPU에서 처리: 빠름
// opacity, scaleEffect, rotationEffect, offset

// ❌ CPU에서 처리: 느릴 수 있음
// frame, clipShape, overlay/background with complex views
// 텍스트 내용 변경, 리스트 아이템 추가/삭제

struct PerformantAnimation: View {
    @State private var isActive = false
    
    var body: some View {
        // ✅ offset은 GPU 가속됨
        Circle()
            .fill(.blue)
            .frame(width: 50, height: 50)
            .offset(x: isActive ? 200 : 0)
            .animation(.spring, value: isActive)
        
        // ❌ frame 변경은 레이아웃 재계산 필요
        // Rectangle()
        //     .frame(width: isActive ? 300 : 100)
        //     .animation(.spring, value: isActive)
    }
}
```

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

---

## 정리

- **애니메이션 원리**: 상태 변화를 시간에 따라 보간합니다. `.animation(_, value:)` 또는 `withAnimation`으로 적용합니다.

- **AnimatableData**: 커스텀 Shape와 View를 애니메이션하려면 `animatableData`를 구현합니다. `AnimatablePair`로 여러 값을 동시에 애니메이션할 수 있습니다.

- **matchedGeometryEffect**: 서로 다른 View 간의 연속적인 전환을 만듭니다. `@Namespace`와 함께 사용하며, hero 애니메이션에 적합합니다.

- **PhaseAnimator/KeyframeAnimator**: iOS 17+에서 단계별, 키프레임별 정밀한 애니메이션 제어가 가능합니다.

- **성능**: `offset`, `opacity`, `scaleEffect` 등 GPU 가속 가능한 속성을 우선하고, `drawingGroup()`으로 복잡한 그래픽을 가속합니다.

다음 장에서는 **Navigation 아키텍처**를 다룹니다.
