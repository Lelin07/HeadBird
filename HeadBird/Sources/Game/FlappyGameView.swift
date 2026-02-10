import SpriteKit
import SwiftUI

struct FlappyGameView: View {
    @EnvironmentObject private var model: HeadBarModel
    @StateObject private var state: GameState
    @State private var scene: FlappyGameScene

    let isActive: Bool

    init(isActive: Bool) {
        self.isActive = isActive
        let gameState = GameState()
        _state = StateObject(wrappedValue: gameState)
        _scene = State(initialValue: FlappyGameScene(state: gameState))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("HeadBird")
                    .font(.title3.weight(.semibold))
                Spacer()
                StatusPill(isConnected: model.connectedAirPods.isEmpty == false)
                Button {
                    startOrReset()
                } label: {
                    actionLabel
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.connectedAirPods.isEmpty)
            }

            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                    )

                HStack {
                    Text("Score \(state.score)")
                    Spacer()
                    Text("Best \(state.highScore)")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(10)

                if !state.statusMessage.isEmpty {
                    Text(state.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }

            HStack(spacing: 12) {
                Text("Sensitivity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(value: $state.sensitivity, in: 0.5...2.0, step: 0.05)
                Text(String(format: "%.2fx", state.sensitivity))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            Text("Tilt your head up or down to fly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .onReceive(model.$motionPose) { pose in
            state.updatePitch(pose.pitch)
        }
        .onAppear {
            scene.isPaused = false
        }
        .onDisappear {
            scene.isPaused = true
        }
        .onChange(of: isActive) { _, active in
            scene.isPaused = !active
        }
    }

    private var actionLabel: some View {
        if state.isPlaying {
            return Label("Reset", systemImage: "arrow.clockwise")
        }
        if state.hasPlayed {
            return Label("Restart", systemImage: "arrow.clockwise")
        }
        return Label("Play", systemImage: "play.fill")
    }

    private func startOrReset() {
        scene.resetGame()
        state.start(with: model.motionPose.pitch)
    }
}
