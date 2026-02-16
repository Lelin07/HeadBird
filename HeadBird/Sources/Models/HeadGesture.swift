import Foundation

enum HeadGesture: String, Codable, CaseIterable, Identifiable {
    case nod
    case shake

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nod:
            return "Nod"
        case .shake:
            return "Shake"
        }
    }
}

struct HeadGestureEvent: Equatable, Sendable {
    let gesture: HeadGesture
    let timestamp: TimeInterval
    let confidence: Double
}

struct GestureThresholdProfile: Codable, Equatable, Sendable {
    static let currentVersion: Int = 1

    let version: Int
    let baselinePitch: Double
    let baselineYaw: Double
    let neutralDeadzone: Double
    let nodAmplitudeThreshold: Double
    let nodVelocityThreshold: Double
    let shakeAmplitudeThreshold: Double
    let shakeVelocityThreshold: Double
    let minConfidence: Double
    let cooldownSeconds: Double

    static let fallback = GestureThresholdProfile(
        version: currentVersion,
        baselinePitch: 0,
        baselineYaw: 0,
        neutralDeadzone: 0.035,
        nodAmplitudeThreshold: 0.16,
        nodVelocityThreshold: 0.65,
        shakeAmplitudeThreshold: 0.2,
        shakeVelocityThreshold: 0.85,
        minConfidence: 0.55,
        cooldownSeconds: 0.9
    )
}

enum GestureMappedAction: String, Codable, CaseIterable, Identifiable {
    case promptResponse
    case runShortcut
    case recenterMotion
    case toggleControlMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .promptResponse:
            return "Prompt Accept/Reject"
        case .runShortcut:
            return "Run Shortcut"
        case .recenterMotion:
            return "Set Zero"
        case .toggleControlMode:
            return "Toggle Control Mode"
        }
    }

    var requiresShortcutName: Bool {
        self == .runShortcut
    }
}

struct GestureActionRouteConfig: Equatable, Sendable {
    var nodAction: GestureMappedAction
    var shakeAction: GestureMappedAction
    var nodShortcutName: String
    var shakeShortcutName: String
}

enum GestureCalibrationStage: String, Codable, CaseIterable, Sendable {
    case notStarted
    case neutral
    case nod
    case shake
    case completed
}

struct GestureCalibrationState: Equatable, Sendable {
    var stage: GestureCalibrationStage
    var isCapturing: Bool
    var progress: Double
    var message: String
    var hasProfile: Bool

    static let initial = GestureCalibrationState(
        stage: .notStarted,
        isCapturing: false,
        progress: 0,
        message: "Calibration required before enabling control mode.",
        hasProfile: false
    )
}

enum PromptDecision {
    case accept
    case reject
}

enum GestureActionResult: Equatable, Sendable {
    case success(String)
    case failure(String)
    case ignored(String)

    var message: String {
        switch self {
        case let .success(message), let .failure(message), let .ignored(message):
            return message
        }
    }
}
