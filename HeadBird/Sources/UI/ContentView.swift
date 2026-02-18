import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: HeadBirdModel
    @State private var selectedTab: PopoverTab = .motion
    @State private var graphStyle: MotionHistoryGraph.GraphStyle = .lines

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
        let isEnabled = model.connectedAirPods.isEmpty == false
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Gesture Controls")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    StatusPill(status: model.motionConnectionStatus)
                }

                calibrationCard
                mappingCard(
                    title: "Nod Mapping",
                    action: $model.nodMappedAction,
                    shortcutName: $model.nodShortcutName
                )
                mappingCard(
                    title: "Shake Mapping",
                    action: $model.shakeMappedAction,
                    shortcutName: $model.shakeShortcutName
                )
                permissionsCard
                safetyCard
                lastGestureCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calibration")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.gestureCalibrationState.stage.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(model.gestureCalibrationState.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.gestureCalibrationState.isCapturing {
                ProgressView(value: model.gestureCalibrationState.progress)
            }

            HStack(spacing: 8) {
                Button("Start") {
                    model.startGestureCalibration()
                }
                .buttonStyle(.bordered)

                Button(captureButtonTitle) {
                    model.beginCalibrationCapture()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCaptureCalibrationStage)

                Button("Use Fallback") {
                    model.skipCalibrationWithFallbackProfile()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Toggle("Using fallback profile", isOn: .constant(model.usesFallbackGestureProfile))
                    .disabled(true)
                    .toggleStyle(.switch)
                Spacer()
                Button("Clear Profile") {
                    model.clearCalibrationProfile()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func mappingCard(
        title: String,
        action: Binding<GestureMappedAction>,
        shortcutName: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Picker("Action", selection: action) {
                ForEach(GestureMappedAction.allCases) { map in
                    Text(map.title).tag(map)
                }
            }
            .pickerStyle(.menu)

            if action.wrappedValue.requiresShortcutName {
                TextField("Shortcut Name", text: shortcutName)
                    .textFieldStyle(.roundedBorder)
                Text("Example: Dark Mode Toggle, Focus Work")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.subheadline.weight(.semibold))

            permissionRow(
                title: "Accessibility",
                isGranted: model.accessibilityTrusted,
                help: "Needed for AX default/cancel button actions."
            )

            permissionRow(
                title: "Event Posting",
                isGranted: model.postEventAccessGranted,
                help: "Needed for Return/Escape fallback events."
            )

            HStack(spacing: 8) {
                Button("Request Accessibility") {
                    model.requestAccessibilityPermissionPrompt()
                }
                .buttonStyle(.bordered)

                Button("Request Event Access") {
                    model.requestPostEventPermissionPrompt()
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    model.refreshGesturePermissions(promptForAccessibility: false)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
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

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety")
                .font(.subheadline.weight(.semibold))

            Toggle("Control mode enabled", isOn: $model.gestureControlEnabled)
                .toggleStyle(.switch)

            Toggle("Double-confirm gestures", isOn: $model.doubleConfirmEnabled)
                .toggleStyle(.switch)

            HStack(spacing: 10) {
                Text("Extra Cooldown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
                Slider(value: $model.gestureCooldownSeconds, in: 0...1.6, step: 0.05)
                Text(String(format: "%.2fs", model.gestureCooldownSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }

            Text(model.canUseGestureControls ? "Ready for nod/shake input." : "Connect AirPods and complete calibration to enable controls.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var lastGestureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Gesture")
                .font(.subheadline.weight(.semibold))

            if let event = model.lastGestureEvent {
                HStack {
                    Text(event.gesture.title)
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("\(Int(event.confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No gesture detected yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var captureButtonTitle: String {
        switch model.gestureCalibrationState.stage {
        case .neutral:
            return "Capture Neutral"
        case .nod:
            return "Capture Nod"
        case .shake:
            return "Capture Shake"
        case .notStarted:
            return "Start First"
        case .completed:
            return "Done"
        }
    }

    private var canCaptureCalibrationStage: Bool {
        let stage = model.gestureCalibrationState.stage
        return !model.gestureCalibrationState.isCapturing && (stage == .neutral || stage == .nod || stage == .shake)
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
