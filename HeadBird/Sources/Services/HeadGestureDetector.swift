import Foundation
import CoreMotion

final class HeadGestureDetector {
    private struct ProcessedSample {
        let timestamp: TimeInterval
        let pitch: Double
        let yaw: Double
        let pitchVelocity: Double
        let yawVelocity: Double
        let pitchRate: Double
        let yawRate: Double
    }

    var profile: GestureThresholdProfile {
        didSet {
            reset()
        }
    }

    var additionalCooldownSeconds: Double = 0

    private var recentSamples: [ProcessedSample] = []
    private var lastPitch: Double?
    private var lastYaw: Double?
    private var lastTimestamp: TimeInterval?
    private var lastDetectionTimestamp: TimeInterval?
    private var smoothedNodConfidence: Double = 0
    private var smoothedShakeConfidence: Double = 0
    private var candidateStreakGesture: HeadGesture?
    private var candidateStreakCount: Int = 0
    private let windowSeconds: Double = 0.9
    private let hysteresisFrames: Int = 2

    init(profile: GestureThresholdProfile) {
        self.profile = profile
    }

    func ingest(sample: HeadphoneMotionSample) -> GestureDetectionResult {
        let timestamp = sample.timestamp
        let unwrappedPitch = unwrap(sample.pitch, previous: lastPitch)
        let unwrappedYaw = unwrap(sample.yaw, previous: lastYaw)
        let normalizedPitch = unwrappedPitch - profile.baselinePitch
        let normalizedYaw = unwrappedYaw - profile.baselineYaw

        let dt = max(0.000_1, (lastTimestamp.map { timestamp - $0 } ?? (1.0 / 60.0)))
        let pitchVelocity = (lastPitch.map { (normalizedPitch - ($0 - profile.baselinePitch)) / dt } ?? 0)
        let yawVelocity = (lastYaw.map { (normalizedYaw - ($0 - profile.baselineYaw)) / dt } ?? 0)
        let pitchRate = abs(sample.rotationRate.x)
        let yawRate = abs(sample.rotationRate.y)

        lastPitch = unwrappedPitch
        lastYaw = unwrappedYaw
        lastTimestamp = timestamp

        recentSamples.append(
            ProcessedSample(
                timestamp: timestamp,
                pitch: normalizedPitch,
                yaw: normalizedYaw,
                pitchVelocity: pitchVelocity,
                yawVelocity: yawVelocity,
                pitchRate: pitchRate,
                yawRate: yawRate
            )
        )

        trimOldSamples(currentTimestamp: timestamp)

        let rawNodConfidence = detectNodConfidence()
        let rawShakeConfidence = detectShakeConfidence()

        let alpha = max(0, min(1, profile.diagnosticSmoothing))
        smoothedNodConfidence = smooth(previous: smoothedNodConfidence, sample: rawNodConfidence, alpha: alpha)
        smoothedShakeConfidence = smooth(previous: smoothedShakeConfidence, sample: rawShakeConfidence, alpha: alpha)

        let candidateGesture: HeadGesture?
        if max(smoothedNodConfidence, smoothedShakeConfidence) >= profile.minConfidence {
            candidateGesture = smoothedNodConfidence >= smoothedShakeConfidence ? .nod : .shake
        } else {
            candidateGesture = nil
        }

        if candidateGesture == candidateStreakGesture {
            candidateStreakCount += 1
        } else {
            candidateStreakGesture = candidateGesture
            candidateStreakCount = candidateGesture == nil ? 0 : 1
        }

        var event: HeadGestureEvent?
        if let candidateGesture,
           candidateStreakCount >= hysteresisFrames,
           !isInCooldown(timestamp: timestamp) {
            let confidence = candidateGesture == .nod ? smoothedNodConfidence : smoothedShakeConfidence
            event = HeadGestureEvent(
                gesture: candidateGesture,
                timestamp: timestamp,
                confidence: min(1, confidence)
            )
            lastDetectionTimestamp = timestamp
            recentSamples.removeAll(keepingCapacity: true)
            candidateStreakGesture = nil
            candidateStreakCount = 0
        }

        return GestureDetectionResult(
            rawNodConfidence: rawNodConfidence,
            rawShakeConfidence: rawShakeConfidence,
            nodConfidence: smoothedNodConfidence,
            shakeConfidence: smoothedShakeConfidence,
            candidateGesture: candidateGesture,
            event: event
        )
    }

    func reset() {
        recentSamples.removeAll(keepingCapacity: true)
        lastPitch = nil
        lastYaw = nil
        lastTimestamp = nil
        lastDetectionTimestamp = nil
        smoothedNodConfidence = 0
        smoothedShakeConfidence = 0
        candidateStreakGesture = nil
        candidateStreakCount = 0
    }

    private func trimOldSamples(currentTimestamp: TimeInterval) {
        let cutoff = currentTimestamp - windowSeconds
        if let first = recentSamples.first, first.timestamp < cutoff {
            recentSamples.removeAll { $0.timestamp < cutoff }
        }
    }

