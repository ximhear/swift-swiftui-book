# Chapter 8. 커스텀 레이아웃과 그래픽

> SwiftUI의 기본 레이아웃 컨테이너(`VStack`, `HStack`, `ZStack`)만으로는 해결할 수 없는 복잡한 UI가 있습니다. iOS 16에서 도입된 Layout 프로토콜은 완전한 커스텀 레이아웃을 선언적으로 구현할 수 있게 합니다. 이 장에서는 Layout 프로토콜을 완전히 정복하고, GeometryReader의 올바른 사용법, Canvas와 Shape를 활용한 커스텀 드로잉까지 다룹니다.

---

## 8.1 Layout 프로토콜 완전 정복

### Layout 프로토콜의 두 가지 메서드

Layout 프로토콜은 핵심적으로 두 메서드만 구현하면 됩니다:

```swift
protocol Layout: Animatable {
    // 1단계: 전체 컨테이너의 크기 결정
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize
    
    // 2단계: 각 자식 View의 위치 배치
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    )
}
```

### 예제: FlowLayout (태그 나열)

🟡 중급

가로 공간이 부족하면 다음 줄로 넘어가는 플로우 레이아웃:

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = computeLayout(
            proposal: proposal,
            subviews: subviews
        )
        return result.size
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = computeLayout(
            proposal: proposal,
            subviews: subviews
        )
        
        for (index, position) in result.positions
            .enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }
    
    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }
    
    private func computeLayout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth,
               currentX > 0 {
                // 다음 줄로
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX,
                                      y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }
        
        return LayoutResult(
            size: CGSize(
                width: maxX,
                height: currentY + lineHeight
            ),
            positions: positions
        )
    }
}

// 사용
struct TagCloudView: View {
    let tags = ["Swift", "SwiftUI", "iOS", "Xcode",
                "UIKit", "Combine", "CoreData",
                "CloudKit", "WidgetKit"]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
}
```

### 예제: RadialLayout (원형 배치)

🔴 고급

자식 View들을 원형으로 배치하는 레이아웃:

```swift
struct RadialLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let size = min(
            proposal.width ?? 200,
            proposal.height ?? 200
        )
        return CGSize(width: size, height: size)
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(
            x: bounds.midX,
            y: bounds.midY
        )
        let angleStep = 2 * .pi / CGFloat(subviews.count)
        
        for (index, subview) in subviews.enumerated() {
            let angle = angleStep * CGFloat(index) - .pi / 2
            let x = center.x + radius * 0.7 * cos(angle)
            let y = center.y + radius * 0.7 * sin(angle)
            
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .center,
                proposal: .unspecified
            )
        }
    }
}
```

---

## 8.2 GeometryReader의 올바른 사용법

### GeometryReader의 문제점

`GeometryReader`는 강력하지만 남용하면 레이아웃 문제를 일으킵니다:

```swift
// ❌ GeometryReader 남용
struct BadExample: View {
    var body: some View {
        GeometryReader { geo in
            // GeometryReader는 가용 공간을 모두 차지하고
            // 자식을 좌상단에 배치함
            Text("Hello")
                .frame(width: geo.size.width * 0.8)
        }
        // 부모의 레이아웃이 깨질 수 있음
    }
}

// ✅ 크기 정보가 정말 필요할 때만 사용
struct GoodExample: View {
    var body: some View {
        Text("Hello")
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        // 대부분의 경우 frame과 padding으로 충분
    }
}
```

### GeometryReader가 적합한 경우

```swift
// 비율 기반 레이아웃이 정말 필요할 때
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue)
                    .frame(
                        width: geo.size.width * progress
                    )
            }
        }
        .frame(height: 8)  // 높이를 명시적으로 제한!
    }
}
```

> **Note**: iOS 17+에서는 `containerRelativeFrame`을 사용하면 `GeometryReader` 없이 상대적 크기를 지정할 수 있습니다.

```swift
// iOS 17+ 대안
Text("Hello")
    .containerRelativeFrame(.horizontal) { width, _ in
        width * 0.8
    }
