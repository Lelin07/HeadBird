import SwiftUI

struct YawCompassView: View {
    let yaw: Double

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 4
                let ringRect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                context.stroke(Path(ellipseIn: ringRect), with: .color(.secondary.opacity(0.35)), lineWidth: 1)

                var tick = Path()
                tick.move(to: CGPoint(x: center.x, y: center.y - radius))
                tick.addLine(to: CGPoint(x: center.x, y: center.y - radius + 6))
                context.stroke(tick, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

                let angle = CGFloat(yaw - .pi / 2)
                let pointer = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )

                var heading = Path()
                heading.move(to: center)
                heading.addLine(to: pointer)
                context.stroke(heading, with: .color(.primary.opacity(0.9)), lineWidth: 2)
            }
        }
        .frame(width: 64, height: 64)
    }
}
