import CoreBluetooth
import CoreMotion
import Foundation

enum HeadBirdModelLogic {
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
}