```

---

## 8.3 Canvas와 Shape를 활용한 커스텀 드로잉

### Canvas — 고성능 2D 드로잉

`Canvas`는 SwiftUI에서 직접 2D 그래픽을 그리는 가장 효율적인 방법입니다:

```swift
struct ChartView: View {
    let dataPoints: [Double]
    
    var body: some View {
        Canvas { context, size in
            let stepX = size.width /
                CGFloat(dataPoints.count - 1)
            let maxValue = dataPoints.max() ?? 1
            
            // 경로 그리기
            var path = Path()
            for (index, value) in dataPoints.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height *
                    (1 - value / maxValue)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // 그라디언트로 선 그리기
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.blue, .purple]),
                    startPoint: .zero,
                    endPoint: CGPoint(
                        x: size.width, y: 0)
                ),
                lineWidth: 2
            )
            
            // 데이터 포인트 원 그리기
            for (index, value) in dataPoints.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height *
                    (1 - value / maxValue)
                let circle = Path(
                    ellipseIn: CGRect(
                        x: x - 4, y: y - 4,
                        width: 8, height: 8
                    )
                )
                context.fill(circle, with: .color(.blue))
            }
        }
        .frame(height: 200)
    }
}
```

### 커스텀 Shape

```swift
struct Polygon: Shape {
    var sides: Int
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2 * .pi / CGFloat(sides)
        
        var path = Path()
        
        for i in 0..<sides {
            let currentAngle = angle * CGFloat(i) - .pi / 2
            let x = center.x + radius * cos(currentAngle)
            let y = center.y + radius * sin(currentAngle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// 사용
struct ShapeDemo: View {
    var body: some View {
        Polygon(sides: 6)
            .fill(.blue.gradient)
            .frame(width: 200, height: 200)
    }
}
```

---

## 8.4 성능을 고려한 레이아웃 설계

### Layout 캐시 활용

```swift
struct CachedFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    struct CacheData {
        var sizes: [CGSize] = []
    }
    
    func makeCache(subviews: Subviews) -> CacheData {
        // 자식들의 크기를 미리 계산하여 캐시
        CacheData(sizes: subviews.map {
            $0.sizeThatFits(.unspecified)
        })
    }
    
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        // cache.sizes를 사용하여 중복 계산 방지
        computeSize(
            maxWidth: proposal.width ?? .infinity,
            sizes: cache.sizes
        )
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {
        // cache.sizes를 사용
        let positions = computePositions(
            maxWidth: bounds.width,
            sizes: cache.sizes
        )
        for (index, position) in positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(
                    cache.sizes[index]
                )
            )
        }
    }
    
    private func computeSize(
        maxWidth: CGFloat, sizes: [CGSize]
    ) -> CGSize {
        // 크기 계산 로직...
        .zero
    }
    
    private func computePositions(
        maxWidth: CGFloat, sizes: [CGSize]
    ) -> [CGPoint] {
        // 위치 계산 로직...
        []
    }
}
```

### drawingGroup() — GPU 가속

```swift
struct HeavyGraphicsView: View {
    var body: some View {
        ZStack {
            ForEach(0..<100, id: \.self) { i in
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: CGFloat(i) * 3)
            }
        }
        .drawingGroup()  // Metal로 오프스크린 렌더링
        // 복잡한 그래픽에서 성능 향상
    }
}
```

---

## 정리

- **Layout 프로토콜**: `sizeThatFits`와 `placeSubviews` 두 메서드로 완전한 커스텀 레이아웃을 구현합니다. FlowLayout, RadialLayout 등 기본 컨테이너로 불가능한 배치가 가능합니다.

- **GeometryReader**: 크기 정보가 정말 필요할 때만 사용하고, `frame(height:)`로 크기를 제한하세요. iOS 17+에서는 `containerRelativeFrame`을 대안으로 고려하세요.

- **Canvas**: 고성능 2D 드로잉에 최적. 차트, 그래프 등에 적합합니다.

- **커스텀 Shape**: `Path`를 반환하는 `path(in:)` 메서드로 임의의 도형을 정의합니다.

- **성능**: Layout 캐시로 중복 계산을 피하고, `drawingGroup()`으로 복잡한 그래픽의 렌더링을 GPU에 위임합니다.

다음 장에서는 **애니메이션과 트랜지션**을 심화 학습합니다.
