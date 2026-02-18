import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case flappy
    case pong

    static let selectionKey = "HeadBird.SelectedGameMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flappy:
            return "Flappy"
        case .pong:
            return "Pong"
        }
    }

    var highScoreKey: String {
        switch self {
        case .flappy:
            return "HeadBirdHighScore"
        case .pong:
            return "HeadBirdPongHighScore"
        }
    }

    var legacyHighScoreKey: String {
        switch self {
        case .flappy:
            return "HeadBarHighScore"
        case .pong:
            return "HeadBirdPongHighScore.Legacy"
        }
    }
}
