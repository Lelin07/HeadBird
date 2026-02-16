import Combine
import Foundation

@MainActor
final class GestureCalibrationService: ObservableObject {
    private struct CalibrationSample {
        let timestamp: TimeInterval
        let pitch: Double
        let yaw: Double
    }

    @Published private(set) var state: GestureCalibrationState = .initial
    @Published private(set) var profile: GestureThresholdProfile = .fallback
    @Published private(set) var isUsingFallbackProfile: Bool = true

    private let profileKey: String
    private let defaults: UserDefaults
    private let captureDuration: TimeInterval
    private var captureStartedAt: TimeInterval?

    private var neutralSamples: [CalibrationSample] = []
    private var nodSamples: [CalibrationSample] = []
    private var shakeSamples: [CalibrationSample] = []

    init(
        defaults: UserDefaults = .standard,
        profileKey: String = "HeadBird.GestureThresholdProfile.v1",
        captureDuration: TimeInterval = 2.2
    ) {
        self.defaults = defaults
        self.profileKey = profileKey
        self.captureDuration = captureDuration
        loadPersistedProfile()
    }

    func startCalibration() {
        neutralSamples.removeAll(keepingCapacity: true)
        nodSamples.removeAll(keepingCapacity: true)
        shakeSamples.removeAll(keepingCapacity: true)
        captureStartedAt = nil

        state = GestureCalibrationState(
            stage: .neutral,
            isCapturing: false,
            progress: 0,
            message: "Neutral stage ready. Keep your head still, then start capture.",
            hasProfile: false
        )
    }

    func beginCaptureForCurrentStage() {
        guard state.stage == .neutral || state.stage == .nod || state.stage == .shake else {
            return
        }

        captureStartedAt = nil
        state.isCapturing = true
        state.progress = 0

        switch state.stage {
        case .neutral:
            neutralSamples.removeAll(keepingCapacity: true)
            state.message = "Capturing neutral pose... keep your head still."
        case .nod:
            nodSamples.removeAll(keepingCapacity: true)
            state.message = "Capture nod: do 2-3 deliberate nods now."
        case .shake:
            shakeSamples.removeAll(keepingCapacity: true)
            state.message = "Capture shake: do 2-3 deliberate shakes now."
        case .notStarted, .completed:
            break
        }
    }

    func ingest(sample: HeadphoneMotionSample) {
        guard state.isCapturing else { return }

        if captureStartedAt == nil {
            captureStartedAt = sample.timestamp
        }
        guard let captureStartedAt else { return }

        let elapsed = sample.timestamp - captureStartedAt
        let progress = max(0, min(1, elapsed / captureDuration))
        state.progress = progress

        let entry = CalibrationSample(timestamp: sample.timestamp, pitch: sample.pitch, yaw: sample.yaw)
        switch state.stage {
        case .neutral:
            neutralSamples.append(entry)
        case .nod:
            nodSamples.append(entry)
        case .shake:
            shakeSamples.append(entry)
        case .notStarted, .completed:
            break
        }

        if progress >= 1 {
            finalizeCurrentCapture()
        }
    }

    func skipCalibrationAndUseFallback() {
        profile = .fallback
        isUsingFallbackProfile = true
        state = GestureCalibrationState(
            stage: .completed,
            isCapturing: false,
            progress: 1,
            message: "Using fallback thresholds. You can recalibrate anytime.",
            hasProfile: true
        )
        persist(profile: profile)
    }

    func clearCalibrationProfile() {
        defaults.removeObject(forKey: profileKey)
        profile = .fallback
        isUsingFallbackProfile = true
        state = .initial
    }

    private func finalizeCurrentCapture() {
        state.isCapturing = false
        state.progress = 1
        captureStartedAt = nil

        switch state.stage {
        case .neutral:
            state.stage = .nod
            state.progress = 0
            state.message = "Neutral captured. Next: nod stage."
        case .nod:
            state.stage = .shake
            state.progress = 0
            state.message = "Nod captured. Next: shake stage."
        case .shake:
            let computed = computeProfile(neutral: neutralSamples, nod: nodSamples, shake: shakeSamples)
            profile = computed
            isUsingFallbackProfile = false
            state = GestureCalibrationState(
                stage: .completed,
                isCapturing: false,
                progress: 1,
                message: "Calibration complete.",
                hasProfile: true
            )
            persist(profile: computed)
        case .notStarted, .completed:
            break
        }
    }

