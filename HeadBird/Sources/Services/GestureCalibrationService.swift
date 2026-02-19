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
    private let legacyProfileKey: String?
    private let defaults: UserDefaults
    private let captureDuration: TimeInterval
    private var captureStartedAt: TimeInterval?

    private var neutralSamples: [CalibrationSample] = []
    private var nodSamples: [CalibrationSample] = []
    private var shakeSamples: [CalibrationSample] = []

    init(
        defaults: UserDefaults = .standard,
        profileKey: String = "HeadBird.GestureThresholdProfile.v2",
        legacyProfileKey: String? = "HeadBird.GestureThresholdProfile.v1",
        captureDuration: TimeInterval = 2.2
    ) {
        self.defaults = defaults
        self.profileKey = profileKey
        self.legacyProfileKey = legacyProfileKey
        self.captureDuration = captureDuration
        if let legacyProfileKey {
            defaults.removeObject(forKey: legacyProfileKey)
        }
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
            message: "Step 1 of 3: capture neutral. Keep your head still, then press Capture.",
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
            state.message = "Capturing neutral pose... stay still."
        case .nod:
            nodSamples.removeAll(keepingCapacity: true)
            state.message = "Capturing nod stage... do 2-3 deliberate nods."
        case .shake:
            shakeSamples.removeAll(keepingCapacity: true)
            state.message = "Capturing shake stage... do 2-3 deliberate shakes."
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
        if let legacyProfileKey {
            defaults.removeObject(forKey: legacyProfileKey)
        }
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
            state.message = "Step 2 of 3: neutral saved. Capture nod next."
        case .nod:
            state.stage = .shake
            state.progress = 0
            state.message = "Step 3 of 3: nod saved. Capture shake next."
        case .shake:
            let computed = computeProfile(neutral: neutralSamples, nod: nodSamples, shake: shakeSamples)
            profile = computed
            isUsingFallbackProfile = computed == .fallback
            state = GestureCalibrationState(
                stage: .completed,
                isCapturing: false,
                progress: 1,
                message: computed == .fallback ? "Calibration finished with fallback thresholds." : "Calibration complete.",
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

        let sanitized = sanitizeProfile(decoded)
        profile = sanitized
        isUsingFallbackProfile = sanitized == .fallback
        if sanitized != decoded {
            persist(profile: sanitized)
        }
        state = GestureCalibrationState(
            stage: .completed,
            isCapturing: false,
            progress: 1,
            message: sanitized == decoded ? "Calibration profile loaded." : "Calibration profile loaded and optimized.",
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

        let baselinePitch = percentile(neutral.map(\.pitch), quantile: 0.5)
        let baselineYaw = percentile(neutral.map(\.yaw), quantile: 0.5)

        let neutralPitchAbsDeviation = neutral.map { abs($0.pitch - baselinePitch) }
        let neutralYawAbsDeviation = neutral.map { abs($0.yaw - baselineYaw) }
        let neutralPitchNoise = percentile(neutralPitchAbsDeviation, quantile: 0.95)
        let neutralYawNoise = percentile(neutralYawAbsDeviation, quantile: 0.95)

        let nodPitchSeries = nod.map { $0.pitch - baselinePitch }
        let nodYawSeries = nod.map { $0.yaw - baselineYaw }
        let shakePitchSeries = shake.map { $0.pitch - baselinePitch }
        let shakeYawSeries = shake.map { $0.yaw - baselineYaw }

        let nodPitchVelocity = velocities(from: nod.map { ($0.timestamp, $0.pitch - baselinePitch) })
        let shakeYawVelocity = velocities(from: shake.map { ($0.timestamp, $0.yaw - baselineYaw) })
        let nodCrossings = zeroCrossings(values: nodPitchVelocity, floor: 0.18)
        let shakeCrossings = zeroCrossings(values: shakeYawVelocity, floor: 0.20)

        let deadzone = max(0.02, max(neutralPitchNoise, neutralYawNoise) * 2.2)

        let nodAmplitudeP90 = percentile(nodPitchSeries.map { abs($0) }, quantile: 0.90)
        let nodVelocityP90 = percentile(nodPitchVelocity.map { abs($0) }, quantile: 0.90)
        let shakeAmplitudeP90 = percentile(shakeYawSeries.map { abs($0) }, quantile: 0.90)
        let shakeVelocityP90 = percentile(shakeYawVelocity.map { abs($0) }, quantile: 0.90)

        let nodAmplitudeThreshold = clamp(max(deadzone * 2.0, nodAmplitudeP90 * 0.42, 0.09), min: 0.08, max: 0.24)
        let nodVelocityThreshold = clamp(max(0.38, nodVelocityP90 * 0.40), min: 0.38, max: 0.92)
        let shakeAmplitudeThreshold = clamp(max(deadzone * 2.2, shakeAmplitudeP90 * 0.44, 0.12), min: 0.10, max: 0.30)
        let shakeVelocityThreshold = clamp(max(0.50, shakeVelocityP90 * 0.40), min: 0.50, max: 1.10)

        let nodCrossLeakage = percentile(nodYawSeries.map { abs($0) }, quantile: 0.90) / max(0.000_1, nodAmplitudeP90)
        let shakeCrossLeakage = percentile(shakePitchSeries.map { abs($0) }, quantile: 0.90) / max(0.000_1, shakeAmplitudeP90)
        let nodCrossAxisLeakageMax = clamp(nodCrossLeakage * 1.40, min: 0.80, max: 1.20)
        let shakeCrossAxisLeakageMax = clamp(shakeCrossLeakage * 1.40, min: 0.80, max: 1.20)
        let nodMinCrossings = max(1, min(2, nodCrossings))
        let shakeMinCrossings = max(1, min(3, shakeCrossings))

        let computed = GestureThresholdProfile(
            version: GestureThresholdProfile.currentVersion,
            baselinePitch: baselinePitch,
            baselineYaw: baselineYaw,
            neutralDeadzone: deadzone,
            nodAmplitudeThreshold: nodAmplitudeThreshold,
            nodVelocityThreshold: nodVelocityThreshold,
            shakeAmplitudeThreshold: shakeAmplitudeThreshold,
            shakeVelocityThreshold: shakeVelocityThreshold,
            nodCrossAxisLeakageMax: nodCrossAxisLeakageMax,
            shakeCrossAxisLeakageMax: shakeCrossAxisLeakageMax,
            nodMinCrossings: nodMinCrossings,
            shakeMinCrossings: shakeMinCrossings,
            diagnosticSmoothing: 0.30,
            minConfidence: 0.50,
            cooldownSeconds: 0.80
        )
        return sanitizeProfile(computed)
    }

    private func velocities(from samples: [(timestamp: TimeInterval, value: Double)]) -> [Double] {
        guard samples.count > 1 else { return [] }
        var values: [Double] = []
        values.reserveCapacity(samples.count - 1)

        for index in 1..<samples.count {
            let prev = samples[index - 1]
            let next = samples[index]
            let dt = max(1.0 / 120.0, next.timestamp - prev.timestamp)
            values.append((next.value - prev.value) / dt)
        }

        return values
    }

    private func sanitizeProfile(_ profile: GestureThresholdProfile) -> GestureThresholdProfile {
        if profile == .fallback {
            return .fallback
        }

        return GestureThresholdProfile(
            version: GestureThresholdProfile.currentVersion,
            baselinePitch: profile.baselinePitch,
            baselineYaw: profile.baselineYaw,
            neutralDeadzone: clamp(profile.neutralDeadzone, min: 0.015, max: 0.09),
            nodAmplitudeThreshold: clamp(profile.nodAmplitudeThreshold, min: 0.08, max: 0.24),
            nodVelocityThreshold: clamp(profile.nodVelocityThreshold, min: 0.38, max: 0.92),
            shakeAmplitudeThreshold: clamp(profile.shakeAmplitudeThreshold, min: 0.10, max: 0.30),
            shakeVelocityThreshold: clamp(profile.shakeVelocityThreshold, min: 0.50, max: 1.10),
            nodCrossAxisLeakageMax: clamp(profile.nodCrossAxisLeakageMax, min: 0.80, max: 1.20),
            shakeCrossAxisLeakageMax: clamp(profile.shakeCrossAxisLeakageMax, min: 0.80, max: 1.20),
            nodMinCrossings: max(1, min(2, profile.nodMinCrossings)),
            shakeMinCrossings: max(1, min(3, profile.shakeMinCrossings)),
            diagnosticSmoothing: clamp(profile.diagnosticSmoothing, min: 0.22, max: 0.36),
            minConfidence: clamp(profile.minConfidence, min: 0.45, max: 0.60),
            cooldownSeconds: clamp(profile.cooldownSeconds, min: 0.70, max: 1.00)
        )
    }

    private func percentile(_ values: [Double], quantile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let q = max(0, min(1, quantile))
        let sorted = values.sorted()
        if sorted.count == 1 {
            return sorted[0]
        }
        let position = q * Double(sorted.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        if lowerIndex == upperIndex {
            return sorted[lowerIndex]
        }
        let interpolation = position - Double(lowerIndex)
        return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * interpolation
    }

    private func zeroCrossings(values: [Double], floor: Double) -> Int {
        guard values.count >= 2 else { return 0 }
        var count = 0
        var previousSign = sign(of: values[0], floor: floor)
        for value in values.dropFirst() {
            let sign = sign(of: value, floor: floor)
            if sign == 0 {
                continue
            }
            if previousSign != 0, sign != previousSign {
                count += 1
            }
            previousSign = sign
        }
        return count
    }

    private func sign(of value: Double, floor: Double) -> Int {
        if abs(value) < floor {
            return 0
        }
        return value > 0 ? 1 : -1
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}
