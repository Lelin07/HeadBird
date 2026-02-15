import Combine
import CoreBluetooth
import CoreMotion
import Foundation

enum MotionConnectionStatus: Equatable {
    case notConnected
    case waiting
    case connected
    case bluetoothPermissionRequired
    case motionPermissionRequired
    case motionUnavailable
}

@MainActor
final class HeadBirdModel: ObservableObject {
    @Published var defaultOutputName: String? = nil
    @Published var connectedAirPods: [String] = []
    @Published var motionSample: HeadphoneMotionSample? = nil
    @Published var motionPose: MotionPose = .zero
    @Published var motionHistory: [MotionHistorySample] = []
    @Published var motionAvailable: Bool = false
    @Published var motionAuthorization: CMAuthorizationStatus = .notDetermined
    @Published var bluetoothAuthorization: CBManagerAuthorization = CBCentralManager.authorization
    @Published var motionStreaming: Bool = false
    @Published var motionError: String? = nil
    @Published var motionSensitivity: Double = 1.0
    @Published private var motionHeadphoneConnected: Bool = false

    private let audioMonitor = AudioDeviceMonitor()
    private let bluetoothMonitor = BluetoothMonitor()
    private let motionMonitor = HeadphoneMotionMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var bluetoothTask: Task<Void, Never>?
    private let historyWindow: TimeInterval = 5.0
    private let smoothingTimeConstant: Double = 0.12
    private let historySampleInterval: TimeInterval = 1.0 / 30.0
    private let deadzoneDegrees: Double = 1.5
    private var lastMotionTimestamp: TimeInterval?
    private var lastHistoryTimestamp: TimeInterval?

    init() {
        audioMonitor.$defaultOutputName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outputName in
                guard let self else { return }
                self.defaultOutputName = outputName
                self.refreshBluetooth()
            }
            .store(in: &cancellables)

