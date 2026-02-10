import CoreMotion
import SwiftUI

struct MotionPanel: View {
    let pose: MotionPose?
    let isAvailable: Bool
    let authorization: CMAuthorizationStatus
    let isStreaming: Bool
    let isEnabled: Bool

    private let maxDegrees: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Motion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let status = statusText {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            MotionAxisBar(label: "Pitch", value: normalized(pose?.pitch ?? 0), isEnabled: isEnabled)
            MotionAxisBar(label: "Roll", value: normalized(pose?.roll ?? 0), isEnabled: isEnabled)
            MotionAxisBar(label: "Yaw", value: normalized(pose?.yaw ?? 0), isEnabled: isEnabled)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    private var statusText: String? {
        if !isAvailable {
            return "Motion unavailable"
        }
        if authorization == .denied || authorization == .restricted {
            return "Permission required"
        }
        if !isStreaming {
            return "Waiting…"
        }
        return nil
    }

    private func normalized(_ radians: Double) -> Double {
        let degrees = radians * 180.0 / .pi
        let clamped = max(-maxDegrees, min(maxDegrees, degrees))
        return clamped / maxDegrees
    }
}
