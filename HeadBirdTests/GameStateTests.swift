import XCTest
@testable import HeadBird

final class GameStateTests: XCTestCase {
    @MainActor private static var retainedStates: [GameState] = []
    private var defaults: UserDefaults!
    private var highScoreKey: String!
    private var legacyHighScoreKey: String!

    override func setUp() {
        super.setUp()
        defaults = .standard
        let id = UUID().uuidString
        highScoreKey = "HeadBirdTests.High.\(id)"
        legacyHighScoreKey = "HeadBirdTests.Legacy.\(id)"
    }

    override func tearDown() {
        defaults.removeObject(forKey: highScoreKey)
        defaults.removeObject(forKey: legacyHighScoreKey)
        defaults = nil
        highScoreKey = nil
        legacyHighScoreKey = nil
        super.tearDown()
    }

    @MainActor
    func testInitializesHighScoreFromNewKeyWhenPresent() {
        defaults.set(42, forKey: highScoreKey)

        let state = makeState()

        XCTAssertEqual(state.highScore, 42)
    }

    @MainActor
    func testMigratesLegacyHighScoreWhenNewKeyMissing() {
        defaults.set(9, forKey: legacyHighScoreKey)

        let state = makeState()

        XCTAssertEqual(state.highScore, 9)
        XCTAssertEqual(defaults.integer(forKey: highScoreKey), 9)
    }

    @MainActor
    func testStartResetsGameState() {
        let state = makeState()
        state.score = 5
        state.statusMessage = "Game Over"

        state.start(with: 0.7)

        XCTAssertTrue(state.isPlaying)
        XCTAssertTrue(state.hasPlayed)
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.statusMessage, "")
    }

    @MainActor
    func testIncrementScoreUpdatesAndPersistsHighScore() {
        let state = makeState()

        state.incrementScore()

        XCTAssertEqual(state.score, 1)
        XCTAssertEqual(state.highScore, 1)
        XCTAssertEqual(defaults.integer(forKey: highScoreKey), 1)
    }

    @MainActor
    func testEndGameSetsStatusAndPersistsHighScore() {
        let state = makeState()
        state.score = 3

        state.endGame()

        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.statusMessage, "Game Over")
        XCTAssertEqual(state.highScore, 3)
        XCTAssertEqual(defaults.integer(forKey: highScoreKey), 3)
    }

    @MainActor
    func testPitchDeltaAppliesDeadzone() {
        let state = makeState()
        state.start(with: 0)

        state.updatePitch(0.01)
        XCTAssertEqual(state.pitchDelta, 0, accuracy: 0.000_001)

        state.updatePitch(0.05)
        XCTAssertEqual(state.pitchDelta, 0.05, accuracy: 0.000_001)

        state.updatePitch(-0.04)
        XCTAssertEqual(state.pitchDelta, -0.04, accuracy: 0.000_001)
    }

    @MainActor
    private func makeState() -> GameState {
        let state = GameState(
            userDefaults: defaults,
            highScoreKey: highScoreKey,
            legacyHighScoreKey: legacyHighScoreKey
        )
        Self.retainedStates.append(state)
        return state
    }
}
