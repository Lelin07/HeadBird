import SpriteKit
import SwiftUI

struct FlappyGameView: View {
    @EnvironmentObject private var model: HeadBirdModel
    @StateObject private var state: GameState
    @State private var scene: FlappyGameScene

    let isActive: Bool
    let selectedMode: Binding<GameMode>

    init(isActive: Bool, selectedMode: Binding<GameMode>) {
        self.isActive = isActive
        self.selectedMode = selectedMode
        let gameState = GameState(
            highScoreKey: GameMode.flappy.highScoreKey,
            legacyHighScoreKey: GameMode.flappy.legacyHighScoreKey
        )
        _state = StateObject(wrappedValue: gameState)
        _scene = State(initialValue: FlappyGameScene(state: gameState))
    }

    var body: some View {
        VStack(spacing: FlappyGameLayout.contentSpacing) {
            HStack(spacing: FlappyGameLayout.controlSpacing) {
                Text(model.activeAirPodsName ?? "Not connected")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusPill(status: model.motionConnectionStatus)
            }

            HStack(spacing: FlappyGameLayout.controlSpacing) {
                Picker("Game", selection: selectedMode) {
                    ForEach(GameMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer(minLength: FlappyGameLayout.toolbarSpacerMinLength)
                Button(action: handlePrimaryAction) { primaryActionLabel }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.connectedAirPods.isEmpty)

                Button("Reset") {
                    resetGame()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!state.hasPlayed && !state.isPlaying && !state.isPaused)
            }

            ZStack(alignment: .top) {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(height: FlappyGameLayout.surfaceHeight)
                    .background(
                        RoundedRectangle(cornerRadius: FlappyGameLayout.surfaceCornerRadius, style: .continuous)
                            .fill(Color.secondary.opacity(0.11))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FlappyGameLayout.surfaceCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FlappyGameLayout.surfaceCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )

                HStack {
                    Text("Score \(state.score)")
                    Spacer()
                    Text("Best \(state.highScore)")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
                .padding(10)

                if !state.statusMessage.isEmpty {
                    Text(state.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: FlappyGameLayout.statusMessageYOffset)
                }
            }
            .frame(height: FlappyGameLayout.surfaceHeight)

            VStack(spacing: FlappyGameLayout.helpSpacing) {
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
        }
        .padding(.horizontal, FlappyGameLayout.horizontalPadding)
        .padding(.vertical, FlappyGameLayout.verticalPadding)
        .onReceive(model.$motionPose) { pose in
            state.updatePitch(pose.pitch)
        }
        .onAppear {
            scene.isPaused = !isActive
            if !isActive && state.isPlaying {
                state.pause()
            }
        }
        .onDisappear {
            scene.isPaused = true
        }
        .onChange(of: isActive) { _, active in
            scene.isPaused = !active
            if !active && state.isPlaying {
                state.pause()
            }
        }
    }

    private var primaryActionLabel: some View {
        if state.isPlaying {
            return Label("Pause", systemImage: "pause.fill")
        }
        if state.isPaused {
            return Label("Resume", systemImage: "play.fill")
        }
        if state.hasPlayed {
            return Label("Play", systemImage: "play.fill")
        }
        return Label("Play", systemImage: "play.fill")
    }

    private func handlePrimaryAction() {
        if state.isPlaying {
            state.pause()
            return
        }

        if state.isPaused {
            state.resume()
            return
        }

        startGame()
    }

    private func startGame() {
        scene.resetGame()
        state.start(with: model.motionPose.pitch)
    }

    private func resetGame() {
        scene.resetGame()
        state.reset()
    }
}

private enum FlappyGameLayout {
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 8
    static let contentSpacing: CGFloat = 8
    static let controlSpacing: CGFloat = 8
    static let helpSpacing: CGFloat = 4
    static let toolbarSpacerMinLength: CGFloat = 8
    static let surfaceHeight: CGFloat = 200
    static let surfaceCornerRadius: CGFloat = 12
    static let statusMessageYOffset: CGFloat = 16
}
