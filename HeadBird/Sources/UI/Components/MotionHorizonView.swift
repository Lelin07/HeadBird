import SwiftUI

struct MotionHorizonView: View {
    let pitch: Double
    let roll: Double

    private let maxDegrees: Double = 35

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let midY = size.height / 2
                let maxOffset = size.height * 0.25
                let pitchDegrees = clamp(degrees(pitch), min: -maxDegrees, max: maxDegrees)
                let offset = CGFloat(-pitchDegrees / maxDegrees) * maxOffset
                let rollRadians = CGFloat(clamp(degrees(roll), min: -maxDegrees, max: maxDegrees) * .pi / 180.0)

                var horizon = Path()
                horizon.move(to: CGPoint(x: -size.width, y: midY + offset))
                horizon.addLine(to: CGPoint(x: size.width * 2, y: midY + offset))

                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: size.width / 2, y: size.height / 2)
                transform = transform.rotated(by: rollRadians)
                transform = transform.translatedBy(x: -size.width / 2, y: -size.height / 2)

                context.stroke(horizon.applying(transform), with: .color(.primary.opacity(0.9)), lineWidth: 2)

                var centerTick = Path()
                centerTick.move(to: CGPoint(x: size.width / 2, y: midY - 6))
                centerTick.addLine(to: CGPoint(x: size.width / 2, y: midY + 6))
                context.stroke(centerTick, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 86)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func degrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
