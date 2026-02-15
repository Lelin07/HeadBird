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

    private let userDefaults: UserDefaults
    private let highScoreKey: String
    private let legacyHighScoreKey: String
    private var baselinePitch: Double = 0
    private var currentPitch: Double = 0
    private let deadzoneDegrees: Double = 1.5

    init(
        userDefaults: UserDefaults = .standard,
        highScoreKey: String = "HeadBirdHighScore",
        legacyHighScoreKey: String = "HeadBarHighScore"
    ) {
        self.userDefaults = userDefaults
        self.highScoreKey = highScoreKey
        self.legacyHighScoreKey = legacyHighScoreKey

        if userDefaults.object(forKey: highScoreKey) == nil {
            let legacyValue = userDefaults.integer(forKey: legacyHighScoreKey)
            highScore = legacyValue
            if legacyValue > 0 {
                userDefaults.set(legacyValue, forKey: highScoreKey)
            }
        } else {
            highScore = userDefaults.integer(forKey: highScoreKey)
        }
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
            userDefaults.set(highScore, forKey: highScoreKey)
        }
    }
}
