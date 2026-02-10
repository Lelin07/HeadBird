import Foundation

struct MotionPose: Equatable {
    var pitch: Double
    var roll: Double
    var yaw: Double

    static let zero = MotionPose(pitch: 0, roll: 0, yaw: 0)

    func blending(toward target: MotionPose, factor: Double) -> MotionPose {
        let f = max(0.0, min(1.0, factor))
        return MotionPose(
            pitch: pitch + (target.pitch - pitch) * f,
            roll: roll + (target.roll - roll) * f,
            yaw: yaw + (target.yaw - yaw) * f
        )
    }

    func scaled(by factor: Double) -> MotionPose {
        MotionPose(
            pitch: pitch * factor,
            roll: roll * factor,
            yaw: yaw * factor
        )
    }
}

struct MotionHistorySample: Equatable {
    let timestamp: TimeInterval
    let pose: MotionPose
}
