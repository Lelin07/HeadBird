import XCTest
@testable import HeadBird

@MainActor
final class GestureProcessingPolicyTests: XCTestCase {
    func testTesterModeAnalyzesGesturesWhenControlModeIsOff() {
        XCTAssertTrue(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: true,
                isGestureTesterActive: true,
                gestureControlEnabled: false,
                hasGestureProfile: false
            )
        )
    }

    func testActionsRequireBothControlModeAndProfile() {
        XCTAssertFalse(
            HeadBirdModelLogic.shouldExecuteGestureActions(
                gestureControlEnabled: false,
                hasGestureProfile: true
            )
        )
        XCTAssertFalse(
            HeadBirdModelLogic.shouldExecuteGestureActions(
                gestureControlEnabled: true,
                hasGestureProfile: false
            )
        )
        XCTAssertTrue(
            HeadBirdModelLogic.shouldExecuteGestureActions(
                gestureControlEnabled: true,
                hasGestureProfile: true
            )
        )
    }
}
