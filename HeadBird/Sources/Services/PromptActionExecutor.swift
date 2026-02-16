import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class PromptActionExecutor {
    func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    func isPostEventAccessGranted() -> Bool {
        CGPreflightPostEventAccess()
    }

    @discardableResult
    func requestPostEventAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    func execute(decision: PromptDecision) -> GestureActionResult {
        guard isAccessibilityTrusted() else {
            if fallbackByPostingKey(decision: decision) {
                return .success(message(for: decision, suffix: "via key fallback"))
            }
            return .failure("Accessibility permission is required for prompt control.")
        }

        if pressPromptButton(decision: decision) {
            return .success(message(for: decision))
        }

        if fallbackByPostingKey(decision: decision) {
            return .success(message(for: decision, suffix: "via key fallback"))
        }

        return .failure("Couldn't control the current prompt.")
    }

    private func message(for decision: PromptDecision, suffix: String? = nil) -> String {
        let base: String
        switch decision {
        case .accept:
            base = "Accepted prompt"
        case .reject:
            base = "Rejected prompt"
        }
        if let suffix {
            return "\(base) (\(suffix))"
        }
        return base
    }

    private func pressPromptButton(decision: PromptDecision) -> Bool {
        guard let focusedWindow = focusedWindowElement() else {
            return false
        }

        let targetAttribute: CFString = {
            switch decision {
            case .accept:
                return kAXDefaultButtonAttribute as CFString
            case .reject:
                return kAXCancelButtonAttribute as CFString
            }
        }()

        guard let targetButton = copyElementAttribute(from: focusedWindow, attribute: targetAttribute) else {
            return false
        }

        let status = AXUIElementPerformAction(targetButton, kAXPressAction as CFString)
        return status == .success
    }

    private func focusedWindowElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let focused = copyElementAttribute(from: appElement, attribute: kAXFocusedWindowAttribute as CFString) {
            return focused
        }
        return copyElementAttribute(from: appElement, attribute: kAXMainWindowAttribute as CFString)
    }

    private func copyElementAttribute(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        guard let value else { return nil }
        return (value as! AXUIElement)
    }

    private func fallbackByPostingKey(decision: PromptDecision) -> Bool {
        guard isPostEventAccessGranted() || requestPostEventAccess() else {
            return false
        }

        let keyCode: CGKeyCode
        switch decision {
        case .accept:
            keyCode = 36 // Return
        case .reject:
            keyCode = 53 // Escape
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            return false
        }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }
}
