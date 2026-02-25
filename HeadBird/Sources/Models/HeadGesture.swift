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

struct GestureDetectionResult: Equatable, Sendable {
    let rawNodConfidence: Double
    let rawShakeConfidence: Double
    let nodConfidence: Double
    let shakeConfidence: Double
    let candidateGesture: HeadGesture?
    let event: HeadGestureEvent?
}

struct GestureDiagnostics: Equatable, Sendable {
    var rawNodConfidence: Double
    var rawShakeConfidence: Double
    var nodConfidence: Double
    var shakeConfidence: Double
    var triggerThreshold: Double
    var sampleRateHertz: Double
    var candidateGesture: HeadGesture?
    var lastUpdatedTimestamp: TimeInterval?

    static let empty = GestureDiagnostics(
        rawNodConfidence: 0,
        rawShakeConfidence: 0,
        nodConfidence: 0,
        shakeConfidence: 0,
        triggerThreshold: 0,
        sampleRateHertz: 0,
        candidateGesture: nil,
        lastUpdatedTimestamp: nil
    )
}

struct GestureThresholdProfile: Codable, Equatable, Sendable {
    static let currentVersion: Int = 2

    let version: Int
    let baselinePitch: Double
    let baselineYaw: Double
    let neutralDeadzone: Double
    let nodAmplitudeThreshold: Double
    let nodVelocityThreshold: Double
    let shakeAmplitudeThreshold: Double
    let shakeVelocityThreshold: Double
    let nodCrossAxisLeakageMax: Double
    let shakeCrossAxisLeakageMax: Double
    let nodMinCrossings: Int
    let shakeMinCrossings: Int
    let diagnosticSmoothing: Double
    let minConfidence: Double
    let cooldownSeconds: Double

    static let fallback = GestureThresholdProfile(
        version: currentVersion,
        baselinePitch: 0,
        baselineYaw: 0,
        neutralDeadzone: 0.035,
        nodAmplitudeThreshold: 0.12,
        nodVelocityThreshold: 0.50,
        shakeAmplitudeThreshold: 0.16,
        shakeVelocityThreshold: 0.68,
        nodCrossAxisLeakageMax: 0.95,
        shakeCrossAxisLeakageMax: 0.95,
        nodMinCrossings: 1,
        shakeMinCrossings: 2,
        diagnosticSmoothing: 0.32,
        minConfidence: 0.50,
        cooldownSeconds: 0.80
    )
}

enum GestureActionMode: String, Codable, Sendable {
    case promptResponses
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
