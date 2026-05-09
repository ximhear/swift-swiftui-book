// Ch08 - Canvas와 커스텀 Shape

import SwiftUI

// MARK: - Canvas 차트

struct LineChartView: View {
    let dataPoints: [Double]

    var body: some View {
        Canvas { context, size in
            guard dataPoints.count > 1 else { return }
            let stepX = size.width /
                CGFloat(dataPoints.count - 1)
            let maxVal = dataPoints.max() ?? 1

            var path = Path()
            for (i, value) in dataPoints.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height * (1 - value / maxVal)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.blue, .purple]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                lineWidth: 2
            )

            for (i, value) in dataPoints.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height * (1 - value / maxVal)
                let circle = Path(ellipseIn: CGRect(
                    x: x - 4, y: y - 4, width: 8, height: 8
                ))
                context.fill(circle, with: .color(.blue))
            }
        }
        .frame(height: 200)
    }
}

// MARK: - 커스텀 Shape

struct Polygon: Shape {
    var sides: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2 * .pi / CGFloat(sides)
        var path = Path()

        for i in 0..<sides {
            let a = angle * CGFloat(i) - .pi / 2
            let pt = CGPoint(
                x: center.x + radius * cos(a),
                y: center.y + radius * sin(a)
            )
            if i == 0 { path.move(to: pt) }
            else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        LineChartView(dataPoints: [20, 45, 30, 70, 55, 90, 60])
            .padding()

        Polygon(sides: 6)
            .fill(.blue.gradient)
            .frame(width: 150, height: 150)
    }
}
