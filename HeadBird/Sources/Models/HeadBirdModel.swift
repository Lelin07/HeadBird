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
    @Published private(set) var motionHeadphoneConnected: Bool = false
    @Published private(set) var isGraphPlaying: Bool = false
    @Published private(set) var isPopoverPresented: Bool = false

    @Published var gestureControlEnabled: Bool = false {
        didSet {
            if gestureControlEnabled && !gestureCalibrationState.hasProfile {
                gestureControlEnabled = false
                guard !isRestoringGestureSettings else { return }
                setFeedback("Complete calibration or use fallback before enabling control mode.")
                return
            }
            if !gestureControlEnabled && gestureTesterEnabled {
                gestureTesterEnabled = false
            }
            reevaluateMotionDemand()
            guard !isRestoringGestureSettings else { return }
            defaults.set(gestureControlEnabled, forKey: DefaultsKey.gestureControlEnabled)
        }
    }
    @Published var gestureTesterEnabled: Bool = false {
        didSet {
            if gestureTesterEnabled && !gestureControlEnabled {
                gestureTesterEnabled = false
                return
            }
            reevaluateMotionDemand()
            if !gestureTesterEnabled {
                clearGestureDiagnostics()
            }
        }
    }

    @Published var lastGestureEvent: HeadGestureEvent? = nil
    @Published private(set) var lastGestureActionResult: String? = nil
    @Published private(set) var lastGestureActionTimestamp: Date? = nil
    @Published var gestureCalibrationState: GestureCalibrationState = .initial
    @Published private(set) var gestureDiagnostics: GestureDiagnostics = .empty
    @Published private(set) var gestureActionMode: GestureActionMode = .promptResponses

    @Published var gestureFeedbackMessage: String? = nil
    @Published var accessibilityTrusted: Bool = false
    @Published private(set) var promptTargetCapabilities: PromptTargetCapabilities = .none
    @Published var usesFallbackGestureProfile: Bool = true

    private let defaults: UserDefaults
    private let audioMonitor = AudioDeviceMonitor()
    private let bluetoothMonitor = BluetoothMonitor()
    private let motionMonitor = HeadphoneMotionMonitor()
    private let calibrationService: GestureCalibrationService
    private let gestureDetector: HeadGestureDetector
    private let promptActionExecutor: PromptActionExecutor
    private let actionRouter: GestureActionRouter

    private var cancellables = Set<AnyCancellable>()
    private var bluetoothTask: Task<Void, Never>?
    private var promptTargetPollingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    private let historyWindow: TimeInterval = 5.0
    private let smoothingTimeConstant: Double = 0.08
    private let historySampleInterval: TimeInterval = 1.0 / 60.0
    private let gestureProcessingInterval: TimeInterval = 1.0 / 40.0
    private let deadzoneDegrees: Double = 1.5
    private let diagnosticsConfidenceDeltaThreshold: Double = 0.01
    private let diagnosticsSampleRateDeltaThreshold: Double = 0.5

    private var lastMotionTimestamp: TimeInterval?
    private var lastHistoryTimestamp: TimeInterval?
    private var lastGestureProcessingTimestamp: TimeInterval?
    private var lastGestureDiagnosticsTimestamp: TimeInterval?
    private var lastSampleSensorLocation: CMDeviceMotion.SensorLocation?
    private var isRestoringGestureSettings: Bool = false
    private var isPopoverVisible: Bool = false
    private var activePopoverTab: PopoverTab = .motion

    private enum DefaultsKey {
        static let gestureControlEnabled = "HeadBird.GestureControlEnabled"
        static let pendingCalibrationStart = "HeadBird.PendingCalibrationStart"
        static let promptOnlyMigrationCompleted = "HeadBird.PromptOnlyMigrationCompleted"
    }

    private enum LegacyDefaultsKey {
        static let nodMappedAction = "HeadBird.NodMappedAction"
        static let shakeMappedAction = "HeadBird.ShakeMappedAction"
        static let nodShortcutName = "HeadBird.NodShortcutName"
        static let shakeShortcutName = "HeadBird.ShakeShortcutName"
        static let gestureCooldownSeconds = "HeadBird.GestureCooldownSeconds"
        static let doubleConfirmEnabled = "HeadBird.DoubleConfirmEnabled"

        static let all: [String] = [
            nodMappedAction,
            shakeMappedAction,
            nodShortcutName,
            shakeShortcutName,
            gestureCooldownSeconds,
            doubleConfirmEnabled
        ]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.sanitizeLegacyGestureSettingsIfNeeded(defaults: defaults)

        let calibrationService = GestureCalibrationService(defaults: defaults)
        self.calibrationService = calibrationService
        self.gestureDetector = HeadGestureDetector(profile: calibrationService.profile)
        self.promptActionExecutor = PromptActionExecutor()
        self.actionRouter = GestureActionRouter(
            promptExecutor: promptActionExecutor
        )

        loadGestureSettings()
        bindSources()

        requestRequiredPermissions()
        refreshGesturePermissions(promptForAccessibility: false)
        startBluetoothPolling()
    }

    deinit {
        bluetoothTask?.cancel()
        promptTargetPollingTask?.cancel()
        feedbackTask?.cancel()
    }

    var hasAnyAirPodsConnection: Bool {
        HeadBirdModelLogic.hasAnyAirPodsConnection(
            connectedAirPods: connectedAirPods,
            motionHeadphoneConnected: motionHeadphoneConnected
        )
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

    var canUseGestureControls: Bool {
        motionStreaming && gestureCalibrationState.hasProfile
    }

    var canExecuteGestureActions: Bool {
        HeadBirdModelLogic.shouldExecuteGestureActions(
            gestureControlEnabled: gestureControlEnabled,
            hasGestureProfile: gestureCalibrationState.hasProfile
        )
    }

    var isGestureTesterActive: Bool {
        isGestureTesterEnabled && motionStreaming
    }

    func refreshNow() {
        audioMonitor.refresh()
        refreshBluetooth()
    }

    func setPopoverVisible(_ isVisible: Bool, activeTab: PopoverTab) {
        let wasVisible = isPopoverVisible
        let previousTab = activePopoverTab

        isPopoverVisible = isVisible
        isPopoverPresented = isVisible
        activePopoverTab = activeTab

        if isVisible && (!wasVisible || previousTab != activeTab) {
            handleTabTransition(from: previousTab, to: activeTab)
        }

        refreshPromptTargetCapabilities()
        reevaluateMotionDemand()
    }

    func setPopoverVisibility(_ isVisible: Bool) {
        setPopoverVisible(isVisible, activeTab: activePopoverTab)
    }

    func setActiveTab(_ tab: PopoverTab) {
        let previousTab = activePopoverTab
        activePopoverTab = tab

        if isPopoverVisible && previousTab != tab {
            handleTabTransition(from: previousTab, to: tab)
        }

        refreshPromptTargetCapabilities()
        reevaluateMotionDemand()
    }

    func setGraphPlaying(_ isPlaying: Bool) {
        guard isGraphPlaying != isPlaying else { return }
        isGraphPlaying = isPlaying
        reevaluateMotionDemand()
    }

    func toggleGraphPlaying() {
        setGraphPlaying(!isGraphPlaying)
    }

    func recenterMotion(showFeedback: Bool = true) {
        motionMonitor.recenter()
        motionPose = .zero
        motionHistory.removeAll()
        lastMotionTimestamp = nil
        lastHistoryTimestamp = nil
        lastGestureProcessingTimestamp = nil
        lastSampleSensorLocation = nil
        if showFeedback {
            setFeedback("Set zero complete.")
        }
    }

    func requestRequiredPermissions() {
        bluetoothMonitor.requestAuthorizationIfNeeded()
        motionMonitor.refreshStatus()
        reevaluateMotionDemand()
    }

    func startGestureCalibration() {
        calibrationService.startCalibration()
        setFeedback("Calibration started.")
    }

    func beginCalibrationCapture() {
        calibrationService.beginCaptureForCurrentStage()
    }

    func skipCalibrationWithFallbackProfile() {
        calibrationService.skipCalibrationAndUseFallback()
        setFeedback("Using fallback calibration profile.")
    }

    func clearCalibrationProfile() {
        calibrationService.clearCalibrationProfile()
        gestureControlEnabled = false
        setFeedback("Calibration profile cleared.")
    }

    func requestAccessibilityPermissionPrompt() {
        _ = promptActionExecutor.isAccessibilityTrusted(prompt: true)
        refreshGesturePermissions(promptForAccessibility: false)
    }

    func refreshGesturePermissions(promptForAccessibility: Bool) {
        accessibilityTrusted = promptActionExecutor.isAccessibilityTrusted(prompt: promptForAccessibility)
        refreshPromptTargetCapabilities()
    }

    func toggleControlMode() {
        gestureControlEnabled.toggle()
        let message = gestureControlEnabled ? "Control mode enabled." : "Control mode disabled."
        setFeedback(message)
    }

    private func bindSources() {
        audioMonitor.$defaultOutputName
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outputName in
                guard let self else { return }
                self.defaultOutputName = outputName
                self.refreshBluetooth()
            }
            .store(in: &cancellables)

        audioMonitor.$devices
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBluetooth()
            }
            .store(in: &cancellables)

        audioMonitor.$defaultOutputDevice
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBluetooth()
            }
            .store(in: &cancellables)

        motionMonitor.$sample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                guard let self else { return }
                guard let sample else { return }

                if self.shouldPublishVisualMotionUpdates {
                    self.motionSample = sample

                    if let lastSampleSensorLocation,
                       lastSampleSensorLocation != sample.sensorLocation {
                        self.lastMotionTimestamp = nil
                    }
                    self.lastSampleSensorLocation = sample.sensorLocation

                    let historyPose = MotionPose(
                        pitch: sample.pitch,
                        roll: sample.roll,
                        yaw: sample.yaw
                    )
                    let dt = self.deltaTime(current: sample.timestamp)
                    let target = MotionPose(
                        pitch: self.applyDeadzone(sample.pitch),
                        roll: self.applyDeadzone(sample.roll),
                        yaw: self.applyDeadzone(sample.yaw)
                    )
                    let alpha = self.smoothingAlpha(for: dt)
                    self.motionPose = self.blendPose(current: self.motionPose, target: target, factor: alpha)
                    self.appendHistoryIfNeeded(timestamp: sample.timestamp, pose: historyPose)
                }

                if self.gestureCalibrationState.isCapturing {
                    self.calibrationService.ingest(sample: sample)
                }
                if self.shouldProcessGestureSample(timestamp: sample.timestamp) {
                    self.processGesture(sample: sample)
                }
            }
            .store(in: &cancellables)

        motionMonitor.$isAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionAvailable)

        motionMonitor.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                guard self.motionAuthorization != status else { return }
                self.motionAuthorization = status
                self.reevaluateMotionDemand()
            }
            .store(in: &cancellables)

        motionMonitor.$isStreaming
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionStreaming)

        motionMonitor.$isHeadphoneConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self else { return }
                guard self.motionHeadphoneConnected != isConnected else { return }
                self.motionHeadphoneConnected = isConnected
                self.reevaluateMotionDemand()
            }
            .store(in: &cancellables)

        motionMonitor.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$motionError)

        bluetoothMonitor.onAuthorizationChanged = { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.bluetoothAuthorization != status else { return }
                self.bluetoothAuthorization = status
                self.refreshBluetooth()
            }
        }

        calibrationService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.gestureCalibrationState = state
                if !state.hasProfile {
                    self.gestureControlEnabled = false
                }
                self.refreshPromptTargetCapabilities()
                self.reevaluateMotionDemand()
            }
            .store(in: &cancellables)

        calibrationService.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self else { return }
                self.gestureDetector.profile = profile
            }
            .store(in: &cancellables)

        calibrationService.$isUsingFallbackProfile
            .receive(on: DispatchQueue.main)
            .assign(to: &$usesFallbackGestureProfile)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.synchronizeGestureSettingsFromDefaults()
            }
            .store(in: &cancellables)
    }

    private func processGesture(sample: HeadphoneMotionSample) {
        let detection = gestureDetector.ingest(sample: sample)
        updateGestureDiagnostics(with: detection, timestamp: sample.timestamp)

        guard let event = detection.event else {
            return
        }

        lastGestureEvent = event

        guard canExecuteGestureActions else {
            return
        }

        let decision = promptDecision(for: event.gesture)
        guard promptTargetCapabilities.supports(decision) else {
            return
        }

        let result = actionRouter.route(
            event: event,
            mode: gestureActionMode
        )

        if case .ignored = result {
            return
        }
        lastGestureActionResult = "\(event.gesture.title): \(result.message)"
        lastGestureActionTimestamp = Date()
        setFeedback("\(event.gesture.title) \(Int(event.confidence * 100))%: \(result.message)")
        refreshGesturePermissions(promptForAccessibility: false)
    }

    private func shouldProcessGestureSample(timestamp: TimeInterval) -> Bool {
        let shouldAnalyze = HeadBirdModelLogic.shouldAnalyzeGestures(
            motionStreaming: motionStreaming,
            isGestureTesterActive: isGestureTesterActive,
            gestureControlEnabled: gestureControlEnabled,
            hasGestureProfile: gestureCalibrationState.hasProfile,
            hasPromptTarget: promptTargetCapabilities.hasAnyTarget
        )
        guard shouldAnalyze else {
            lastGestureProcessingTimestamp = nil
            clearGestureDiagnostics()
            return false
        }
        if let lastGestureProcessingTimestamp,
           timestamp - lastGestureProcessingTimestamp < gestureProcessingInterval {
            return false
        }
        lastGestureProcessingTimestamp = timestamp
        return true
    }

    private func updateGestureDiagnostics(with result: GestureDetectionResult, timestamp: TimeInterval) {
        guard gestureTesterEnabled else {
            clearGestureDiagnostics()
            return
        }
        let sampleRateHertz: Double
        if let lastGestureDiagnosticsTimestamp {
            let dt = timestamp - lastGestureDiagnosticsTimestamp
            if dt > 0 {
                let instantaneousHertz = min(120, max(0, 1.0 / dt))
                sampleRateHertz = gestureDiagnostics.sampleRateHertz == 0
                    ? instantaneousHertz
                    : (gestureDiagnostics.sampleRateHertz * 0.78) + (instantaneousHertz * 0.22)
            } else {
                sampleRateHertz = gestureDiagnostics.sampleRateHertz
            }
        } else {
            sampleRateHertz = 0
        }
        lastGestureDiagnosticsTimestamp = timestamp
        let diagnostics = GestureDiagnostics(
            rawNodConfidence: result.rawNodConfidence,
            rawShakeConfidence: result.rawShakeConfidence,
            nodConfidence: result.nodConfidence,
            shakeConfidence: result.shakeConfidence,
            triggerThreshold: gestureDetector.profile.minConfidence,
            sampleRateHertz: sampleRateHertz,
            candidateGesture: result.candidateGesture,
            lastUpdatedTimestamp: timestamp
        )

        if shouldPublishGestureDiagnostics(diagnostics, eventDetected: result.event != nil) {
            gestureDiagnostics = diagnostics
        }
    }

    private func shouldPublishGestureDiagnostics(_ next: GestureDiagnostics, eventDetected: Bool) -> Bool {
        if eventDetected {
            return true
        }
        let current = gestureDiagnostics
        if current == .empty {
            return next.sampleRateHertz > 0 || next.candidateGesture != nil
        }
        if abs(next.rawNodConfidence - current.rawNodConfidence) >= diagnosticsConfidenceDeltaThreshold {
            return true
        }
        if abs(next.rawShakeConfidence - current.rawShakeConfidence) >= diagnosticsConfidenceDeltaThreshold {
            return true
        }
        if abs(next.sampleRateHertz - current.sampleRateHertz) >= diagnosticsSampleRateDeltaThreshold {
            return true
        }
        if next.candidateGesture != current.candidateGesture {
            return true
        }
        if abs(next.triggerThreshold - current.triggerThreshold) >= 0.001 {
            return true
        }
        return false
    }

    private func clearGestureDiagnostics() {
        if gestureDiagnostics == .empty {
            return
        }
        lastGestureDiagnosticsTimestamp = nil
        gestureDiagnostics = .empty
    }

    private func startBluetoothPolling() {
        bluetoothTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.audioMonitor.refresh()
                self.refreshBluetooth()
                let pollInterval: TimeInterval
                if self.isPopoverVisible || self.shouldStreamMotion {
                    pollInterval = 1.5
                } else if self.hasAnyAirPodsConnection {
                    pollInterval = 3.0
                } else {
                    pollInterval = 6.0
                }
                try? await Task.sleep(for: .seconds(pollInterval))
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

        let sortedNames = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if connectedAirPods != sortedNames {
            connectedAirPods = sortedNames
        }

        let hasConnectedAirPods = !sortedNames.isEmpty || motionHeadphoneConnected

        if !hadConnectedAirPods && hasConnectedAirPods {
            requestRequiredPermissions()
        }

        if hadConnectedAirPods != hasConnectedAirPods {
            reevaluateMotionDemand()
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
        if activePopoverTab == .motion && isGraphPlaying {
            return max(0.55, min(0.98, alpha))
        }
        return max(0.12, min(0.85, alpha))
    }

    private func blendPose(current: MotionPose, target: MotionPose, factor: Double) -> MotionPose {
        let f = max(0.0, min(1.0, factor))
        return MotionPose(
            pitch: current.pitch + (target.pitch - current.pitch) * f,
            roll: blendAngle(current: current.roll, target: target.roll, factor: f),
            yaw: blendAngle(current: current.yaw, target: target.yaw, factor: f)
        )
    }

    private func blendAngle(current: Double, target: Double, factor: Double) -> Double {
        let delta = atan2(sin(target - current), cos(target - current))
        return current + delta * factor
    }

    private var shouldStreamMotion: Bool {
        HeadBirdModelLogic.shouldStreamMotion(
            hasAnyAirPodsConnection: hasAnyAirPodsConnection,
            motionAuthorization: motionAuthorization,
            isPopoverVisible: isPopoverVisible,
            activeTab: activePopoverTab,
            isGestureTesterEnabled: isGestureTesterEnabled,
            isGraphPlaying: isGraphPlaying,
            gestureControlEnabled: gestureControlEnabled,
            hasGestureProfile: gestureCalibrationState.hasProfile,
            hasPromptTarget: promptTargetCapabilities.hasAnyTarget,
            isCalibrationCapturing: gestureCalibrationState.isCapturing
        )
    }

    private var shouldPublishVisualMotionUpdates: Bool {
        HeadBirdModelLogic.shouldPublishVisualMotionUpdates(
            isPopoverVisible: isPopoverVisible,
            activeTab: activePopoverTab,
            isGraphPlaying: isGraphPlaying
        )
    }

    private var isGestureTesterVisible: Bool {
        isPopoverVisible && activePopoverTab == .controls
    }

    private var isGestureTesterEnabled: Bool {
        isGestureTesterVisible && gestureTesterEnabled
    }

    private var preferredMotionSampleRate: Double {
        if shouldPublishVisualMotionUpdates {
            return 45
        }
        if isGestureTesterEnabled {
            return 30
        }
        if gestureCalibrationState.isCapturing {
            return 40
        }
        if gestureControlEnabled && gestureCalibrationState.hasProfile {
            if !isPopoverVisible {
                return 20
            }
            return 30
        }
        return 20
    }

    private func reevaluateMotionDemand() {
        updatePromptTargetPolling()
        motionMonitor.setPreferredSampleRate(preferredMotionSampleRate)
        motionMonitor.setStreamingEnabled(shouldStreamMotion)
    }

    private func updatePromptTargetPolling() {
        let shouldPoll = canExecuteGestureActions
        if shouldPoll {
            if promptTargetPollingTask == nil {
                refreshPromptTargetCapabilities()
                promptTargetPollingTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    while !Task.isCancelled {
                        self.refreshPromptTargetCapabilities()
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                }
            }
            return
        }

        promptTargetPollingTask?.cancel()
        promptTargetPollingTask = nil
        if promptTargetCapabilities != .none {
            promptTargetCapabilities = .none
        }
    }

    private func refreshPromptTargetCapabilities() {
        let capabilities: PromptTargetCapabilities
        if canExecuteGestureActions {
            capabilities = promptActionExecutor.currentPromptTargetCapabilities()
        } else {
            capabilities = .none
        }

        guard promptTargetCapabilities != capabilities else { return }
        promptTargetCapabilities = capabilities
        motionMonitor.setStreamingEnabled(shouldStreamMotion)
    }

    private func promptDecision(for gesture: HeadGesture) -> PromptDecision {
        gesture == .nod ? .accept : .reject
    }

    private func handleTabTransition(from previous: PopoverTab, to next: PopoverTab) {
        if previous == .motion && next != .motion {
            isGraphPlaying = false
            return
        }

        if next == .motion {
            // Motion graph always starts paused until user explicitly taps Play.
            isGraphPlaying = false
        }
    }

    private func loadGestureSettings() {
        isRestoringGestureSettings = true

        gestureControlEnabled = defaults.bool(forKey: DefaultsKey.gestureControlEnabled)
        gestureActionMode = .promptResponses
        gestureCalibrationState = calibrationService.state
        usesFallbackGestureProfile = calibrationService.isUsingFallbackProfile
        if !gestureCalibrationState.hasProfile {
            gestureControlEnabled = false
        }
        refreshPromptTargetCapabilities()
        isRestoringGestureSettings = false
    }

    private func synchronizeGestureSettingsFromDefaults() {
        if defaults.bool(forKey: DefaultsKey.pendingCalibrationStart) {
            defaults.set(false, forKey: DefaultsKey.pendingCalibrationStart)
            startGestureCalibration()
            return
        }

        guard !isRestoringGestureSettings else { return }
        isRestoringGestureSettings = true

        let defaultControlMode = defaults.bool(forKey: DefaultsKey.gestureControlEnabled)
        if gestureControlEnabled != defaultControlMode {
            gestureControlEnabled = defaultControlMode
        }
        if !gestureCalibrationState.hasProfile, gestureControlEnabled {
            gestureControlEnabled = false
        }

        isRestoringGestureSettings = false
    }

    static func sanitizeLegacyGestureSettingsIfNeeded(defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.promptOnlyMigrationCompleted) else {
            return
        }

        for key in LegacyDefaultsKey.all {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: DefaultsKey.promptOnlyMigrationCompleted)
    }

    private func setFeedback(_ message: String) {
        gestureFeedbackMessage = message
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self else { return }
            self.gestureFeedbackMessage = nil
        }
    }
}
