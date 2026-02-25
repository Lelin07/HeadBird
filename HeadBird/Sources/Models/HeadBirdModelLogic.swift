import CoreBluetooth
import CoreMotion
import Foundation

enum HeadBirdModelLogic {
    enum PromptTargetBannerEvent: Equatable {
        case ready
    }

    static func hasAnyAirPodsConnection(
        connectedAirPods: [String],
        motionHeadphoneConnected: Bool
    ) -> Bool {
        connectedAirPods.isEmpty == false || motionHeadphoneConnected
    }

    static func activeAirPodsName(
        connectedAirPods: [String],
        defaultOutputName: String?,
        motionHeadphoneConnected: Bool
    ) -> String? {
        if connectedAirPods.isEmpty == false {
            if let defaultOutputName,
               let match = connectedAirPods.first(where: { namesMatch($0, defaultOutputName) }) {
                return match
            }
            return connectedAirPods.first
        }
        return motionHeadphoneConnected ? "AirPods" : nil
    }

    static func isActive(activeAirPodsName: String?, defaultOutputName: String?) -> Bool {
        guard let activeAirPodsName, let defaultOutputName else { return false }
        return namesMatch(activeAirPodsName, defaultOutputName)
    }

    static func headState(hasAnyAirPodsConnection: Bool, isActive: Bool, motionStreaming: Bool) -> HeadState {
        if !hasAnyAirPodsConnection {
            return .asleep
        }
        if isActive || motionStreaming {
            return .active
        }
        return .idle
    }

    static func motionConnectionStatus(
        hasAnyAirPodsConnection: Bool,
        bluetoothAuthorization: CBManagerAuthorization,
        motionAuthorization: CMAuthorizationStatus,
        motionStreaming: Bool,
        motionAvailable: Bool
    ) -> MotionConnectionStatus {
        if !hasAnyAirPodsConnection,
           (bluetoothAuthorization == .denied || bluetoothAuthorization == .restricted) {
            return .bluetoothPermissionRequired
        }
        if !hasAnyAirPodsConnection {
            return .notConnected
        }
        if motionAuthorization == .denied || motionAuthorization == .restricted {
            return .motionPermissionRequired
        }
        if !motionStreaming {
            return .waiting
        }
        if !motionAvailable {
            return .motionUnavailable
        }
        return .connected
    }

    static func statusTitle(activeAirPodsName: String?) -> String {
        activeAirPodsName ?? "No AirPods Connected"
    }

    static func statusSubtitle(hasAnyAirPodsConnection: Bool, isActive: Bool) -> String {
        guard hasAnyAirPodsConnection else {
            return "Open the case to connect."
        }
        return isActive ? "Active" : "Connected"
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalize(lhs)
        let right = normalize(rhs)
        return left == right || left.contains(right) || right.contains(left)
    }

    static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func isAirPodsName(_ name: String) -> Bool {
        normalize(name).contains("airpods")
    }

    static func shouldStreamMotion(
        hasAnyAirPodsConnection: Bool,
        motionAuthorization: CMAuthorizationStatus,
        isPopoverVisible: Bool,
        activeTab: PopoverTab,
        isGestureTesterEnabled: Bool,
        isGraphPlaying: Bool,
        gestureControlEnabled: Bool,
        hasGestureProfile: Bool,
        hasPromptTarget: Bool,
        isCalibrationCapturing: Bool
    ) -> Bool {
        guard hasAnyAirPodsConnection else { return false }
        guard motionAuthorization != .denied, motionAuthorization != .restricted else { return false }

        if isCalibrationCapturing {
            return true
        }
        if isGestureTesterEnabled {
            return true
        }
        if gestureControlEnabled && hasGestureProfile && hasPromptTarget {
            return true
        }

        guard isPopoverVisible else { return false }

        let needsMotionGraph = activeTab == .motion && isGraphPlaying
        let needsGame = activeTab == .game
        return needsMotionGraph || needsGame
    }

    static func shouldAnalyzeGestures(
        motionStreaming: Bool,
        isGestureTesterActive: Bool,
        gestureControlEnabled: Bool,
        hasGestureProfile: Bool,
        hasPromptTarget: Bool
    ) -> Bool {
        guard motionStreaming else { return false }
        if isGestureTesterActive {
            return true
        }
        return shouldExecuteGestureActions(
            gestureControlEnabled: gestureControlEnabled,
            hasGestureProfile: hasGestureProfile
        ) && hasPromptTarget
    }

