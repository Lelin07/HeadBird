import CoreBluetooth
import CoreMotion
import XCTest
@testable import HeadBird

@MainActor
final class HeadBirdModelLogicTests: XCTestCase {
    func testNormalizeRemovesPunctuationSpacingAndCase() {
        XCTAssertEqual(HeadBirdModelLogic.normalize(" AirPods Pro (LeLin) "), "airpodsprolelin")
    }

    func testNamesMatchHandlesExactAndContainsBothWays() {
        XCTAssertTrue(HeadBirdModelLogic.namesMatch("AirPods Pro", "airpodspro"))
        XCTAssertTrue(HeadBirdModelLogic.namesMatch("AirPods", "AirPods Pro"))
        XCTAssertTrue(HeadBirdModelLogic.namesMatch("AirPods Pro", "AirPods"))
        XCTAssertFalse(HeadBirdModelLogic.namesMatch("AirPods", "MacBook Speakers"))
    }

    func testIsAirPodsNameDetectsCommonVariants() {
        XCTAssertTrue(HeadBirdModelLogic.isAirPodsName("AirPods"))
        XCTAssertTrue(HeadBirdModelLogic.isAirPodsName("AIRPODS-PRO-2"))
        XCTAssertFalse(HeadBirdModelLogic.isAirPodsName("Beats Studio"))
    }

    func testHeadStateMatrix() {
        XCTAssertEqual(
            HeadBirdModelLogic.headState(hasAnyAirPodsConnection: false, isActive: false, motionStreaming: false),
            .asleep
        )
        XCTAssertEqual(
            HeadBirdModelLogic.headState(hasAnyAirPodsConnection: true, isActive: false, motionStreaming: false),
            .idle
        )
        XCTAssertEqual(
            HeadBirdModelLogic.headState(hasAnyAirPodsConnection: true, isActive: true, motionStreaming: false),
            .active
        )
        XCTAssertEqual(
            HeadBirdModelLogic.headState(hasAnyAirPodsConnection: true, isActive: false, motionStreaming: true),
            .active
        )
    }

    func testMotionConnectionStatusMatrix() {
        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: false,
                bluetoothAuthorization: .denied,
                motionAuthorization: .authorized,
                motionStreaming: false,
                motionAvailable: false
            ),
            .bluetoothPermissionRequired
        )

        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: false,
                bluetoothAuthorization: .allowedAlways,
                motionAuthorization: .authorized,
                motionStreaming: false,
                motionAvailable: false
            ),
            .notConnected
        )

        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: true,
                bluetoothAuthorization: .allowedAlways,
                motionAuthorization: .denied,
                motionStreaming: false,
                motionAvailable: false
            ),
            .motionPermissionRequired
        )

        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: true,
                bluetoothAuthorization: .allowedAlways,
                motionAuthorization: .authorized,
                motionStreaming: false,
                motionAvailable: true
            ),
            .waiting
        )

        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: true,
                bluetoothAuthorization: .allowedAlways,
                motionAuthorization: .authorized,
                motionStreaming: true,
                motionAvailable: false
            ),
            .motionUnavailable
        )

        XCTAssertEqual(
            HeadBirdModelLogic.motionConnectionStatus(
                hasAnyAirPodsConnection: true,
                bluetoothAuthorization: .allowedAlways,
                motionAuthorization: .authorized,
                motionStreaming: true,
                motionAvailable: true
            ),
            .connected
        )
    }

    func testActiveAirPodsNamePrefersDefaultOutputMatchAndFallsBack() {
        let names = ["AirPods Pro", "AirPods Max"]

        XCTAssertEqual(
            HeadBirdModelLogic.activeAirPodsName(
                connectedAirPods: names,
                defaultOutputName: "airpodsmax",
                motionHeadphoneConnected: false
            ),
            "AirPods Max"
        )

        XCTAssertEqual(
            HeadBirdModelLogic.activeAirPodsName(
                connectedAirPods: names,
                defaultOutputName: "Unknown Device",
                motionHeadphoneConnected: false
            ),
            "AirPods Pro"
        )

        XCTAssertEqual(
            HeadBirdModelLogic.activeAirPodsName(
                connectedAirPods: [],
                defaultOutputName: nil,
                motionHeadphoneConnected: true
            ),
            "AirPods"
        )
    }

    func testStatusTextDerivation() {
        XCTAssertEqual(HeadBirdModelLogic.statusTitle(activeAirPodsName: nil), "No AirPods Connected")
        XCTAssertEqual(HeadBirdModelLogic.statusTitle(activeAirPodsName: "AirPods Pro"), "AirPods Pro")

        XCTAssertEqual(
            HeadBirdModelLogic.statusSubtitle(hasAnyAirPodsConnection: false, isActive: false),
            "Open the case to connect."
        )
        XCTAssertEqual(
            HeadBirdModelLogic.statusSubtitle(hasAnyAirPodsConnection: true, isActive: false),
            "Connected"
        )
        XCTAssertEqual(
            HeadBirdModelLogic.statusSubtitle(hasAnyAirPodsConnection: true, isActive: true),
            "Active"
        )
    }

    func testShouldStreamMotionDemandRules() {
        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: false,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .denied,
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: false,
                activeTab: .motion,
                isGraphPlaying: true,
                gestureControlEnabled: true,
                isCalibrationCapturing: true
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                isCalibrationCapturing: true
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .game,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: false,
                activeTab: .game,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                isCalibrationCapturing: false
            )
        )
    }

    func testShouldPublishVisualMotionUpdatesRules() {
        XCTAssertTrue(
            HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: true
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
                isPopoverVisible: true,
                activeTab: .motion,
                isGraphPlaying: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
                isPopoverVisible: true,
                activeTab: .game,
                isGraphPlaying: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
                isPopoverVisible: true,
                activeTab: .controls,
                isGraphPlaying: true
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
                isPopoverVisible: false,
                activeTab: .motion,
                isGraphPlaying: true
            )
        )
    }
}
