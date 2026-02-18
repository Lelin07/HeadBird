import XCTest
@testable import HeadBird

final class GameModeTests: XCTestCase {
    func testRawValueMapping() {
        XCTAssertEqual(GameMode(rawValue: "flappy"), .flappy)
        XCTAssertEqual(GameMode(rawValue: "pong"), .pong)
        XCTAssertNil(GameMode(rawValue: "unknown"))
    }

    @MainActor
    func testMetadataKeys() {
        let flappyHighScoreKey = GameMode.flappy.highScoreKey
        let flappyLegacyKey = GameMode.flappy.legacyHighScoreKey
        let pongHighScoreKey = GameMode.pong.highScoreKey
        let pongLegacyKey = GameMode.pong.legacyHighScoreKey

        XCTAssertEqual(flappyHighScoreKey, "HeadBirdHighScore")
        XCTAssertEqual(flappyLegacyKey, "HeadBarHighScore")
        XCTAssertEqual(pongHighScoreKey, "HeadBirdPongHighScore")
        XCTAssertEqual(pongLegacyKey, "HeadBirdPongHighScore.Legacy")
    }

    func testFallbackModeForUnknownStoredValue() {
        let fallback = GameMode(rawValue: "invalid") ?? .flappy
        XCTAssertEqual(fallback, .flappy)
    }
}
