import AppKit
import Carbon
import CoreGraphics
import Foundation

protocol AppleScriptExecuting {
    func executeAppleScript(source: String) -> GestureActionResult
}

enum SystemGestureAction: Equatable {
    case toggleDarkMode
    case playPauseMedia
}

final class ScriptActionExecutor {
    func executeAppleScript(source: String) -> GestureActionResult {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)

        if result != nil {
            return .success("AppleScript executed.")
        }

        if let error,
           let message = error[NSAppleScript.errorMessage] as? String {
            return .failure("AppleScript failed: \(message)")
        }

        return .failure("AppleScript failed.")
    }
}
extension ScriptActionExecutor: AppleScriptExecuting {}

final class SystemActionExecutor {
    private enum MediaKeyState {
        static let keyDown = Int32(0xA)
        static let keyUp = Int32(0xB)
        static let subtypeAuxControlButton = Int16(8)
    }

    private let scriptExecutor: AppleScriptExecuting

    init(scriptExecutor: AppleScriptExecuting = ScriptActionExecutor()) {
        self.scriptExecutor = scriptExecutor
    }

    func execute(action: SystemGestureAction) -> GestureActionResult {
        switch action {
        case .toggleDarkMode:
            return toggleDarkMode()
        case .playPauseMedia:
            return playPauseMedia()
        }
    }

    private func toggleDarkMode() -> GestureActionResult {
        let source = """
            tell application id "com.apple.systemevents" to launch
            delay 0.08
            tell application id "com.apple.systemevents"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """
        var result = scriptExecutor.executeAppleScript(source: source)
        if shouldRetryToggleDarkMode(result) {
            result = scriptExecutor.executeAppleScript(source: source)
        }

        switch result {
        case .success:
            return .success("Toggled dark/light mode.")
        case let .failure(message):
            return .failure(mapDarkModeFailure(message))
        case let .ignored(message):
            return .ignored(message)
        }
    }

    private func shouldRetryToggleDarkMode(_ result: GestureActionResult) -> Bool {
        guard case let .failure(message) = result else { return false }
        let normalized = message.lowercased()
        return normalized.contains("isn’t running") || normalized.contains("isn't running")
    }

    private func mapDarkModeFailure(_ message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("not authorized")
            || normalized.contains("apple events")
            || normalized.contains("error: -1743") {
            return "Failed to toggle dark/light mode. Allow HeadBird to control System Events in System Settings > Privacy & Security > Automation."
        }
        return "Failed to toggle dark/light mode. \(message)"
    }

    private func playPauseMedia() -> GestureActionResult {
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            return .failure("Event posting permission is required for media control.")
        }

        guard postMediaKeyPress(keyType: Int32(NX_KEYTYPE_PLAY)) else {
            return .failure("Failed to send Play/Pause media key.")
        }

        return .success("Sent Play/Pause media key.")
    }

    private func postMediaKeyPress(keyType: Int32) -> Bool {
        guard let keyDownEvent = makeMediaKeyEvent(keyType: keyType, keyState: MediaKeyState.keyDown) else {
            return false
        }
        guard let keyUpEvent = makeMediaKeyEvent(keyType: keyType, keyState: MediaKeyState.keyUp) else {
            return false
        }

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        return true
    }

    private func makeMediaKeyEvent(keyType: Int32, keyState: Int32) -> CGEvent? {
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(keyState << 8))
        let data1 = Int((keyType << 16) | (keyState << 8))
        return NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: MediaKeyState.subtypeAuxControlButton,
            data1: data1,
            data2: -1
        )?.cgEvent
    }
}
