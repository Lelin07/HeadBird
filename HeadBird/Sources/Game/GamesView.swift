import SwiftUI

struct GamesView: View {
    let isActive: Bool

    @AppStorage(GameMode.selectionKey) private var selectedModeRawValue: String = GameMode.flappy.rawValue

    var body: some View {
        VStack(spacing: 6) {
            switch selectedMode {
            case .flappy:
                FlappyGameView(isActive: isActive, selectedMode: selectedModeBinding)
            case .pong:
                PongGameView(isActive: isActive, selectedMode: selectedModeBinding)
            }
        }
        .onAppear {
            if GameMode(rawValue: selectedModeRawValue) == nil {
                selectedModeRawValue = GameMode.flappy.rawValue
            }
        }
    }

    private var selectedMode: GameMode {
        GameMode(rawValue: selectedModeRawValue) ?? .flappy
    }

    private var selectedModeBinding: Binding<GameMode> {
        Binding(
            get: { selectedMode },
            set: { selectedModeRawValue = $0.rawValue }
        )
    }
}
