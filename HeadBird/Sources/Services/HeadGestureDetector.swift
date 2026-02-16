import Foundation

final class HeadGestureDetector {
    private struct ProcessedSample {
        let timestamp: TimeInterval
        let pitch: Double
        let yaw: Double
        let pitchVelocity: Double
        let yawVelocity: Double
    }

    var profile: GestureThresholdProfile {
        didSet {
            recentSamples.removeAll(keepingCapacity: true)
            lastPitch = nil
            lastYaw = nil
        }
    }

    var additionalCooldownSeconds: Double = 0

    private var recentSamples: [ProcessedSample] = []
    private var lastPitch: Double?
    private var lastYaw: Double?
    private var lastTimestamp: TimeInterval?
    private var lastDetectionTimestamp: TimeInterval?
    private let windowSeconds: Double = 0.9

    init(profile: GestureThresholdProfile) {
        self.profile = profile
    }

    func ingest(sample: HeadphoneMotionSample) -> HeadGestureEvent? {
        let timestamp = sample.timestamp
        let unwrappedPitch = unwrap(sample.pitch, previous: lastPitch)
        let unwrappedYaw = unwrap(sample.yaw, previous: lastYaw)
        let normalizedPitch = unwrappedPitch - profile.baselinePitch
        let normalizedYaw = unwrappedYaw - profile.baselineYaw

        let dt = max(0.000_1, (lastTimestamp.map { timestamp - $0 } ?? (1.0 / 60.0)))
        let pitchVelocity = (lastPitch.map { (normalizedPitch - ($0 - profile.baselinePitch)) / dt } ?? 0)
        let yawVelocity = (lastYaw.map { (normalizedYaw - ($0 - profile.baselineYaw)) / dt } ?? 0)

        lastPitch = unwrappedPitch
        lastYaw = unwrappedYaw
        lastTimestamp = timestamp

        recentSamples.append(
            ProcessedSample(
                timestamp: timestamp,
                pitch: normalizedPitch,
                yaw: normalizedYaw,
                pitchVelocity: pitchVelocity,
                yawVelocity: yawVelocity
            )
        )

        trimOldSamples(currentTimestamp: timestamp)

        let cooldown = profile.cooldownSeconds + max(0, additionalCooldownSeconds)
        if let lastDetectionTimestamp, timestamp - lastDetectionTimestamp < cooldown {
            return nil
        }

        let nodConfidence = detectNodConfidence()
        let shakeConfidence = detectShakeConfidence()

        guard nodConfidence >= profile.minConfidence || shakeConfidence >= profile.minConfidence else {
            return nil
        }

        let event: HeadGestureEvent
        if nodConfidence >= shakeConfidence {
            event = HeadGestureEvent(gesture: .nod, timestamp: timestamp, confidence: min(1, nodConfidence))
        } else {
            event = HeadGestureEvent(gesture: .shake, timestamp: timestamp, confidence: min(1, shakeConfidence))
        }

        lastDetectionTimestamp = timestamp
        recentSamples.removeAll(keepingCapacity: true)
        return event
    }

    func reset() {
        recentSamples.removeAll(keepingCapacity: true)
        lastPitch = nil
        lastYaw = nil
        lastTimestamp = nil
        lastDetectionTimestamp = nil
    }

    private func trimOldSamples(currentTimestamp: TimeInterval) {
        let cutoff = currentTimestamp - windowSeconds
        if let first = recentSamples.first, first.timestamp < cutoff {
            recentSamples.removeAll { $0.timestamp < cutoff }
        }
    }

    private func detectNodConfidence() -> Double {
        guard recentSamples.count >= 6 else { return 0 }

        let maxAbsPitch = recentSamples.map { abs($0.pitch) }.max() ?? 0
        let maxAbsYaw = recentSamples.map { abs($0.yaw) }.max() ?? 0
        let maxPitchVelocity = recentSamples.map { abs($0.pitchVelocity) }.max() ?? 0
        let pitchCrossings = zeroCrossings(values: recentSamples.map(\.pitchVelocity), floor: profile.nodVelocityThreshold * 0.35)

        guard maxAbsPitch >= profile.nodAmplitudeThreshold else { return 0 }
        guard maxPitchVelocity >= profile.nodVelocityThreshold else { return 0 }
        guard pitchCrossings >= 2 else { return 0 }

        // Reject sideways movement that dominates the signal.
        guard maxAbsYaw <= maxAbsPitch * 0.95 else { return 0 }

        let amplitudeScore = normalizedScore(maxAbsPitch, threshold: profile.nodAmplitudeThreshold)
        let velocityScore = normalizedScore(maxPitchVelocity, threshold: profile.nodVelocityThreshold)
        let crossingsScore = min(1, Double(pitchCrossings) / 3.0)
        return (amplitudeScore * 0.45) + (velocityScore * 0.4) + (crossingsScore * 0.15)
    }

    private func detectShakeConfidence() -> Double {
        guard recentSamples.count >= 6 else { return 0 }

        let maxAbsYaw = recentSamples.map { abs($0.yaw) }.max() ?? 0
        let maxAbsPitch = recentSamples.map { abs($0.pitch) }.max() ?? 0
        let maxYawVelocity = recentSamples.map { abs($0.yawVelocity) }.max() ?? 0
        let yawCrossings = zeroCrossings(values: recentSamples.map(\.yawVelocity), floor: profile.shakeVelocityThreshold * 0.35)

        guard maxAbsYaw >= profile.shakeAmplitudeThreshold else { return 0 }
        guard maxYawVelocity >= profile.shakeVelocityThreshold else { return 0 }
        guard yawCrossings >= 2 else { return 0 }

        // Reject vertical movement that dominates the signal.
        guard maxAbsPitch <= maxAbsYaw * 0.95 else { return 0 }

        let amplitudeScore = normalizedScore(maxAbsYaw, threshold: profile.shakeAmplitudeThreshold)
        let velocityScore = normalizedScore(maxYawVelocity, threshold: profile.shakeVelocityThreshold)
        let crossingsScore = min(1, Double(yawCrossings) / 3.0)
        return (amplitudeScore * 0.45) + (velocityScore * 0.4) + (crossingsScore * 0.15)
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

    private func normalizedScore(_ value: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 1 }
        return min(1, value / (threshold * 1.6))
    }

    private func unwrap(_ value: Double, previous: Double?) -> Double {
        guard let previous else { return value }

        var adjusted = value
        var delta = adjusted - previous

        while delta > .pi {
            adjusted -= (2 * .pi)
            delta = adjusted - previous
        }

        while delta < -.pi {
            adjusted += (2 * .pi)
            delta = adjusted - previous
        }

        return adjusted
    }
}