    static func shouldExecuteGestureActions(
        gestureControlEnabled: Bool,
        hasGestureProfile: Bool
    ) -> Bool {
        gestureControlEnabled && hasGestureProfile
    }

    static func shouldPublishVisualMotionUpdates(
        isPopoverVisible: Bool,
        activeTab: PopoverTab,
        isGraphPlaying: Bool
    ) -> Bool {
        guard isPopoverVisible else { return false }
        switch activeTab {
        case .motion:
            return isGraphPlaying
        case .game:
            return true
        case .controls, .about:
            return false
        }
    }

    static func promptTargetBannerEvent(
        previousPromptSignature: String?,
        currentPromptSignature: String?,
        canExecuteGestureActions: Bool,
        suppressForPopover: Bool,
        now: Date,
        lastBannerTimestamp: Date?,
        cooldownSeconds: TimeInterval
    ) -> PromptTargetBannerEvent? {
        guard canExecuteGestureActions else { return nil }
        guard !suppressForPopover else { return nil }
        guard let currentPromptSignature else { return nil }
        if let previousPromptSignature, previousPromptSignature == currentPromptSignature {
            return nil
        }
        if let lastBannerTimestamp,
           now.timeIntervalSince(lastBannerTimestamp) < cooldownSeconds {
            return nil
        }
        return .ready
    }

    static func shouldDeliverDeferredPromptReadyBanner(
        pendingPromptSignature: String?,
        pendingDetectedAt: Date?,
        currentPromptSignature: String?,
        canExecuteGestureActions: Bool,
        suppressForPopover: Bool,
        now: Date,
        lastBannerTimestamp: Date?,
        cooldownSeconds: TimeInterval,
        pendingMaxAgeSeconds: TimeInterval
    ) -> Bool {
        guard let pendingPromptSignature else { return false }
        guard canExecuteGestureActions else { return false }
        guard !suppressForPopover else { return false }
        guard let currentPromptSignature, currentPromptSignature == pendingPromptSignature else { return false }
        if let pendingDetectedAt,
           now.timeIntervalSince(pendingDetectedAt) > pendingMaxAgeSeconds {
            return false
        }
        if let lastBannerTimestamp,
           now.timeIntervalSince(lastBannerTimestamp) < cooldownSeconds {
            return false
        }
        return true
    }

    static func promptTargetBannerEvent(
        previousReadyState: Bool?,
        currentReadyState: Bool,
        canExecuteGestureActions: Bool,
        isPopoverVisible: Bool,
        now: Date,
        lastBannerTimestamp: Date?,
        cooldownSeconds: TimeInterval
    ) -> PromptTargetBannerEvent? {
        guard canExecuteGestureActions else { return nil }
        guard !isPopoverVisible else { return nil }
        if let previousReadyState, previousReadyState == currentReadyState {
            return nil
        }
        if let lastBannerTimestamp,
           now.timeIntervalSince(lastBannerTimestamp) < cooldownSeconds {
            return nil
        }
        guard currentReadyState else { return nil }
        return .ready
    }

    static func shouldDeliverDeferredPromptReadyBanner(
        hasPendingReadyBanner: Bool,
        pendingDetectedAt: Date?,
        currentReadyState: Bool,
        canExecuteGestureActions: Bool,
        isPopoverVisible: Bool,
        now: Date,
        lastBannerTimestamp: Date?,
        cooldownSeconds: TimeInterval,
        pendingMaxAgeSeconds: TimeInterval
    ) -> Bool {
        guard hasPendingReadyBanner else { return false }
        guard canExecuteGestureActions else { return false }
        guard !isPopoverVisible else { return false }
        guard currentReadyState else { return false }
        if let pendingDetectedAt,
           now.timeIntervalSince(pendingDetectedAt) > pendingMaxAgeSeconds {
            return false
        }
        if let lastBannerTimestamp,
           now.timeIntervalSince(lastBannerTimestamp) < cooldownSeconds {
            return false
        }
        return true
    }
}
