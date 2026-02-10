import SwiftUI

struct MotionDialView: View {
    let label: String
    let valueDegrees: Double
    let color: Color

    private let maxDegrees: Double = 35

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 6

                    let ringRect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    context.stroke(Path(ellipseIn: ringRect), with: .color(.secondary.opacity(0.25)), lineWidth: 1)

                    let clamped = clamp(valueDegrees, min: -maxDegrees, max: maxDegrees)
                    let angle = CGFloat((clamped / maxDegrees) * .pi / 2 - .pi / 2)
                    let pointer = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )

                    var needle = Path()
                    needle.move(to: center)
                    needle.addLine(to: pointer)
                    context.stroke(needle, with: .color(color.opacity(0.9)), lineWidth: 2)

                    let centerDot = Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
                    context.fill(centerDot, with: .color(color))
                }
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(.caption)
                .foregroundStyle(color.opacity(0.85))

            Text(String(format: "%+.1f°", valueDegrees))
                .font(.caption.monospacedDigit())
        }
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
