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

final class HeadphoneMotionMonitor: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var sample: HeadphoneMotionSample? = nil
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var isHeadphoneConnected: Bool = false
    @Published private(set) var authorizationStatus: CMAuthorizationStatus = .notDetermined
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private let manager = CMHeadphoneMotionManager()
    private let callbackDispatchQueue = DispatchQueue(label: "HeadBird.HeadphoneMotionQueue.dispatch")
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "HeadBird.HeadphoneMotionQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        queue.underlyingQueue = callbackDispatchQueue
        return queue
    }()
    private let stateLock = NSLock()
    nonisolated(unsafe) private var referenceAttitude: CMAttitude?
    nonisolated(unsafe) private var lastAttitude: CMAttitude?
    nonisolated(unsafe) private var lastPublishTimestamp: TimeInterval?
    nonisolated(unsafe) private var lastMotionSampleMonotonicTime: CFTimeInterval?
    private let publishInterval: TimeInterval = 1.0 / 60.0
    private let streamStaleTimeout: CFTimeInterval = 0.6
    private let failedStartRetryInterval: CFTimeInterval = 0.5
    private let streamWatchdogInterval: TimeInterval = 0.2
    private var streamWatchdog: Timer?
    private var lastFailedStartTime: CFTimeInterval?

    override init() {
        super.init()
        manager.delegate = self
        manager.startConnectionStatusUpdates()
        refreshStatus()
        startStreamWatchdogIfNeeded()
        startIfPossible()
    }

    func refreshStatus() {
        isAvailable = manager.isDeviceMotionAvailable
        authorizationStatus = CMHeadphoneMotionManager.authorizationStatus()
    }

    func startIfPossible() {
        let now = CFAbsoluteTimeGetCurrent()

        guard Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") != nil else {
            errorMessage = "Missing NSMotionUsageDescription in Info.plist"
            registerFailedStartAttempt(at: now)
            return
        }

        if !manager.isConnectionStatusActive {
            manager.startConnectionStatusUpdates()
        }
        startStreamWatchdogIfNeeded()
        refreshStatus()

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            errorMessage = "Motion access not authorized"
            registerFailedStartAttempt(at: now)
            return
        }

        let shouldPrimeAuthorization = authorizationStatus == .notDetermined && isHeadphoneConnected
        guard isAvailable || shouldPrimeAuthorization else {
            if manager.isDeviceMotionActive {
                manager.stopDeviceMotionUpdates()
            }
            isStreaming = false
            if authorizationStatus == .notDetermined {
                errorMessage = nil
                return
            }
            errorMessage = "Headphone motion is not available"
            registerFailedStartAttempt(at: now)
            return
        }
        if manager.isDeviceMotionActive {
            errorMessage = nil
            return
        }
        guard !isStartAttemptThrottled(at: now) else {
            return
        }

        let handler: @Sendable (CMDeviceMotion?, (any Error)?) -> Void = { [weak self] motion, error in
            guard let self else { return }
            self.handleMotionCallback(motion: motion, error: error)
        }
        errorMessage = nil
        manager.startDeviceMotionUpdates(to: queue, withHandler: handler)
        lastFailedStartTime = nil
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
        stopStreamWatchdog()
        resetMotionState()
        sample = nil
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
            Task { @MainActor [weak self] in
                self?.errorMessage = error.localizedDescription
                self?.isStreaming = false
                self?.registerFailedStartAttempt(at: CFAbsoluteTimeGetCurrent())
            }
            return
        }

        guard let motion else { return }

        let timestamp = motion.timestamp
        stateLock.lock()
        lastMotionSampleMonotonicTime = CFAbsoluteTimeGetCurrent()
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

        Task { @MainActor [weak self] in
            self?.authorizationStatus = authStatus
            self?.isHeadphoneConnected = true
            self?.sample = sample
            self?.isStreaming = true
            self?.errorMessage = nil
            self?.lastFailedStartTime = nil
        }
    }

    private func startStreamWatchdogIfNeeded() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startStreamWatchdogIfNeeded()
            }
            return
        }
        guard streamWatchdog == nil else { return }
        let timer = Timer(timeInterval: streamWatchdogInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateStreamStaleness()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        streamWatchdog = timer
    }

    private func stopStreamWatchdog() {
        if Thread.isMainThread {
            streamWatchdog?.invalidate()
            streamWatchdog = nil
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.stopStreamWatchdog()
        }
    }

    private func evaluateStreamStaleness() {
        guard isStreaming else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let isStale: Bool = stateLock.withLock {
            guard let lastMotionSampleMonotonicTime else { return true }
            return (now - lastMotionSampleMonotonicTime) > streamStaleTimeout
        }

        if isStale || !manager.isDeviceMotionActive {
            isStreaming = false
        }
    }

    private func registerFailedStartAttempt(at time: CFTimeInterval) {
        lastFailedStartTime = time
    }

    private func isStartAttemptThrottled(at now: CFTimeInterval) -> Bool {
        guard let lastFailedStartTime else { return false }
        return now - lastFailedStartTime < failedStartRetryInterval
    }

    private func resetMotionState() {
        stateLock.withLock {
            referenceAttitude = nil
            lastAttitude = nil
            lastPublishTimestamp = nil
            lastMotionSampleMonotonicTime = nil
        }
    }
}

extension HeadphoneMotionMonitor: CMHeadphoneMotionManagerDelegate {
    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isHeadphoneConnected = true
            self.refreshStatus()
            self.startIfPossible()
        }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshStatus()
            self.isHeadphoneConnected = false
            self.isStreaming = false
            self.sample = nil
            self.resetMotionState()
        }
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
