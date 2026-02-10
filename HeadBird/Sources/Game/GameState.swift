import Combine
import Foundation

@MainActor
final class GameState: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var score: Int = 0
    @Published var highScore: Int
    @Published var statusMessage: String = "Tap Play to start"
    @Published var sensitivity: Double = 1.0
    @Published var hasPlayed: Bool = false

    private let highScoreKey = "HeadBarHighScore"
    private var baselinePitch: Double = 0
    private var currentPitch: Double = 0
    private let deadzoneDegrees: Double = 1.5

    init() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func updatePitch(_ pitch: Double) {
        currentPitch = pitch
    }

    func start(with pitch: Double) {
        baselinePitch = pitch
        score = 0
        isPlaying = true
        hasPlayed = true
        statusMessage = ""
    }

    func endGame() {
        isPlaying = false
        statusMessage = "Game Over"
        updateHighScoreIfNeeded()
    }

    func incrementScore() {
        score += 1
        updateHighScoreIfNeeded()
    }

    var pitchDelta: Double {
        let delta = currentPitch - baselinePitch
        let deadzone = deadzoneDegrees * .pi / 180.0
        if abs(delta) < deadzone {
            return 0
        }
        return delta
    }

    private func updateHighScoreIfNeeded() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: highScoreKey)
        }
    }
}