        audioMonitor.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBluetooth()
            }
            .store(in: &cancellables)

        audioMonitor.$defaultOutputDevice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBluetooth()
            }
            .store(in: &cancellables)

        motionMonitor.$sample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                guard let self else { return }
                self.motionSample = sample
                guard let sample else { return }
                let dt = self.deltaTime(current: sample.timestamp)
                let target = MotionPose(
                    pitch: self.applyDeadzone(sample.pitch),
                    roll: self.applyDeadzone(sample.roll),
                    yaw: self.applyDeadzone(sample.yaw)
                )
                let alpha = self.smoothingAlpha(for: dt)
                self.motionPose = self.motionPose.blending(toward: target, factor: alpha)
                self.appendHistoryIfNeeded(timestamp: sample.timestamp, pose: self.motionPose)
            }
            .store(in: &cancellables)

        motionMonitor.$isAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionAvailable)

        motionMonitor.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                let previousStatus = self.motionAuthorization
                self.motionAuthorization = status

                let becameAuthorizedWhileConnected =
                    self.hasAnyAirPodsConnection &&
                    previousStatus == .notDetermined &&
                    status != .notDetermined &&
                    status != .denied &&
                    status != .restricted
                if becameAuthorizedWhileConnected {
                    self.motionMonitor.startIfPossible()
                }
            }
            .store(in: &cancellables)

        motionMonitor.$isStreaming
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionStreaming)

        motionMonitor.$isHeadphoneConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionHeadphoneConnected)

        motionMonitor.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionError)

        bluetoothMonitor.onAuthorizationChanged = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.bluetoothAuthorization = status
                self?.refreshBluetooth()
            }
        }
        requestRequiredPermissions()

        startBluetoothPolling()
    }

    deinit {
        bluetoothTask?.cancel()
    }

    private var hasAnyAirPodsConnection: Bool {
        connectedAirPods.isEmpty == false || motionHeadphoneConnected
    }

    var activeAirPodsName: String? {
        HeadBirdModelLogic.activeAirPodsName(
            connectedAirPods: connectedAirPods,
            defaultOutputName: defaultOutputName,
            motionHeadphoneConnected: motionHeadphoneConnected
        )
    }

    var isActive: Bool {
        HeadBirdModelLogic.isActive(
            activeAirPodsName: activeAirPodsName,
            defaultOutputName: defaultOutputName
        )
    }

    var headState: HeadState {
        HeadBirdModelLogic.headState(
            hasAnyAirPodsConnection: hasAnyAirPodsConnection,
            isActive: isActive,
            motionStreaming: motionStreaming
        )
    }

    var motionConnectionStatus: MotionConnectionStatus {
        HeadBirdModelLogic.motionConnectionStatus(
            hasAnyAirPodsConnection: hasAnyAirPodsConnection,
            bluetoothAuthorization: bluetoothAuthorization,
            motionAuthorization: motionAuthorization,
            motionStreaming: motionStreaming,
            motionAvailable: motionAvailable
        )
    }

    var statusTitle: String {
        HeadBirdModelLogic.statusTitle(activeAirPodsName: activeAirPodsName)
    }

    var statusSubtitle: String {
        HeadBirdModelLogic.statusSubtitle(
            hasAnyAirPodsConnection: hasAnyAirPodsConnection,
            isActive: isActive
        )
    }

    func refreshNow() {
        audioMonitor.refresh()
        refreshBluetooth()
    }

    func recenterMotion() {
        motionMonitor.recenter()
        motionPose = .zero
        motionHistory.removeAll()
    }

    func requestRequiredPermissions() {
        bluetoothMonitor.requestAuthorizationIfNeeded()
        motionMonitor.startIfPossible()
    }

    private func startBluetoothPolling() {
        bluetoothTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.audioMonitor.refresh()
                self.refreshBluetooth()
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }

    @MainActor
    private func refreshBluetooth() {
        let hadConnectedAirPods = hasAnyAirPodsConnection
        var names = Set(bluetoothMonitor.connectedAirPods())

        if let defaultOutputDevice = audioMonitor.defaultOutputDevice {
            if defaultOutputDevice.isBluetooth || HeadBirdModelLogic.isAirPodsName(defaultOutputDevice.name) {
                names.insert(defaultOutputDevice.name)
            }
        } else if let defaultOutputName, HeadBirdModelLogic.isAirPodsName(defaultOutputName) {
            names.insert(defaultOutputName)
        }

        for device in audioMonitor.devices where device.isBluetooth || HeadBirdModelLogic.isAirPodsName(device.name) {
            names.insert(device.name)
        }

        connectedAirPods = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let hasConnectedAirPods = hasAnyAirPodsConnection

        if !hadConnectedAirPods && hasConnectedAirPods {
            requestRequiredPermissions()
        }

        let canRequestMotion = motionAuthorization != .denied && motionAuthorization != .restricted
        if hasConnectedAirPods && canRequestMotion {
            motionMonitor.startIfPossible()
        }
    }

    private func applyDeadzone(_ value: Double) -> Double {
        let deadzone = deadzoneDegrees * .pi / 180.0
        return abs(value) < deadzone ? 0 : value
    }

    private func appendHistoryIfNeeded(timestamp: TimeInterval, pose: MotionPose) {
        if let lastHistoryTimestamp, timestamp - lastHistoryTimestamp < historySampleInterval {
            return
        }
        lastHistoryTimestamp = timestamp
        motionHistory.append(MotionHistorySample(timestamp: timestamp, pose: pose))
        let cutoff = timestamp - historyWindow
        if let first = motionHistory.first, first.timestamp < cutoff {
            motionHistory.removeAll { $0.timestamp < cutoff }
        }
    }

    private func deltaTime(current: TimeInterval) -> TimeInterval {
        defer { lastMotionTimestamp = current }
        guard let lastMotionTimestamp else { return 1.0 / 60.0 }
        let dt = current - lastMotionTimestamp
        if dt <= 0 || dt > 0.5 {
            return 1.0 / 60.0
        }
        return dt
    }

    private func smoothingAlpha(for dt: TimeInterval) -> Double {
        let alpha = 1.0 - exp(-dt / smoothingTimeConstant)
        return max(0.05, min(0.6, alpha))
    }
}
