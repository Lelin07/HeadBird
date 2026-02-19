import CoreMotion
import XCTest
@testable import HeadBird

final class GestureCalibrationServiceTests: XCTestCase {
    func testComputesAndPersistsProfileAfterThreeStages() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "HeadBirdTests.Calibration.\(UUID().uuidString)")!
            let key = "HeadBirdTests.Profile.\(UUID().uuidString)"

            let service = GestureCalibrationService(defaults: defaults, profileKey: key, captureDuration: 0.2)

            service.startCalibration()
            service.beginCaptureForCurrentStage()
            Self.ingestStage(service, start: 0, end: 0.24) { _ in (0.002, -0.001) }

            XCTAssertEqual(service.state.stage, .nod)

            service.beginCaptureForCurrentStage()
            Self.ingestStage(service, start: 1.0, end: 1.28) { t in
                let x = sin(t * 20)
                return (0.24 * x, 0.02)
            }

            XCTAssertEqual(service.state.stage, .shake)

            service.beginCaptureForCurrentStage()
            Self.ingestStage(service, start: 2.0, end: 2.28) { t in
                let x = sin(t * 20)
                return (0.02, 0.3 * x)
            }

            XCTAssertEqual(service.state.stage, .completed)
            XCTAssertTrue(service.state.hasProfile)
            XCTAssertNotEqual(service.profile, .fallback)
            XCTAssertGreaterThan(service.profile.nodCrossAxisLeakageMax, 0)
            XCTAssertGreaterThan(service.profile.shakeCrossAxisLeakageMax, 0)
            XCTAssertGreaterThan(service.profile.nodMinCrossings, 0)
            XCTAssertGreaterThan(service.profile.shakeMinCrossings, 0)

            let reloaded = GestureCalibrationService(defaults: defaults, profileKey: key, captureDuration: 0.2)
            XCTAssertEqual(reloaded.state.stage, .completed)
            XCTAssertEqual(reloaded.profile, service.profile)
        }
    }

    func testFallsBackWhenCapturedDataIsInsufficient() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "HeadBirdTests.Calibration.Fallback.\(UUID().uuidString)")!
            let service = GestureCalibrationService(
                defaults: defaults,
                profileKey: "HeadBirdTests.Fallback.\(UUID().uuidString)",
                captureDuration: 0.05
            )

            service.startCalibration()
            service.beginCaptureForCurrentStage()
            Self.ingestSparseStage(service, start: 0)

            service.beginCaptureForCurrentStage()
            Self.ingestSparseStage(service, start: 1)

            service.beginCaptureForCurrentStage()
            Self.ingestSparseStage(service, start: 2)

            XCTAssertEqual(service.state.stage, .completed)
            XCTAssertEqual(service.profile, .fallback)
        }
    }

    func testDeletesLegacyProfileAndRequiresRecalibration() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "HeadBirdTests.Calibration.Migration.\(UUID().uuidString)")!
            let legacyKey = "HeadBirdTests.Legacy.\(UUID().uuidString)"
            let v2Key = "HeadBirdTests.ProfileV2.\(UUID().uuidString)"

            let legacyProfile = GestureThresholdProfile(
                version: 1,
                baselinePitch: 0,
                baselineYaw: 0,
                neutralDeadzone: 0.03,
                nodAmplitudeThreshold: 0.14,
                nodVelocityThreshold: 0.56,
                shakeAmplitudeThreshold: 0.18,
                shakeVelocityThreshold: 0.72,
                nodCrossAxisLeakageMax: 0.9,
                shakeCrossAxisLeakageMax: 0.9,
                nodMinCrossings: 2,
                shakeMinCrossings: 2,
                diagnosticSmoothing: 0.24,
                minConfidence: 0.55,
                cooldownSeconds: 0.9
            )
            defaults.set(try? JSONEncoder().encode(legacyProfile), forKey: legacyKey)

            let service = GestureCalibrationService(
                defaults: defaults,
                profileKey: v2Key,
                legacyProfileKey: legacyKey,
                captureDuration: 0.2
            )

            XCTAssertNil(defaults.data(forKey: legacyKey))
            XCTAssertEqual(service.state, .initial)
            XCTAssertEqual(service.profile, .fallback)
            XCTAssertTrue(service.isUsingFallbackProfile)
        }
    }

    func testSanitizesPersistedProfileWhenThresholdsAreOverlyStrict() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "HeadBirdTests.Calibration.Sanitize.\(UUID().uuidString)")!
            let key = "HeadBirdTests.Profile.Sanitize.\(UUID().uuidString)"
            let strictProfile = GestureThresholdProfile(
                version: GestureThresholdProfile.currentVersion,
                baselinePitch: 0.2,
                baselineYaw: -0.2,
                neutralDeadzone: 0.2,
                nodAmplitudeThreshold: 0.5,
                nodVelocityThreshold: 1.8,
                shakeAmplitudeThreshold: 0.5,
                shakeVelocityThreshold: 1.8,
                nodCrossAxisLeakageMax: 0.4,
                shakeCrossAxisLeakageMax: 0.4,
                nodMinCrossings: 6,
                shakeMinCrossings: 6,
                diagnosticSmoothing: 0.1,
                minConfidence: 0.8,
                cooldownSeconds: 1.8
            )
            defaults.set(try? JSONEncoder().encode(strictProfile), forKey: key)

            let service = GestureCalibrationService(defaults: defaults, profileKey: key)

            XCTAssertEqual(service.profile.neutralDeadzone, 0.09, accuracy: 0.0001)
            XCTAssertEqual(service.profile.nodAmplitudeThreshold, 0.24, accuracy: 0.0001)
            XCTAssertEqual(service.profile.nodVelocityThreshold, 0.92, accuracy: 0.0001)
            XCTAssertEqual(service.profile.shakeAmplitudeThreshold, 0.30, accuracy: 0.0001)
            XCTAssertEqual(service.profile.shakeVelocityThreshold, 1.10, accuracy: 0.0001)
            XCTAssertEqual(service.profile.nodCrossAxisLeakageMax, 0.80, accuracy: 0.0001)
            XCTAssertEqual(service.profile.shakeCrossAxisLeakageMax, 0.80, accuracy: 0.0001)
            XCTAssertEqual(service.profile.nodMinCrossings, 2)
            XCTAssertEqual(service.profile.shakeMinCrossings, 3)
            XCTAssertEqual(service.profile.diagnosticSmoothing, 0.22, accuracy: 0.0001)
            XCTAssertEqual(service.profile.minConfidence, 0.60, accuracy: 0.0001)
            XCTAssertEqual(service.profile.cooldownSeconds, 1.00, accuracy: 0.0001)
        }
    }

    @MainActor
    private static func ingestStage(
        _ service: GestureCalibrationService,
        start: TimeInterval,
        end: TimeInterval,
        values: (TimeInterval) -> (pitch: Double, yaw: Double)
    ) {
        let dt = 1.0 / 60.0
        var t = start
        while t <= end {
            let value = values(t)
            service.ingest(sample: makeSample(timestamp: t, pitch: value.pitch, yaw: value.yaw))
            t += dt
        }
    }

    @MainActor
    private static func ingestSparseStage(_ service: GestureCalibrationService, start: TimeInterval) {
        service.ingest(sample: makeSample(timestamp: start + 0.01, pitch: 0.01, yaw: 0.01))
        service.ingest(sample: makeSample(timestamp: start + 0.07, pitch: 0.015, yaw: 0.015))
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
