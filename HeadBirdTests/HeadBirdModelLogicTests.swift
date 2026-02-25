import CoreBluetooth
import CoreMotion
import Foundation
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

    func testHasAnyAirPodsConnectionSupportsMotionOnlyFallback() {
        XCTAssertFalse(
            HeadBirdModelLogic.hasAnyAirPodsConnection(
                connectedAirPods: [],
                motionHeadphoneConnected: false
            )
        )
        XCTAssertTrue(
            HeadBirdModelLogic.hasAnyAirPodsConnection(
                connectedAirPods: ["AirPods Pro"],
                motionHeadphoneConnected: false
            )
        )
        XCTAssertTrue(
            HeadBirdModelLogic.hasAnyAirPodsConnection(
                connectedAirPods: [],
                motionHeadphoneConnected: true
            )
        )
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
                isGestureTesterEnabled: false,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .denied,
                isPopoverVisible: true,
                activeTab: .motion,
                isGestureTesterEnabled: false,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                hasGestureProfile: true,
                hasPromptTarget: true,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .motion,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: true
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGestureTesterEnabled: true,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: false,
                activeTab: .motion,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: true,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .motion,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGestureTesterEnabled: false,
                isGraphPlaying: true,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .controls,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: true,
                isCalibrationCapturing: false
            )
        )

        XCTAssertTrue(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: true,
                activeTab: .game,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: false,
                activeTab: .game,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: false,
                hasGestureProfile: false,
                hasPromptTarget: false,
                isCalibrationCapturing: false
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldStreamMotion(
                hasAnyAirPodsConnection: true,
                motionAuthorization: .authorized,
                isPopoverVisible: false,
                activeTab: .controls,
                isGestureTesterEnabled: false,
                isGraphPlaying: false,
                gestureControlEnabled: true,
                hasGestureProfile: false,
                hasPromptTarget: false,
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

    func testGestureAnalysisAndExecutionPolicies() {
        XCTAssertFalse(
            HeadBirdModelLogic.shouldAnalyzeGestures(
                motionStreaming: false,
                isGestureTesterActive: true,
                gestureControlEnabled: false,
                hasGestureProfile: false,
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
                isGestureTesterActive: false,
                gestureControlEnabled: true,
                hasGestureProfile: true,
                hasPromptTarget: true
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

    func testLegacyGestureSettingsMigrationClearsDeprecatedKeysAndKeepsRelevantSettings() {
        let suiteName = "HeadBirdModelLogicTests.Migration.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults suite.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        defaults.set(true, forKey: "HeadBird.GestureControlEnabled")
        defaults.set(true, forKey: "HeadBird.PendingCalibrationStart")
        defaults.set("legacy", forKey: "HeadBird.NodMappedAction")
        defaults.set("legacy", forKey: "HeadBird.ShakeMappedAction")
        defaults.set("legacy", forKey: "HeadBird.NodShortcutName")
        defaults.set("legacy", forKey: "HeadBird.ShakeShortcutName")
        defaults.set(0.4, forKey: "HeadBird.GestureCooldownSeconds")
        defaults.set(true, forKey: "HeadBird.DoubleConfirmEnabled")

        HeadBirdModel.sanitizeLegacyGestureSettingsIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.object(forKey: "HeadBird.GestureControlEnabled") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "HeadBird.PendingCalibrationStart") as? Bool, true)
        XCTAssertNil(defaults.object(forKey: "HeadBird.NodMappedAction"))
        XCTAssertNil(defaults.object(forKey: "HeadBird.ShakeMappedAction"))
        XCTAssertNil(defaults.object(forKey: "HeadBird.NodShortcutName"))
        XCTAssertNil(defaults.object(forKey: "HeadBird.ShakeShortcutName"))
        XCTAssertNil(defaults.object(forKey: "HeadBird.GestureCooldownSeconds"))
        XCTAssertNil(defaults.object(forKey: "HeadBird.DoubleConfirmEnabled"))
        XCTAssertEqual(defaults.object(forKey: "HeadBird.PromptOnlyMigrationCompleted") as? Bool, true)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLegacyGestureSettingsMigrationIsOneTimeAndIdempotent() {
        let suiteName = "HeadBirdModelLogicTests.MigrationRepeat.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults suite.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        HeadBirdModel.sanitizeLegacyGestureSettingsIfNeeded(defaults: defaults)
        defaults.set("after-migration", forKey: "HeadBird.NodMappedAction")

        HeadBirdModel.sanitizeLegacyGestureSettingsIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.object(forKey: "HeadBird.NodMappedAction") as? String, "after-migration")
        XCTAssertEqual(defaults.object(forKey: "HeadBird.PromptOnlyMigrationCompleted") as? Bool, true)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPromptTargetBannerEventPolicy() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: nil,
                currentReadyState: false,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertEqual(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: nil,
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            ),
            .ready
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: false,
                currentReadyState: true,
                canExecuteGestureActions: false,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: false,
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: true,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertEqual(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: false,
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            ),
            .ready
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: true,
                currentReadyState: false,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: true,
                currentReadyState: false,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: now.addingTimeInterval(-1.0),
                cooldownSeconds: 1.8
            )
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousReadyState: true,
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )
    }

    func testDeferredPromptReadyBannerDeliveryPolicy() {
        let now = Date(timeIntervalSince1970: 2_000)

        XCTAssertTrue(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                hasPendingReadyBanner: true,
                pendingDetectedAt: now.addingTimeInterval(-0.5),
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                hasPendingReadyBanner: true,
                pendingDetectedAt: now.addingTimeInterval(-3.0),
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                hasPendingReadyBanner: true,
                pendingDetectedAt: now.addingTimeInterval(-0.5),
                currentReadyState: false,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                hasPendingReadyBanner: true,
                pendingDetectedAt: now.addingTimeInterval(-0.5),
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: true,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                hasPendingReadyBanner: true,
                pendingDetectedAt: now.addingTimeInterval(-0.5),
                currentReadyState: true,
                canExecuteGestureActions: true,
                isPopoverVisible: false,
                now: now,
                lastBannerTimestamp: now.addingTimeInterval(-1.0),
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )
    }

    func testPromptTargetBannerEventPolicyUsesPromptSignatureIdentity() {
        let now = Date(timeIntervalSince1970: 3_000)

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousPromptSignature: nil,
                currentPromptSignature: nil,
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertEqual(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousPromptSignature: nil,
                currentPromptSignature: "finder::emptytrash",
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            ),
            .ready
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousPromptSignature: "finder::emptytrash",
                currentPromptSignature: "finder::emptytrash",
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )

        XCTAssertEqual(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousPromptSignature: "finder::emptytrash",
                currentPromptSignature: "finder::deleteimmediately",
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            ),
            .ready
        )

        XCTAssertNil(
            HeadBirdModelLogic.promptTargetBannerEvent(
                previousPromptSignature: nil,
                currentPromptSignature: "finder::emptytrash",
                canExecuteGestureActions: true,
                suppressForPopover: true,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8
            )
        )
    }

    func testDeferredPromptReadyBannerDeliveryPolicyUsesSignatureMatch() {
        let now = Date(timeIntervalSince1970: 4_000)

        XCTAssertTrue(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                pendingPromptSignature: "finder::emptytrash",
                pendingDetectedAt: now.addingTimeInterval(-0.4),
                currentPromptSignature: "finder::emptytrash",
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                pendingPromptSignature: "finder::emptytrash",
                pendingDetectedAt: now.addingTimeInterval(-0.4),
                currentPromptSignature: "finder::deleteimmediately",
                canExecuteGestureActions: true,
                suppressForPopover: false,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )

        XCTAssertFalse(
            HeadBirdModelLogic.shouldDeliverDeferredPromptReadyBanner(
                pendingPromptSignature: "finder::emptytrash",
                pendingDetectedAt: now.addingTimeInterval(-0.4),
                currentPromptSignature: "finder::emptytrash",
                canExecuteGestureActions: true,
                suppressForPopover: true,
                now: now,
                lastBannerTimestamp: nil,
                cooldownSeconds: 1.8,
                pendingMaxAgeSeconds: 2.0
            )
        )
    }
}