    private func loadPersistedProfile() {
        guard
            let data = defaults.data(forKey: profileKey),
            let decoded = try? JSONDecoder().decode(GestureThresholdProfile.self, from: data),
            decoded.version == GestureThresholdProfile.currentVersion
        else {
            profile = .fallback
            isUsingFallbackProfile = true
            state = .initial
            return
        }

        profile = decoded
        isUsingFallbackProfile = decoded == .fallback
        state = GestureCalibrationState(
            stage: .completed,
            isCapturing: false,
            progress: 1,
            message: "Calibration profile loaded.",
            hasProfile: true
        )
    }

    private func persist(profile: GestureThresholdProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    private func computeProfile(
        neutral: [CalibrationSample],
        nod: [CalibrationSample],
        shake: [CalibrationSample]
    ) -> GestureThresholdProfile {
        guard neutral.count >= 8, nod.count >= 8, shake.count >= 8 else {
            return .fallback
        }

        let baselinePitch = mean(neutral.map(\.pitch))
        let baselineYaw = mean(neutral.map(\.yaw))

        let neutralPitchNoise = standardDeviation(neutral.map { $0.pitch - baselinePitch })
        let neutralYawNoise = standardDeviation(neutral.map { $0.yaw - baselineYaw })

        let nodPitchSeries = nod.map { $0.pitch - baselinePitch }
        let shakeYawSeries = shake.map { $0.yaw - baselineYaw }

        let nodAmplitude = maxAbs(nodPitchSeries)
        let shakeAmplitude = maxAbs(shakeYawSeries)

        let nodVelocity = maxAbs(velocities(from: nod.map { ($0.timestamp, $0.pitch - baselinePitch) }))
        let shakeVelocity = maxAbs(velocities(from: shake.map { ($0.timestamp, $0.yaw - baselineYaw) }))

        let deadzone = max(0.02, max(neutralPitchNoise, neutralYawNoise) * 2.6)

        let nodAmplitudeThreshold = max(deadzone * 2.0, nodAmplitude * 0.42, 0.09)
        let nodVelocityThreshold = max(0.45, nodVelocity * 0.38)
        let shakeAmplitudeThreshold = max(deadzone * 2.4, shakeAmplitude * 0.42, 0.12)
        let shakeVelocityThreshold = max(0.6, shakeVelocity * 0.38)

        return GestureThresholdProfile(
            version: GestureThresholdProfile.currentVersion,
            baselinePitch: baselinePitch,
            baselineYaw: baselineYaw,
            neutralDeadzone: deadzone,
            nodAmplitudeThreshold: nodAmplitudeThreshold,
            nodVelocityThreshold: nodVelocityThreshold,
            shakeAmplitudeThreshold: shakeAmplitudeThreshold,
            shakeVelocityThreshold: shakeVelocityThreshold,
            minConfidence: 0.55,
            cooldownSeconds: 0.9
        )
    }

    private func velocities(from samples: [(timestamp: TimeInterval, value: Double)]) -> [Double] {
        guard samples.count > 1 else { return [] }
        var values: [Double] = []
        values.reserveCapacity(samples.count - 1)

        for index in 1..<samples.count {
            let prev = samples[index - 1]
            let next = samples[index]
            let dt = max(0.000_1, next.timestamp - prev.timestamp)
            values.append((next.value - prev.value) / dt)
        }

        return values
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let variance = values.reduce(0) { partial, value in
            let delta = value - avg
            return partial + (delta * delta)
        } / Double(values.count)
        return sqrt(variance)
    }

    private func maxAbs(_ values: [Double]) -> Double {
        values.reduce(0) { max($0, abs($1)) }
    }
}
