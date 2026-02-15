import SwiftUI

struct StatusPill: View {
    let status: MotionConnectionStatus
    @State private var isWaitingPulseVisible = false

    var body: some View {
        return HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .opacity(dotOpacity)
                .animation(waitingAnimation, value: isWaitingPulseVisible)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.12))
        )
        .onAppear {
            syncWaitingPulseState()
        }
        .onChange(of: status) { _, _ in
            syncWaitingPulseState()
        }
    }

    private var label: String {
        switch status {
        case .notConnected:
            return "Not connected"
        case .waiting:
            return "Waiting"
        case .connected:
            return "Connected"
        case .bluetoothPermissionRequired:
            return "Bluetooth permission required"
        case .motionPermissionRequired:
            return "Motion permission required"
        case .motionUnavailable:
            return "Motion unavailable"
        }
    }

    private var dotColor: Color {
        switch status {
        case .connected, .waiting:
            return .green
        case .notConnected, .bluetoothPermissionRequired, .motionPermissionRequired, .motionUnavailable:
            return .red
        }
    }

    private var dotOpacity: Double {
        guard status == .waiting else { return 1.0 }
        return isWaitingPulseVisible ? 1.0 : 0.25
    }

    private var waitingAnimation: Animation? {
        guard status == .waiting else { return nil }
        return .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
    }

    private func syncWaitingPulseState() {
        isWaitingPulseVisible = status == .waiting
    }
}
