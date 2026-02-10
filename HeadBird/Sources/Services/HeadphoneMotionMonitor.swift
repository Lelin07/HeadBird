import Combine
import CoreMotion
import Foundation

struct HeadphoneMotionSample {
    let timestamp: TimeInterval
    let pitch: Double
    let roll: Double
    let yaw: Double
    let rotationRate: CMRotationRate
    let gravity: CMAcceleration
    let userAcceleration: CMAcceleration
    let quaternion: CMQuaternion
}

final class HeadphoneMotionMonitor: ObservableObject, @unchecked Sendable {
    @Published private(set) var sample: HeadphoneMotionSample? = nil
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var authorizationStatus: CMAuthorizationStatus = .notDetermined
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "HeadBird.HeadphoneMotionQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let stateLock = NSLock()
    nonisolated(unsafe) private var referenceAttitude: CMAttitude?
    nonisolated(unsafe) private var lastAttitude: CMAttitude?
    nonisolated(unsafe) private var lastPublishTimestamp: TimeInterval?
    private let publishInterval: TimeInterval = 1.0 / 60.0

    init() {
        refreshStatus()
        startIfPossible()
    }

    func refreshStatus() {
        isAvailable = manager.isDeviceMotionAvailable
        authorizationStatus = CMHeadphoneMotionManager.authorizationStatus()
    }

    func startIfPossible() {
        errorMessage = nil

        guard Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") != nil else {
            errorMessage = "Missing NSMotionUsageDescription in Info.plist"
            return
        }

        if manager.isDeviceMotionActive {
            refreshStatus()
            return
        }

        refreshStatus()
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            errorMessage = "Motion access not authorized"
            return
        }
        guard isAvailable else {
            errorMessage = "Headphone motion is not available"
            return
        }

        let handler: @Sendable (CMDeviceMotion?, (any Error)?) -> Void = { [weak self] motion, error in
            guard let self else { return }
            self.handleMotionCallback(motion: motion, error: error)
        }
        manager.startDeviceMotionUpdates(to: queue, withHandler: handler)
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isStreaming = false
    }

    func recenter() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let lastAttitude else { return }
        referenceAttitude = (lastAttitude.copy() as? CMAttitude) ?? lastAttitude
    }

    nonisolated private func handleMotionCallback(motion: CMDeviceMotion?, error: (any Error)?) {
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = error.localizedDescription
                self?.isStreaming = false
            }
            return
        }

        guard let motion else { return }

        let timestamp = motion.timestamp
        stateLock.lock()
        if let lastPublishTimestamp, timestamp - lastPublishTimestamp < publishInterval {
            stateLock.unlock()
            return
        }
        lastPublishTimestamp = timestamp
        stateLock.unlock()

        let authStatus = CMHeadphoneMotionManager.authorizationStatus()

        let absoluteAttitude = (motion.attitude.copy() as? CMAttitude) ?? motion.attitude
        stateLock.lock()
        lastAttitude = absoluteAttitude
        stateLock.unlock()

        let attitude = (absoluteAttitude.copy() as? CMAttitude) ?? absoluteAttitude
        stateLock.lock()
        if let referenceAttitude {
            attitude.multiply(byInverseOf: referenceAttitude)
        } else {
            referenceAttitude = (absoluteAttitude.copy() as? CMAttitude) ?? absoluteAttitude
        }
        stateLock.unlock()

        let sample = HeadphoneMotionSample(
            timestamp: timestamp,
            pitch: attitude.pitch,
            roll: attitude.roll,
            yaw: attitude.yaw,
            rotationRate: motion.rotationRate,
            gravity: motion.gravity,
            userAcceleration: motion.userAcceleration,
            quaternion: attitude.quaternion
        )

        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = authStatus
            self?.sample = sample
            self?.isStreaming = true
        }
    }
}
