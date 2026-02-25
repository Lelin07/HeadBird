import XCTest
@testable import HeadBird

@MainActor
final class GestureProcessingPolicyTests: XCTestCase {
    func testGestureAnalysisRespectsPromptAndTesterPolicies() {
        XCTAssertFalse(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: true,
                isGestureTesterActive: false,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: true,
                isGestureTesterActive: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: true,
                isGestureTesterActive: true,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: true,
                isGestureTesterActive: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: true
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
