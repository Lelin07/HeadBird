import XCTest
@testable import HeadBird

@MainActor
final class MotionPoseTests: XCTestCase {
    func testZeroIsAllZeroes() {
        XCTAssertEqual(MotionPose.zero, MotionPose(pitch: 0, roll: 0, yaw: 0))
    }

    func testBlendingClampsFactorBelowZero() {
        let start = MotionPose(pitch: 1, roll: -2, yaw: 3)
        let target = MotionPose(pitch: 10, roll: 10, yaw: 10)

        XCTAssertEqual(start.blending(toward: target, factor: -0.5), start)
    }

    func testBlendingClampsFactorAboveOne() {
        let start = MotionPose(pitch: 1, roll: -2, yaw: 3)
        let target = MotionPose(pitch: 10, roll: 10, yaw: 10)

        XCTAssertEqual(start.blending(toward: target, factor: 1.5), target)
    }

    func testBlendingInterpolatesAtMidpoint() {
        let start = MotionPose(pitch: 2, roll: -4, yaw: 6)
        let target = MotionPose(pitch: 10, roll: 8, yaw: -2)

        let result = start.blending(toward: target, factor: 0.25)

        XCTAssertEqual(result.pitch, 4, accuracy: 0.000_001)
        XCTAssertEqual(result.roll, -1, accuracy: 0.000_001)
        XCTAssertEqual(result.yaw, 4, accuracy: 0.000_001)
    }

    func testScaledScalesAllAxes() {
        let pose = MotionPose(pitch: 2, roll: -3, yaw: 4)

        XCTAssertEqual(pose.scaled(by: 0), MotionPose(pitch: 0, roll: 0, yaw: 0))
        XCTAssertEqual(pose.scaled(by: 2), MotionPose(pitch: 4, roll: -6, yaw: 8))
        XCTAssertEqual(pose.scaled(by: -0.5), MotionPose(pitch: -1, roll: 1.5, yaw: -2))
    }
}
