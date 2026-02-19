import CoreMotion
import XCTest
@testable import HeadBird

@MainActor
final class HeadGestureDetectorTests: XCTestCase {
    func testDetectsNodFromPitchOscillation() async {
        await MainActor.run {
            let profile = Self.balancedProfile()
            let detector = HeadGestureDetector(profile: profile)

            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<90 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.22 * sin(t * 12)
                let yaw = 0.04 * sin(t * 5)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertEqual(detected?.gesture, .nod)
            XCTAssertNotNil(detected)
        }
    }

    func testDetectsShakeFromYawOscillation() async {
        await MainActor.run {
            let profile = Self.balancedProfile()
            let detector = HeadGestureDetector(profile: profile)

            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<90 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.03 * sin(t * 4)
                let yaw = 0.25 * sin(t * 12)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertEqual(detected?.gesture, .shake)
            XCTAssertNotNil(detected)
        }
    }

    func testRejectsSlowDriftNoise() async {
        await MainActor.run {
            let detector = HeadGestureDetector(profile: .fallback)

            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<240 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.02 * sin(t * 0.8)
                let yaw = 0.025 * sin(t * 0.7)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertNil(detected)
        }
    }

    func testFallbackProfileDetectsModerateNodMovement() async {
        await MainActor.run {
            let detector = HeadGestureDetector(profile: .fallback)
            var detected: HeadGestureEvent?

            let dt: Double = 1.0 / 60.0
            for index in 0..<180 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.18 * sin(t * 11)
                let yaw = 0.04 * sin(t * 4)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertEqual(detected?.gesture, .nod)
            XCTAssertNotNil(detected)
        }
    }

    func testFallbackProfileDetectsModerateShakeMovement() async {
        await MainActor.run {
            let detector = HeadGestureDetector(profile: .fallback)
            var detected: HeadGestureEvent?

            let dt: Double = 1.0 / 60.0
            for index in 0..<180 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.04 * sin(t * 4)
                let yaw = 0.19 * sin(t * 11)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertEqual(detected?.gesture, .shake)
            XCTAssertNotNil(detected)
        }
    }

    func testSinglePulseNodTriggersEvenWithTwoCrossingProfile() async {
        await MainActor.run {
            var profile = Self.balancedProfile()
            profile = GestureThresholdProfile(
                version: profile.version,
                baselinePitch: profile.baselinePitch,
                baselineYaw: profile.baselineYaw,
                neutralDeadzone: profile.neutralDeadzone,
                nodAmplitudeThreshold: profile.nodAmplitudeThreshold,
                nodVelocityThreshold: profile.nodVelocityThreshold,
                shakeAmplitudeThreshold: profile.shakeAmplitudeThreshold,
                shakeVelocityThreshold: profile.shakeVelocityThreshold,
                nodCrossAxisLeakageMax: profile.nodCrossAxisLeakageMax,
                shakeCrossAxisLeakageMax: profile.shakeCrossAxisLeakageMax,
                nodMinCrossings: 2,
                shakeMinCrossings: profile.shakeMinCrossings,
                diagnosticSmoothing: profile.diagnosticSmoothing,
                minConfidence: profile.minConfidence,
                cooldownSeconds: profile.cooldownSeconds
            )
            let detector = HeadGestureDetector(profile: profile)
            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0

            for index in 0..<120 where detected == nil {
                let t = Double(index) * dt
                let normalized = (t - 0.45) / 0.16
                let pitch = 0.24 * exp(-(normalized * normalized))
                let yaw = 0.025 * sin(t * 5)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                detected = result.event
            }

            XCTAssertEqual(detected?.gesture, .nod)
        }
    }

