// Ch09 - 애니메이션 종합 예제

import SwiftUI

// MARK: - 커스텀 AnimatableData

struct PieSegment: Shape {
    var startAngle: Double
    var endAngle: Double

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
            center: center, radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - matchedGeometryEffect

struct HeroAnimation: View {
    @State private var isExpanded = false
    @Namespace private var animation

    var body: some View {
        VStack {
            if isExpanded {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue)
                    .matchedGeometryEffect(
                        id: "card", in: animation)
                    .frame(height: 300)
                    .onTapGesture {
                        withAnimation(.spring(
                            duration: 0.4, bounce: 0.2)) {
                            isExpanded = false
                        }
                    }
                Spacer()
            } else {
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue)
                    .matchedGeometryEffect(
                        id: "card", in: animation)
                    .frame(width: 80, height: 80)
                    .onTapGesture {
                        withAnimation(.spring(
                            duration: 0.4, bounce: 0.2)) {
                            isExpanded = true
                        }
                    }
            }
        }
        .padding()
    }
}

// MARK: - PhaseAnimator

enum BouncePhase: CaseIterable {
    case initial, up, down

    var scale: Double {
        switch self {
        case .initial: 1.0
        case .up: 1.3
        case .down: 0.9
        }
    }
}

struct BouncingEmoji: View {
    var body: some View {
        PhaseAnimator(BouncePhase.allCases) { phase in
            Text("🚀")
                .font(.system(size: 80))
                .scaleEffect(phase.scale)
        } animation: { phase in
            .spring(duration: 0.3, bounce: 0.5)
        }
    }
}

// MARK: - KeyframeAnimator

struct AnimationValues {
    var scale = 1.0
    var verticalOffset = 0.0
    var rotation = Angle.zero
    var opacity = 1.0
}

struct KeyframeDemo: View {
    @State private var trigger = false

    var body: some View {
        VStack {
            KeyframeAnimator(
                initialValue: AnimationValues(),
                trigger: trigger
            ) { values in
                Circle()
                    .fill(.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(values.scale)
                    .offset(y: values.verticalOffset)
                    .rotationEffect(values.rotation)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.5, duration: 0.3)
                    SpringKeyframe(1.0, duration: 0.5)
                }
                KeyframeTrack(\.verticalOffset) {
                    LinearKeyframe(-100, duration: 0.3)
                    LinearKeyframe(0, duration: 0.5)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(
                        .degrees(360), duration: 0.8)
                }
            }

            Button("실행") { trigger.toggle() }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        HeroAnimation()
        BouncingEmoji()
    }
}
