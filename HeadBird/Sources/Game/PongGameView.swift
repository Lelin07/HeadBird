import SpriteKit
import SwiftUI

struct PongGameView: View {
    @EnvironmentObject private var model: HeadBirdModel
    @StateObject private var state: GameState
    @State private var scene: PongGameScene

    let isActive: Bool
    let selectedMode: Binding<GameMode>

    init(isActive: Bool, selectedMode: Binding<GameMode>) {
        self.isActive = isActive
        self.selectedMode = selectedMode
        let gameState = GameState(
            highScoreKey: GameMode.pong.highScoreKey,
            legacyHighScoreKey: GameMode.pong.legacyHighScoreKey
        )
        _state = StateObject(wrappedValue: gameState)
        _scene = State(initialValue: PongGameScene(state: gameState))
    }

    var body: some View {
        VStack(spacing: PongGameLayout.contentSpacing) {
            HStack(spacing: PongGameLayout.controlSpacing) {
                Text(model.activeAirPodsName ?? "Not connected")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusPill(status: model.motionConnectionStatus)
            }

            HStack(spacing: PongGameLayout.controlSpacing) {
                Picker("Game", selection: selectedMode) {
                    ForEach(GameMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer(minLength: PongGameLayout.toolbarSpacerMinLength)
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
                    .frame(height: PongGameLayout.surfaceHeight)
                    .background(
                        RoundedRectangle(cornerRadius: PongGameLayout.surfaceCornerRadius, style: .continuous)
                            .fill(Color.secondary.opacity(0.11))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PongGameLayout.surfaceCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PongGameLayout.surfaceCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )

                HStack {
                    Text("You \(state.score)")
                    Spacer()
                    Text("CPU \(state.opponentScore)")
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
                        .offset(y: PongGameLayout.statusMessageYOffset)
                }
            }
            .frame(height: PongGameLayout.surfaceHeight)

            VStack(spacing: PongGameLayout.helpSpacing) {
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

                Text("Tilt your head up or down to move your paddle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, PongGameLayout.horizontalPadding)
        .padding(.vertical, PongGameLayout.verticalPadding)
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
            scene.prepareForResume()
            state.resume()
            return
        }

        startGame()
    }

    private func startGame() {
        scene.resetGame()
        state.start(with: model.motionPose.pitch)
        scene.startRound(towardRight: Bool.random())
    }

    private func resetGame() {
        scene.resetGame()
    }
}

private enum PongGameLayout {
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