    func testRejectsCrossAxisDominantMotion() async {
        await MainActor.run {
            var profile = Self.balancedProfile()
            profile = GestureThresholdProfile(
                version: profile.version,
                baselinePitch: profile.baselinePitch,
                baselineYaw: profile.baselineYaw,
                neutralDeadzone: profile.neutralDeadzone,
                nodAmplitudeThreshold: profile.nodAmplitudeThreshold,
                nodVelocityThreshold: profile.nodVelocityThreshold,
                shakeAmplitudeThreshold: profile.shakeAmplitudeThreshold,
                shakeVelocityThreshold: profile.shakeVelocityThreshold,
                nodCrossAxisLeakageMax: 0.65,
                shakeCrossAxisLeakageMax: 0.65,
                nodMinCrossings: profile.nodMinCrossings,
                shakeMinCrossings: profile.shakeMinCrossings,
                diagnosticSmoothing: profile.diagnosticSmoothing,
                minConfidence: profile.minConfidence,
                cooldownSeconds: profile.cooldownSeconds
            )
            let detector = HeadGestureDetector(profile: profile)
            var nodDetected = false

            let dt: Double = 1.0 / 60.0
            for index in 0..<120 where !nodDetected {
                let t = Double(index) * dt
                let pitch = 0.11 * sin(t * 9)
                let yaw = 0.26 * sin(t * 10)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                if result.event?.gesture == .nod {
                    nodDetected = true
                }
            }

            XCTAssertFalse(nodDetected)
        }
    }

