import AppKit
import CoreMotion
import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var model: HeadBirdModel
    @State private var selectedTab: PopoverTab = .motion
    @State private var graphStyle: MotionHistoryGraph.GraphStyle = .lines
    @State private var isPromptDebugSnapshotExpanded = false

    var body: some View {
        VStack(spacing: 10) {
            Picker("", selection: $selectedTab) {
                Text("Motion").tag(PopoverTab.motion)
                Text("Controls").tag(PopoverTab.controls)
                Text("Games").tag(PopoverTab.game)
                Text("About").tag(PopoverTab.about)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            switch selectedTab {
            case .motion:
                motionTab
            case .controls:
                controlsTab
            case .game:
                GamesView(isActive: model.isPopoverPresented)
            case .about:
                aboutTab
            }
        }
        .padding(.bottom, 18)
        .onAppear {
            model.setActiveTab(selectedTab)
        }
        .onChange(of: selectedTab) { _, tab in
            model.setActiveTab(tab)
        }
    }

    private var motionTab: some View {
        let displayPose = model.motionPose.scaled(by: model.motionSensitivity)
        let pitchDegrees = degrees(displayPose.pitch)
        let rollDegrees = degrees(displayPose.roll)
        let yawDegrees = degrees(displayPose.yaw)
        let isEnabled = model.hasAnyAirPodsConnection
        let pitchColor = Color.blue
        let rollColor = Color.orange
        let yawColor = Color.green

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.activeAirPodsName ?? "Not connected")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusPill(status: model.motionConnectionStatus)
            }
            .padding(.horizontal, 24)

            MotionHorizonView(pitch: displayPose.pitch, roll: displayPose.roll)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                MotionDialView(label: "Pitch", valueDegrees: pitchDegrees, color: pitchColor)
                    .frame(maxWidth: .infinity)
                MotionDialView(label: "Roll", valueDegrees: rollDegrees, color: rollColor)
                    .frame(maxWidth: .infinity)
                MotionDialView(label: "Yaw", valueDegrees: yawDegrees, color: yawColor)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Text("History")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("", selection: $graphStyle) {
                    ForEach(MotionHistoryGraph.GraphStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button {
                    model.toggleGraphPlaying()
                } label: {
                    Image(systemName: model.isGraphPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(model.isGraphPlaying ? "Stop graph" : "Play graph")
                .help(model.isGraphPlaying ? "Stop graph updates" : "Play graph updates")
                .disabled(!isEnabled)

                Button("Set Zero") {
                    model.recenterMotion()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!model.motionStreaming || !isEnabled)
            }
            .padding(.horizontal, 24)

            MotionHistoryGraph(
                samples: model.motionHistory,
                sensitivity: model.motionSensitivity,
                style: graphStyle,
                showGrid: true
            )
            .padding(.horizontal, 24)
            .opacity(isEnabled ? 1.0 : 0.6)

            HStack(spacing: 12) {
                Text("Sensitivity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(value: $model.motionSensitivity, in: 0.5...2.0, step: 0.05)
                Text(String(format: "%.2fx", model.motionSensitivity))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 6)
    }

    private var controlsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gesture Controls")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    StatusPill(status: model.motionConnectionStatus)
                }

                readinessCard
                calibrationCard
                liveTesterCard
                fixedMappingsCard
                permissionsCard
                promptDebugCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var readinessCard: some View {
        guidedCard(step: "Step 1", title: "Readiness", subtitle: "Verify hardware, permissions, and profile state.") {
            readinessRow(
                title: "Connection",
                detail: model.activeAirPodsName ?? "No AirPods connected",
                isReady: model.activeAirPodsName != nil
            )
            readinessRow(
                title: "Motion Permission",
                detail: motionAuthorizationText,
                isReady: model.motionAuthorization == .authorized
            )
            readinessRow(
                title: "Calibration Profile",
                detail: model.gestureCalibrationState.hasProfile
                    ? (model.usesFallbackGestureProfile ? "Fallback profile active" : "Custom profile active")
                    : "No profile configured",
                isReady: model.gestureCalibrationState.hasProfile
            )
            readinessRow(
                title: "Control Mode",
                detail: model.gestureControlEnabled ? "Enabled" : "Disabled",
                isReady: model.gestureControlEnabled
            )
            readinessRow(
                title: "Prompt Target",
                detail: promptTargetStatusText,
                isReady: model.promptTargetCapabilities.hasAnyTarget
            )
            readinessRow(
                title: "Prompt Target Name",
                detail: promptTargetNameStatusText,
                isReady: model.promptContextDetected && model.promptTargetName != nil
            )
        }
    }

    private var calibrationCard: some View {
        guidedCard(
            step: "Step 2",
            title: "Calibration",
            subtitle: "Capture neutral, nod, and shake to tune thresholds.",
            headerTrailing: {
                stateChip(
                    title: model.usesFallbackGestureProfile ? "Fallback" : "Custom",
                    tint: model.usesFallbackGestureProfile ? .orange : .green
                )
            }
        ) {
            Text(calibrationStageLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.gestureCalibrationState.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.gestureCalibrationState.isCapturing {
                ProgressView(value: model.gestureCalibrationState.progress)
            }

            HStack(spacing: 8) {
                Button(calibrationPrimaryActionTitle) {
                    runCalibrationPrimaryAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPerformCalibrationPrimaryAction)

                Button("Use Fallback") {
                    model.skipCalibrationWithFallbackProfile()
                }
                .buttonStyle(.bordered)
                Button("Clear Profile") {
                    model.clearCalibrationProfile()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var liveTesterCard: some View {
        guidedCard(
            step: "Step 3",
            title: "Live Tester",
            subtitle: "Visualizes nod/shake confidence while enabled. Actions still require a prompt target.",
            headerTrailing: {
                stateChip(
                    title: testerStateTitle,
                    tint: testerStateTint
                )
            }
        ) {
            HStack {
                Text("Live tester enabled")
                    .font(.caption.weight(.medium))
                Spacer()
                if model.gestureTesterEnabled && model.gestureDiagnostics.sampleRateHertz > 0 {
                    Text(String(format: "%.1f Hz", model.gestureDiagnostics.sampleRateHertz))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Toggle("", isOn: $model.gestureTesterEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!model.gestureControlEnabled)
            }

            if model.gestureTesterEnabled {
                confidenceRow(
                    label: "Nod",
                    rawConfidence: model.gestureDiagnostics.rawNodConfidence,
                    smoothedConfidence: model.gestureDiagnostics.nodConfidence,
                    triggerThreshold: model.gestureDiagnostics.triggerThreshold,
                    tint: .blue
                )
                confidenceRow(
                    label: "Shake",
                    rawConfidence: model.gestureDiagnostics.rawShakeConfidence,
                    smoothedConfidence: model.gestureDiagnostics.shakeConfidence,
                    triggerThreshold: model.gestureDiagnostics.triggerThreshold,
                    tint: .green
                )

                HStack {
                    Text("Candidate")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(model.gestureDiagnostics.candidateGesture?.title ?? "None")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Enable Live Tester to visualize nod/shake confidence.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Last Detected")
                    .font(.caption.weight(.medium))
                Spacer()
                if let event = model.lastGestureEvent {
                    Text("\(event.gesture.title) \(Int(event.confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Last Action Result")
                    .font(.caption.weight(.medium))
                Spacer()
                if let result = model.lastGestureActionResult {
                    let timestampText = model.lastGestureActionTimestamp?.formatted(date: .omitted, time: .standard) ?? ""
                    let timestampSuffix = timestampText.isEmpty ? "" : " @ \(timestampText)"
                    Text(result + timestampSuffix)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(actionGateStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(liveTesterStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var fixedMappingsCard: some View {
        guidedCard(step: "Step 4", title: "Gesture Mapping", subtitle: "Prompt control is fixed for now. More mappings can be added in a future update.") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nod: Accept prompt")
                    .font(.caption.weight(.medium))
                Text("Shake: Reject prompt")
                    .font(.caption.weight(.medium))
            }

            HStack {
                Text("Control mode enabled")
                    .font(.caption.weight(.medium))
                Spacer()
                Toggle("", isOn: $model.gestureControlEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!model.gestureCalibrationState.hasProfile)
            }

            Text(
                model.gestureControlEnabled
                    ? (model.promptTargetCapabilities.hasAnyTarget
                        ? "Control mode is active. Detected nod/shake can accept or reject prompts."
                        : "Control mode is active but waiting for a prompt target.")
                    : (model.gestureCalibrationState.hasProfile
                        ? "Control mode is off. Enable it to run gesture features."
                        : "Control mode is unavailable until calibration or Use Fallback sets a profile.")
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let feedback = model.gestureFeedbackMessage {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionsCard: some View {
        guidedCard(step: "Step 5", title: "Permissions", subtitle: "Required for prompt actions.") {
            permissionRow(
                title: "Accessibility",
                isGranted: model.accessibilityTrusted,
                help: "Needed for AX default/cancel button actions."
            )

            HStack(spacing: 8) {
                Button("Request Accessibility") {
                    model.requestAccessibilityPermissionPrompt()
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    model.refreshGesturePermissions(promptForAccessibility: false)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var promptDebugCard: some View {
        guidedCard(step: "Debug", title: "Prompt Debug", subtitle: "Capture a bounded Accessibility snapshot to diagnose prompt detection.") {
            HStack {
                Text("AX Debug Mode")
                    .font(.caption.weight(.medium))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.promptDebugModeEnabled },
                        set: { model.setPromptDebugModeEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            HStack {
                Text("Allow banners while popover open (debug)")
                    .font(.caption.weight(.medium))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.promptDebugNotificationOverrideEnabled },
                        set: { model.setPromptDebugBannerOverride($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!model.promptDebugModeEnabled)
            }

            HStack(spacing: 8) {
                Button("Capture Prompt Snapshot") {
                    model.capturePromptAXDebugSnapshot()
                    isPromptDebugSnapshotExpanded = true
                }
                .buttonStyle(.borderedProminent)

                Button("Clear Snapshot") {
                    model.clearPromptAXDebugSnapshot()
                }
                .buttonStyle(.bordered)
                .disabled(model.lastPromptAXDebugSnapshot == nil)

                Button("Copy Snapshot") {
                    copyPromptDebugSnapshotToPasteboard()
                }
                .buttonStyle(.bordered)
                .disabled(model.lastPromptAXDebugSnapshot == nil)
            }

            readinessRow(
                title: "Prompt Signature",
                detail: model.promptTargetSignature ?? "No prompt signature",
                isReady: model.promptTargetSignature != nil
            )

            readinessRow(
                title: "Notification Permission",
                detail: notificationAuthorizationStatusText,
                isReady: model.notificationAuthorizationStatus == .authorized || model.notificationAuthorizationStatus == .provisional
            )

            readinessRow(
                title: "Last Snapshot Summary",
                detail: promptDebugSnapshotSummaryText,
                isReady: model.lastPromptAXDebugSnapshot != nil
            )

            DisclosureGroup(isExpanded: $isPromptDebugSnapshotExpanded) {
                ScrollView {
                    Text(promptDebugSnapshotBodyText)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 120, maxHeight: 220)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.08))
                )
            } label: {
                Text("Snapshot Details")
                    .font(.caption.weight(.medium))
            }
        }
    }

    private func permissionRow(title: String, isGranted: Bool, help: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isGranted ? "checkmark.seal.fill" : "xmark.seal")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .font(.caption)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func readinessRow(title: String, detail: String, isReady: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(isReady ? Color.green : Color.orange)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func confidenceRow(
        label: String,
        rawConfidence: Double,
        smoothedConfidence: Double,
        triggerThreshold: Double,
        tint: Color
    ) -> some View {
        let clampedRaw = max(0, min(1, rawConfidence))
        let clampedSmoothed = max(0, min(1, smoothedConfidence))
        let clampedThreshold = max(0, min(1, triggerThreshold))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("Raw \(Int(clampedRaw * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: proxy.size.width * clampedRaw)
                    Rectangle()
                        .fill(Color.primary.opacity(0.65))
                        .frame(width: 1.5, height: 12)
                        .offset(x: (proxy.size.width * clampedThreshold) - 0.75)
                }
            }
            .frame(height: 12)
            HStack {
                Text("Trigger >= \(Int(clampedThreshold * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Smoothed \(Int(clampedSmoothed * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func guidedCard<Content: View>(
        step: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        guidedCard(step: step, title: title, subtitle: subtitle, headerTrailing: { EmptyView() }, content: content)
    }

    private func guidedCard<HeaderTrailing: View, Content: View>(
        step: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(step)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.16))
                    )
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                headerTrailing()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func stateChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.2))
            )
            .foregroundStyle(tint)
    }

    private var calibrationPrimaryActionTitle: String {
        switch model.gestureCalibrationState.stage {
        case .notStarted, .completed:
            return "Start Calibration"
        case .neutral:
            return "Capture Neutral"
        case .nod:
            return "Capture Nod"
        case .shake:
            return "Capture Shake"
        }
    }

    private var canPerformCalibrationPrimaryAction: Bool {
        let stage = model.gestureCalibrationState.stage
        if model.gestureCalibrationState.isCapturing {
            return false
        }
        return stage == .notStarted || stage == .completed || stage == .neutral || stage == .nod || stage == .shake
    }

    private var calibrationStageLabel: String {
        switch model.gestureCalibrationState.stage {
        case .notStarted:
            return "Not Started"
        case .neutral:
            return "Neutral Stage"
        case .nod:
            return "Nod Stage"
        case .shake:
            return "Shake Stage"
        case .completed:
            return "Completed"
        }
    }

    private var motionAuthorizationText: String {
        switch model.motionAuthorization {
        case .authorized:
            return "Authorized"
        case .notDetermined:
            return "Not determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }

    private var liveTesterStatusText: String {
        if !model.gestureCalibrationState.hasProfile {
            return "Live tester is unavailable until calibration or Use Fallback provides a profile."
        }
        if !model.gestureControlEnabled {
            return "Live tester is unavailable while Control Mode is off."
        }
        if !model.gestureTesterEnabled {
            return "Live tester is off. Enable it to visualize nod/shake confidence, even without a prompt."
        }
        if !model.motionStreaming {
            return "Waiting for motion stream. Connect AirPods and keep this tab open."
        }
        return "Live tester is active. Visualization works without a prompt; actions still wait for prompt targets."
    }

    private var actionGateStatusText: String {
        if !model.gestureCalibrationState.hasProfile {
            return "Actions disabled until calibration or Use Fallback."
        }
        if !model.gestureControlEnabled {
            return "Actions disabled because Control Mode is off."
        }
        if !model.accessibilityTrusted {
            return "Actions disabled until Accessibility permission is granted."
        }
        if !model.promptTargetCapabilities.hasAnyTarget {
            return "Control mode enabled, waiting for frontmost prompt target."
        }
        return "Actions are enabled for the current prompt target."
    }

    private var promptTargetStatusText: String {
        let capabilities = model.promptTargetCapabilities
        if capabilities.canAccept && capabilities.canReject {
            return "Accept and Reject available"
        }
        if capabilities.canAccept {
            return "Accept only"
        }
        if capabilities.canReject {
            return "Reject only"
        }
        let reason = model.promptTargetDebugMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason.isEmpty {
            return "No prompt target"
        }
        return "No prompt target (\(reason))"
    }

    private var promptTargetNameStatusText: String {
        guard model.promptContextDetected else {
            return "No prompt detected"
        }
        if let name = model.promptTargetName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return "Prompt detected (name unavailable)"
    }

    private var notificationAuthorizationStatusText: String {
        switch model.notificationAuthorizationStatus {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    private var promptDebugSnapshotSummaryText: String {
        guard let snapshot = model.lastPromptAXDebugSnapshot else {
            return "No snapshot captured"
        }
        let pid = snapshot.appProcessIdentifier.map(String.init) ?? "nil"
        let reason = snapshot.failureReason?.rawValue ?? "none"
        return "pid=\(pid) roots=\(snapshot.rootsCount) promptLike=\(snapshot.promptLikeContainerCount) buttons=\(snapshot.buttonCandidateCount) failure=\(reason)"
    }

    private var promptDebugSnapshotBodyText: String {
        model.lastPromptAXDebugSnapshot?.formattedText ?? "Capture a prompt snapshot to inspect the AX tree."
    }

    private func copyPromptDebugSnapshotToPasteboard() {
        guard let text = model.lastPromptAXDebugSnapshot?.formattedText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private var testerStateTitle: String {
        model.gestureTesterEnabled ? "Tester On" : "Tester Off"
    }

    private var testerStateTint: Color {
        if !model.gestureControlEnabled || !model.gestureCalibrationState.hasProfile {
            return .orange
        }
        if !model.gestureTesterEnabled {
            return .orange
        }
        return .green
    }

    private func runCalibrationPrimaryAction() {
        switch model.gestureCalibrationState.stage {
        case .notStarted, .completed:
            model.startGestureCalibration()
        case .neutral, .nod, .shake:
            model.beginCalibrationCapture()
        }
    }

    private func degrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    appIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HeadBird")
                            .font(.title3.weight(.semibold))
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                githubLink
            }

            Text("AirPods motion visualization with a head‑controlled mini game in the menu bar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                privacyCard
                signalsCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var appIcon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: 44, height: 44)
            .scaleEffect(1.22)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
    }

    private var githubLink: some View {
        Link(destination: URL(string: "https://github.com/Lelin07/HeadBird")!) {
            HStack(spacing: 8) {
                githubIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("GitHub")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build, short != build {
            return "\(short) (\(build))"
        }
        return short ?? build ?? "Unknown"
    }

    private var privacyCard: some View {
        aboutInfoCard(
            title: "Privacy",
            systemImage: "lock.shield",
            bullets: [
                "No microphone access.",
                "No audio recording or processing.",
                "Motion and device-state data stays on this Mac.",
                "No cloud upload of this data."
            ]
        )
    }

    private var signalsCard: some View {
        aboutInfoCard(
            title: "Signals",
            systemImage: "antenna.radiowaves.left.and.right",
            bullets: [
                "AirPods connection status.",
                "Default output-device status.",
                "Headphone motion (pitch, roll, yaw).",
                "Gesture mapping and calibration settings."
            ]
        )
    }

    private func aboutInfoCard(title: String, systemImage: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .padding(.top, 5)
                        Text(bullet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var githubIcon: Image {
        if let image = NSImage(named: "GitHubMark") {
            return Image(nsImage: image)
        }
        return Image(systemName: "chevron.left.slash.chevron.right")
    }
}
