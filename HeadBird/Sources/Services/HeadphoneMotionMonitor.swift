import Combine
import CoreMotion
import Foundation

struct HeadphoneMotionSample {
    let timestamp: TimeInterval
    let pitch: Double
    let roll: Double
    let yaw: Double
    let sensorLocation: CMDeviceMotion.SensorLocation
    let rotationRate: CMRotationRate
    let gravity: CMAcceleration
    let userAcceleration: CMAcceleration
    let quaternion: CMQuaternion
}

final class HeadphoneMotionMonitor: NSObject, ObservableObject, @unchecked Sendable {
    private struct PendingMainPublish {
        let sample: HeadphoneMotionSample
        let authorizationStatus: CMAuthorizationStatus
    }

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
    nonisolated(unsafe) private var lastSensorLocation: CMDeviceMotion.SensorLocation?
    nonisolated(unsafe) private var lastMotionSampleMonotonicTime: CFTimeInterval?
    nonisolated(unsafe) private var lastPublishTimestamp: TimeInterval?
    nonisolated(unsafe) private var publishInterval: TimeInterval = 1.0 / 45.0
    nonisolated(unsafe) private var pendingMainPublish: PendingMainPublish?
    nonisolated(unsafe) private var isMainPublishScheduled: Bool = false
    private let streamStaleTimeout: CFTimeInterval = 0.6
    private let failedStartRetryInterval: CFTimeInterval = 0.5
    private let streamWatchdogInterval: TimeInterval = 0.2
    private var streamWatchdog: Timer?
    private var lastFailedStartTime: CFTimeInterval?
    private var streamingEnabled: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.startConnectionStatusUpdates()
        refreshStatus()
    }

    func refreshStatus() {
        let available = manager.isDeviceMotionAvailable
        if isAvailable != available {
            isAvailable = available
        }

        let auth = CMHeadphoneMotionManager.authorizationStatus()
        if authorizationStatus != auth {
            authorizationStatus = auth
        }
    }

    func startIfPossible() {
        let now = CFAbsoluteTimeGetCurrent()

        guard Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") != nil else {
            let message = "Missing NSMotionUsageDescription in Info.plist"
            if errorMessage != message {
                errorMessage = message
            }
            registerFailedStartAttempt(at: now)
            return
        }

        guard streamingEnabled else {
            if manager.isDeviceMotionActive {
                manager.stopDeviceMotionUpdates()
            }
            if isStreaming {
                isStreaming = false
            }
            return
        }

        if !manager.isConnectionStatusActive {
            manager.startConnectionStatusUpdates()
        }
        startStreamWatchdogIfNeeded()
        refreshStatus()

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            let message = "Motion access not authorized"
            if errorMessage != message {
                errorMessage = message
            }
            registerFailedStartAttempt(at: now)
            return
        }

        let shouldPrimeAuthorization = authorizationStatus == .notDetermined && isHeadphoneConnected
        guard isAvailable || shouldPrimeAuthorization else {
            if manager.isDeviceMotionActive {
                manager.stopDeviceMotionUpdates()
            }
            if isStreaming {
                isStreaming = false
            }
            if authorizationStatus == .notDetermined {
                if errorMessage != nil {
                    errorMessage = nil
                }
                return
            }
            let message = "Headphone motion is not available"
            if errorMessage != message {
                errorMessage = message
            }
            registerFailedStartAttempt(at: now)
            return
        }
        if manager.isDeviceMotionActive {
            if errorMessage != nil {
                errorMessage = nil
            }
            return
        }
        guard !isStartAttemptThrottled(at: now) else {
            return
        }

        let handler: @Sendable (CMDeviceMotion?, (any Error)?) -> Void = { [weak self] motion, error in
            guard let self else { return }
            self.handleMotionCallback(motion: motion, error: error)
        }
        if errorMessage != nil {
            errorMessage = nil
        }
        manager.startDeviceMotionUpdates(to: queue, withHandler: handler)
        lastFailedStartTime = nil
    }

    func stop() {
        streamingEnabled = false
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
        stopStreamWatchdog()
        resetMotionState()
        sample = nil
        if isStreaming {
            isStreaming = false
        }
    }

    func setStreamingEnabled(_ enabled: Bool) {
        if streamingEnabled == enabled {
            if enabled && !manager.isDeviceMotionActive {
                startIfPossible()
            }
            return
        }

        streamingEnabled = enabled

        if enabled {
            if !manager.isConnectionStatusActive {
                manager.startConnectionStatusUpdates()
            }
            startStreamWatchdogIfNeeded()
            startIfPossible()
            return
        }

        manager.stopDeviceMotionUpdates()
        stopStreamWatchdog()
        if isStreaming {
            isStreaming = false
        }
    }

    func setPreferredSampleRate(_ hertz: Double) {
        let clampedHertz = max(15.0, min(60.0, hertz))
        let interval = 1.0 / clampedHertz
        stateLock.withLock {
            if abs(publishInterval - interval) < 0.000_1 {
                return
            }
            publishInterval = interval
            lastPublishTimestamp = nil
        }
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
                guard let self else { return }
                let message = error.localizedDescription
                if self.errorMessage != message {
                    self.errorMessage = message
                }
                if self.isStreaming {
                    self.isStreaming = false
                }
                self.registerFailedStartAttempt(at: CFAbsoluteTimeGetCurrent())
            }
            return
        }

        guard let motion else { return }

        let timestamp = motion.timestamp
        stateLock.lock()
        lastMotionSampleMonotonicTime = CFAbsoluteTimeGetCurrent()
        if let lastPublishTimestamp,
           timestamp - lastPublishTimestamp < publishInterval {
            stateLock.unlock()
            return
        }
        lastPublishTimestamp = timestamp
        stateLock.unlock()

        let authStatus = CMHeadphoneMotionManager.authorizationStatus()

        let sensorLocation = motion.sensorLocation
        let absoluteAttitude = (motion.attitude.copy() as? CMAttitude) ?? motion.attitude
        stateLock.lock()
        if let lastSensorLocation, lastSensorLocation != sensorLocation {
            // Re-anchor when Core Motion switches the streaming earbud sensor.
            referenceAttitude = (absoluteAttitude.copy() as? CMAttitude) ?? absoluteAttitude
        }
        lastSensorLocation = sensorLocation
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
            sensorLocation: sensorLocation,
            rotationRate: motion.rotationRate,
            gravity: motion.gravity,
            userAcceleration: motion.userAcceleration,
            quaternion: attitude.quaternion
        )

        enqueueMainPublish(sample: sample, authorizationStatus: authStatus)
    }

    nonisolated private func enqueueMainPublish(sample: HeadphoneMotionSample, authorizationStatus: CMAuthorizationStatus) {
        stateLock.lock()
        pendingMainPublish = PendingMainPublish(sample: sample, authorizationStatus: authorizationStatus)
        let shouldSchedule = !isMainPublishScheduled
        if shouldSchedule {
            isMainPublishScheduled = true
        }
        stateLock.unlock()

        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingMainPublish()
        }
    }

    private func flushPendingMainPublish() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.flushPendingMainPublish()
            }
            return
        }

        let pending: PendingMainPublish? = stateLock.withLock {
            let value = pendingMainPublish
            pendingMainPublish = nil
            isMainPublishScheduled = false
            return value
        }

        guard let pending else { return }
        if authorizationStatus != pending.authorizationStatus {
            authorizationStatus = pending.authorizationStatus
        }
        if !isHeadphoneConnected {
            isHeadphoneConnected = true
        }
        sample = pending.sample
        if !isStreaming {
            isStreaming = true
        }
        if errorMessage != nil {
            errorMessage = nil
        }
        lastFailedStartTime = nil
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
            lastSensorLocation = nil
            lastMotionSampleMonotonicTime = nil
            lastPublishTimestamp = nil
            pendingMainPublish = nil
            isMainPublishScheduled = false
        }
    }
}

extension HeadphoneMotionMonitor: CMHeadphoneMotionManagerDelegate {
    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isHeadphoneConnected = true
            self.refreshStatus()
            if self.streamingEnabled {
                self.startIfPossible()
            }
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
