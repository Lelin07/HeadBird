import AppIntents
import Foundation

private enum GestureIntentDefaultsKey {
    static let gestureControlEnabled = "HeadBird.GestureControlEnabled"
    static let pendingCalibrationStart = "HeadBird.PendingCalibrationStart"
}

struct EnableGestureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Enable Gesture Control"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: await GestureIntentDefaultsKey.gestureControlEnabled)
        return .result(dialog: IntentDialog("Gesture control enabled."))
    }
}

struct DisableGestureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Disable Gesture Control"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(false, forKey: await GestureIntentDefaultsKey.gestureControlEnabled)
        return .result(dialog: IntentDialog("Gesture control disabled."))
    }
}

struct SetPromptMappingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Use Prompt Gestures"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: IntentDialog("HeadBird uses nod and shake for prompt accept/reject."))
    }
}

struct StartGestureCalibrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Gesture Calibration"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: await GestureIntentDefaultsKey.pendingCalibrationStart)
        return .result(dialog: IntentDialog("Calibration queued. Open HeadBird controls to capture each stage."))
    }
}

struct HeadBirdAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EnableGestureControlIntent(),
            phrases: [
                "Enable gesture control in \(.applicationName)",
                "Turn on nod control in \(.applicationName)"
            ],
            shortTitle: "Enable Control",
            systemImageName: "power"
        )
        AppShortcut(
            intent: DisableGestureControlIntent(),
            phrases: [
                "Disable gesture control in \(.applicationName)",
                "Turn off nod control in \(.applicationName)"
            ],
            shortTitle: "Disable Control",
            systemImageName: "poweroff"
        )
        AppShortcut(
            intent: SetPromptMappingsIntent(),
            phrases: [
                "Set prompt mappings in \(.applicationName)",
                "Use nod and shake for prompts in \(.applicationName)"
            ],
            shortTitle: "Prompt Mapping",
            systemImageName: "checkmark.message"
        )
        AppShortcut(
            intent: StartGestureCalibrationIntent(),
            phrases: [
                "Start calibration in \(.applicationName)",
                "Calibrate head gestures in \(.applicationName)"
            ],
            shortTitle: "Start Calibration",
            systemImageName: "dot.scope"
        )
    }
}
