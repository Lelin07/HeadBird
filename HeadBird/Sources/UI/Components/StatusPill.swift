import SwiftUI

struct StatusPill: View {
    let isConnected: Bool
    let connectedText: String

    init(isConnected: Bool, connectedText: String = "Connected") {
        self.isConnected = isConnected
        self.connectedText = connectedText
    }

    var body: some View {
        let color = isConnected ? Color.green : Color.red
        let text = isConnected ? connectedText : "Not connected"
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.12))
        )
    }
}
