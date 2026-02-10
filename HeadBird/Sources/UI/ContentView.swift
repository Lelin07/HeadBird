import AppKit
import CoreBluetooth
import CoreMotion
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: HeadBarModel
    @State private var selectedTab: Tab = .motion
    @State private var graphStyle: MotionHistoryGraph.GraphStyle = .lines

    private enum Tab {
        case motion
        case game
        case about
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("", selection: $selectedTab) {
                Text("Motion").tag(Tab.motion)
                Text("Game").tag(Tab.game)
                Text("About").tag(Tab.about)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            switch selectedTab {
            case .motion:
                motionTab
            case .game:
                FlappyGameView(isActive: true)
            case .about:
                aboutTab
            }
        }
        .padding(.bottom, 18)
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
                StatusPill(isConnected: isEnabled)
            }
            .padding(.horizontal, 24)

            if let status = motionStatusText {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

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

    private var motionStatusText: String? {
        if model.connectedAirPods.isEmpty,
           (model.bluetoothAuthorization == .denied || model.bluetoothAuthorization == .restricted) {
            return "Bluetooth permission required"
        }
        if model.connectedAirPods.isEmpty {
            return "Not connected"
        }
        if !model.motionAvailable {
            return "Motion unavailable"
        }
        if model.motionAuthorization == .denied || model.motionAuthorization == .restricted {
            return "Permission required"
        }
        if !model.motionStreaming {
            return "Waiting…"
        }
        return nil
    }

    private func degrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("HB")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("HeadBird")
                        .font(.title3.weight(.semibold))
                    if let version = appVersion {
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("AirPods motion visualization with a head‑controlled mini game in the menu bar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                infoRow(title: "Privacy", detail: "No microphone usage. No audio processing.")
                infoRow(title: "Signals", detail: "AirPods connection, default output device, headphone motion.")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )

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
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var appVersion: String? {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build, short != build {
            return "\(short) (\(build))"
        }
        return short ?? build
    }

    private func infoRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var githubIcon: Image {
        if let image = NSImage(named: "GitHubMark") {
            return Image(nsImage: image)
        }
        return Image(systemName: "chevron.left.slash.chevron.right")
    }
}
