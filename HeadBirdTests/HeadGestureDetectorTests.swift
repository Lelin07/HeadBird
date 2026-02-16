import CoreMotion
import XCTest
@testable import HeadBird

final class HeadGestureDetectorTests: XCTestCase {
    func testDetectsNodFromPitchOscillation() async {
        await MainActor.run {
            let profile = GestureThresholdProfile(
                version: GestureThresholdProfile.currentVersion,
                baselinePitch: 0,
                baselineYaw: 0,
                neutralDeadzone: 0.02,
                nodAmplitudeThreshold: 0.1,
                nodVelocityThreshold: 0.45,
                shakeAmplitudeThreshold: 0.18,
                shakeVelocityThreshold: 0.7,
                minConfidence: 0.45,
                cooldownSeconds: 0.2
            )
            let detector = HeadGestureDetector(profile: profile)

            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<90 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.22 * sin(t * 12)
                let yaw = 0.04 * sin(t * 5)
                detected = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
            }

            XCTAssertEqual(detected?.gesture, .nod)
            XCTAssertNotNil(detected)
        }
    }

    func testDetectsShakeFromYawOscillation() async {
        await MainActor.run {
            let profile = GestureThresholdProfile(
                version: GestureThresholdProfile.currentVersion,
                baselinePitch: 0,
                baselineYaw: 0,
                neutralDeadzone: 0.02,
                nodAmplitudeThreshold: 0.12,
                nodVelocityThreshold: 0.55,
                shakeAmplitudeThreshold: 0.12,
                shakeVelocityThreshold: 0.55,
                minConfidence: 0.45,
                cooldownSeconds: 0.2
            )
            let detector = HeadGestureDetector(profile: profile)

            var detected: HeadGestureEvent?
            let dt: Double = 1.0 / 60.0
            for index in 0..<90 where detected == nil {
                let t = Double(index) * dt
                let pitch = 0.03 * sin(t * 4)
                let yaw = 0.25 * sin(t * 12)
                detected = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
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
                detected = detector.ingest(sample: Self.makeSample(timestamp: t, pitch: pitch, yaw: yaw))
            }

            XCTAssertNil(detected)
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
                minConfidence: 0.4,
                cooldownSeconds: 0.8
            )

            let detector = HeadGestureDetector(profile: profile)

            let firstBurst = Self.syntheticNodBurst(startTime: 0)
            let secondBurst = Self.syntheticNodBurst(startTime: 0.4)
            let thirdBurst = Self.syntheticNodBurst(startTime: 1.4)

            let first = (firstBurst + secondBurst).compactMap { detector.ingest(sample: $0) }
            XCTAssertEqual(first.count, 1)

            let second = thirdBurst.compactMap { detector.ingest(sample: $0) }
            XCTAssertEqual(second.count, 1)
        }
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
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0),
            gravity: CMAcceleration(x: 0, y: -1, z: 0),
            userAcceleration: CMAcceleration(x: 0, y: 0, z: 0),
            quaternion: CMQuaternion(x: 0, y: 0, z: 0, w: 1)
        )
    }
}
