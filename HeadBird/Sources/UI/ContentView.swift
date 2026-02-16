import AppKit
import CoreBluetooth
import CoreMotion
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: HeadBirdModel
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
                "Sensitivity value for game control."
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
