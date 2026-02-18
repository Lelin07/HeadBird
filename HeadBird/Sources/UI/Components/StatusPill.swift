import SwiftUI

struct StatusPill: View {
    let status: MotionConnectionStatus
    @State private var isWaitingPulseOn: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            statusDot
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
            updatePulseState(for: status)
        }
        .onChange(of: status) { _, newStatus in
            updatePulseState(for: newStatus)
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

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .opacity(status == .waiting && isWaitingPulseOn ? 0.25 : 1.0)
    }

    private func updatePulseState(for status: MotionConnectionStatus) {
        guard status == .waiting else {
            withAnimation(.none) {
                isWaitingPulseOn = false
            }
            return
        }

        isWaitingPulseOn = false
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            isWaitingPulseOn = true
        }
    }
}
