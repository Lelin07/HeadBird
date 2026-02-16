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
            rotationRate: CMRotationRate(x: 0, y: 0, z: 0),
            gravity: CMAcceleration(x: 0, y: -1, z: 0),
            userAcceleration: CMAcceleration(x: 0, y: 0, z: 0),
            quaternion: CMQuaternion(x: 0, y: 0, z: 0, w: 1)
        )
    }
}
