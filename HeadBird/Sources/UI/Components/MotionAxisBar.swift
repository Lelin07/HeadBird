import SwiftUI

struct MotionAxisBar: View {
    let label: String
    let value: Double
    let isEnabled: Bool

    private let barHeight: CGFloat = 6

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            GeometryReader { proxy in
                let clamped = max(-1.0, min(1.0, value))
                let half = proxy.size.width / 2
                let fillWidth = abs(clamped) * half
                let fillX = clamped >= 0 ? half : half - fillWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(isEnabled ? 0.18 : 0.08))
                        .frame(height: barHeight)

                    Rectangle()
                        .fill(Color.primary.opacity(isEnabled ? 0.9 : 0.35))
                        .frame(width: fillWidth, height: barHeight)
                        .cornerRadius(barHeight / 2)
                        .offset(x: fillX)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1, height: barHeight + 6)
                        .offset(x: half - 0.5)
                }
            }
            .frame(height: barHeight + 6)
        }
    }
}
