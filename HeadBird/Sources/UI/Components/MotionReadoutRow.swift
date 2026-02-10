import SwiftUI

struct MotionReadoutRow: View {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let pitchColor: Color
    let rollColor: Color
    let yawColor: Color

    var body: some View {
        HStack {
            readout(label: "Pitch", value: pitch, color: pitchColor)
            Spacer()
            readout(label: "Roll", value: roll, color: rollColor)
            Spacer()
            readout(label: "Yaw", value: yaw, color: yawColor)
        }
    }

    private func readout(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.8))
            Text(formatted(value))
                .font(.caption.monospacedDigit())
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%+.1f°", value)
    }
}