    private func detectNodConfidence() -> Double {
        guard recentSamples.count >= 8 else { return 0 }

        let absPitch = recentSamples.map { abs($0.pitch) }
        let absYaw = recentSamples.map { abs($0.yaw) }
        let absPitchVelocity = recentSamples.map { abs($0.pitchVelocity) }
        let absPitchRate = recentSamples.map { $0.pitchRate }
        let p90Pitch = percentile(absPitch, quantile: 0.90)
        let p90Yaw = percentile(absYaw, quantile: 0.90)
        let p95PitchVelocity = percentile(absPitchVelocity, quantile: 0.95)
        let p90PitchRate = percentile(absPitchRate, quantile: 0.90)
        let pitchCrossings = zeroCrossings(
            values: recentSamples.map(\.pitchVelocity),
            floor: min(profile.nodVelocityThreshold * 0.30, 0.22)
        )
        let nodMinCrossings = max(1, profile.nodMinCrossings)
        let nodRequiredCrossings = max(1, nodMinCrossings - 1)

        guard p90Pitch >= profile.nodAmplitudeThreshold else { return 0 }
        guard p95PitchVelocity >= profile.nodVelocityThreshold else { return 0 }
        guard pitchCrossings >= nodRequiredCrossings else { return 0 }

        let crossAxisLeakage = p90Yaw / max(0.000_1, p90Pitch)
        let crossAxisPenalty = crossAxisPenalty(
            leakage: crossAxisLeakage,
            leakageMax: profile.nodCrossAxisLeakageMax
        )
        guard crossAxisPenalty > 0 else { return 0 }

        let amplitudeScore = normalizedScore(p90Pitch, threshold: profile.nodAmplitudeThreshold)
        let velocityScore = normalizedScore(p95PitchVelocity, threshold: profile.nodVelocityThreshold)
        let rhythmScore = min(1, Double(pitchCrossings) / Double(nodMinCrossings))
        let dynamicScore = normalizedScore(p90PitchRate, threshold: profile.nodVelocityThreshold * 0.8)
        let baseScore = (amplitudeScore * 0.38) + (velocityScore * 0.34) + (rhythmScore * 0.16) + (dynamicScore * 0.12)
        return baseScore * crossAxisPenalty
    }

    private func detectShakeConfidence() -> Double {
        guard recentSamples.count >= 8 else { return 0 }

        let absYaw = recentSamples.map { abs($0.yaw) }
        let absPitch = recentSamples.map { abs($0.pitch) }
        let absYawVelocity = recentSamples.map { abs($0.yawVelocity) }
        let absYawRate = recentSamples.map { $0.yawRate }
        let p90Yaw = percentile(absYaw, quantile: 0.90)
        let p90Pitch = percentile(absPitch, quantile: 0.90)
        let p95YawVelocity = percentile(absYawVelocity, quantile: 0.95)
        let p90YawRate = percentile(absYawRate, quantile: 0.90)
        let yawCrossings = zeroCrossings(
            values: recentSamples.map(\.yawVelocity),
            floor: profile.shakeVelocityThreshold * 0.30
        )
        let shakeMinCrossings = max(1, profile.shakeMinCrossings)

        guard p90Yaw >= profile.shakeAmplitudeThreshold else { return 0 }
        guard p95YawVelocity >= profile.shakeVelocityThreshold else { return 0 }
        guard yawCrossings >= shakeMinCrossings else { return 0 }

        let crossAxisLeakage = p90Pitch / max(0.000_1, p90Yaw)
        let crossAxisPenalty = crossAxisPenalty(
            leakage: crossAxisLeakage,
            leakageMax: profile.shakeCrossAxisLeakageMax
        )
        guard crossAxisPenalty > 0 else { return 0 }

        let amplitudeScore = normalizedScore(p90Yaw, threshold: profile.shakeAmplitudeThreshold)
        let velocityScore = normalizedScore(p95YawVelocity, threshold: profile.shakeVelocityThreshold)
        let rhythmScore = min(1, Double(yawCrossings) / Double(shakeMinCrossings + 1))
        let dynamicScore = normalizedScore(p90YawRate, threshold: profile.shakeVelocityThreshold * 0.8)
        let baseScore = (amplitudeScore * 0.38) + (velocityScore * 0.34) + (rhythmScore * 0.16) + (dynamicScore * 0.12)
        return baseScore * crossAxisPenalty
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

    private func isInCooldown(timestamp: TimeInterval) -> Bool {
        let cooldown = profile.cooldownSeconds + max(0, additionalCooldownSeconds)
        guard let lastDetectionTimestamp else { return false }
        return timestamp - lastDetectionTimestamp < cooldown
    }

    private func smooth(previous: Double, sample: Double, alpha: Double) -> Double {
        let clampedAlpha = max(0, min(1, alpha))
        return previous + (sample - previous) * clampedAlpha
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

    private func normalizedScore(_ value: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 1 }
        return min(1, value / (threshold * 1.55))
    }

    private func crossAxisPenalty(leakage: Double, leakageMax: Double) -> Double {
        guard leakageMax > 0 else { return 0 }
        let ratio = leakage / leakageMax
        if ratio <= 1 {
            return 1
        }
        if ratio > 1.8 {
            return 0
        }
        return max(0, 1 - ((ratio - 1.0) / 0.8))
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