    func testHysteresisRequiresConsecutiveFramesBeforeEvent() async {
        await MainActor.run {
            let detector = HeadGestureDetector(profile: Self.balancedProfile())
            var sawCandidateWithoutEvent = false
            var detected: HeadGestureEvent?

            let dt: Double = 1.0 / 60.0
            for index in 0..<120 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.23 * sin(t * 11)
                let yaw = 0.03 * sin(t * 4)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                if result.candidateGesture != nil, result.event == nil {
                    sawCandidateWithoutEvent = true
                }
                detected = result.event
            }

            XCTAssertTrue(sawCandidateWithoutEvent)
            XCTAssertEqual(detected?.gesture, .nod)
        }
    }

    func testSoftCrossAxisPenaltyAllowsModerateLeakageConfidence() async {
        await MainActor.run {
            var profile = Self.balancedProfile()
            profile = GestureThresholdProfile(
                version: profile.version,
                baselinePitch: profile.baselinePitch,
                baselineYaw: profile.baselineYaw,
                neutralDeadzone: profile.neutralDeadzone,
                nodAmplitudeThreshold: profile.nodAmplitudeThreshold,
                nodVelocityThreshold: profile.nodVelocityThreshold,
                shakeAmplitudeThreshold: profile.shakeAmplitudeThreshold,
                shakeVelocityThreshold: profile.shakeVelocityThreshold,
                nodCrossAxisLeakageMax: 0.75,
                shakeCrossAxisLeakageMax: profile.shakeCrossAxisLeakageMax,
                nodMinCrossings: profile.nodMinCrossings,
                shakeMinCrossings: profile.shakeMinCrossings,
                diagnosticSmoothing: profile.diagnosticSmoothing,
                minConfidence: 0.70,
                cooldownSeconds: profile.cooldownSeconds
            )

            let detector = HeadGestureDetector(profile: profile)
            var maxRawNod: Double = 0
            let dt: Double = 1.0 / 60.0

            for index in 0..<120 {
                let t = Double(index) * dt
                let pitch = 0.20 * sin(t * 11)
                let yaw = 0.16 * sin(t * 10)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                maxRawNod = max(maxRawNod, result.rawNodConfidence)
            }

            XCTAssertGreaterThan(maxRawNod, 0.05)
        }
    }

    func testRawConfidenceCanExceedThresholdBeforeSmoothedEvent() async {
        await MainActor.run {
            var profile = Self.balancedProfile()
            profile = GestureThresholdProfile(
                version: profile.version,
                baselinePitch: profile.baselinePitch,
                baselineYaw: profile.baselineYaw,
                neutralDeadzone: profile.neutralDeadzone,
                nodAmplitudeThreshold: profile.nodAmplitudeThreshold,
                nodVelocityThreshold: profile.nodVelocityThreshold,
                shakeAmplitudeThreshold: profile.shakeAmplitudeThreshold,
                shakeVelocityThreshold: profile.shakeVelocityThreshold,
                nodCrossAxisLeakageMax: profile.nodCrossAxisLeakageMax,
                shakeCrossAxisLeakageMax: profile.shakeCrossAxisLeakageMax,
                nodMinCrossings: profile.nodMinCrossings,
                shakeMinCrossings: profile.shakeMinCrossings,
                diagnosticSmoothing: 0.12,
                minConfidence: 0.50,
                cooldownSeconds: profile.cooldownSeconds
            )
            let detector = HeadGestureDetector(profile: profile)

            var sawRawAboveThresholdBeforeEvent = false
            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<140 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.23 * sin(t * 12)
                let yaw = 0.03 * sin(t * 3)
                let result = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
                if result.rawNodConfidence >= profile.minConfidence, result.event == nil {
                    sawRawAboveThresholdBeforeEvent = true
                }
                detected = result.event
            }

            XCTAssertTrue(sawRawAboveThresholdBeforeEvent)
            XCTAssertEqual(detected?.gesture, .nod)
        }
    }

    func testAppliesCooldownGate() async {
        await MainActor.run {
            let profile = GestureThresholdProfile(
                version: GestureThresholdProfile.currentVersion,
                baselinePitch: 0,
                baselineYaw: 0,
                neutralDeadzone: 0.02,
                nodAmplitudeThreshold: 0.1,
                nodVelocityThreshold: 0.45,
                shakeAmplitudeThreshold: 0.1,
                shakeVelocityThreshold: 0.45,
                nodCrossAxisLeakageMax: 0.9,
                shakeCrossAxisLeakageMax: 0.9,
                nodMinCrossings: 2,
                shakeMinCrossings: 2,
                diagnosticSmoothing: 0.24,
                minConfidence: 0.4,
                cooldownSeconds: 0.8
            )

            let detector = HeadGestureDetector(profile: profile)

            let firstBurst = Self.syntheticNodBurst(startTime: 0)
            let secondBurst = Self.syntheticNodBurst(startTime: 0.25)
            let thirdBurst = Self.syntheticNodBurst(startTime: 1.4)

            let first = (firstBurst + secondBurst).compactMap { detector.ingest(sample: $0).event }
            XCTAssertEqual(first.count, 1)

            let second = thirdBurst.compactMap { detector.ingest(sample: $0).event }
            XCTAssertEqual(second.count, 1)
        }
    }

    private static func balancedProfile() -> GestureThresholdProfile {
        GestureThresholdProfile(
            version: GestureThresholdProfile.currentVersion,
            baselinePitch: 0,
            baselineYaw: 0,
            neutralDeadzone: 0.02,
            nodAmplitudeThreshold: 0.1,
            nodVelocityThreshold: 0.45,
            shakeAmplitudeThreshold: 0.12,
            shakeVelocityThreshold: 0.55,
            nodCrossAxisLeakageMax: 0.85,
            shakeCrossAxisLeakageMax: 0.85,
            nodMinCrossings: 2,
            shakeMinCrossings: 2,
            diagnosticSmoothing: 0.24,
            minConfidence: 0.45,
            cooldownSeconds: 0.2
        )
    }

    private static func syntheticNodBurst(startTime: TimeInterval) -> [HeadphoneMotionSample] {
        var samples: [HeadphoneMotionSample] = []
        let dt: Double = 1.0 / 60.0
        for index in 0..<36 {
            let t = startTime + (Double(index) * dt)
            let pitch = 0.24 * sin(Double(index) * 0.32)
            samples.append(makeSample(timestamp: t, pitch: pitch, yaw: 0.02))
        }
        return samples
    }

    private static func makeSample(timestamp: TimeInterval, pitch: Double, yaw: Double) -> HeadphoneMotionSample {
        HeadphoneMotionSample(
            timestamp: timestamp,
            pitch: pitch,
            roll: 0,
            yaw: yaw,
            sensorLocation: .default,
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0),
            gravity: CMAcceleration(x: 0, y: -1, z: 0),
            userAcceleration: CMAcceleration(x: 0, y: 0, z: 0),
            quaternion: CMQuaternion(x: 0, y: 0, z: 0, w: 1)
        )
    }
}
