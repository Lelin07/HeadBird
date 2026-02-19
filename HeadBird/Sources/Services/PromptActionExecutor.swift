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

        if let targetButton = copyElementAttribute(from: focusedWindow, attribute: targetAttribute) {
            let status = AXUIElementPerformAction(targetButton, kAXPressAction as CFString)
            if status == .success {
                return true
            }
        }

        if let fallbackButton = buttonCandidate(in: focusedWindow, decision: decision) {
            let status = AXUIElementPerformAction(fallbackButton, kAXPressAction as CFString)
            return status == .success
        }

        return false
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
        guard let value = copyAttributeValue(from: element, attribute: attribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyAttributeValue(from element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        return value
    }

    private func copyElementArrayAttribute(from element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        guard let value = copyAttributeValue(from: element, attribute: attribute) else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func copyStringAttribute(from element: AXUIElement, attribute: CFString) -> String? {
        guard let value = copyAttributeValue(from: element, attribute: attribute) else { return nil }
        return value as? String
    }

    private func buttonCandidate(in window: AXUIElement, decision: PromptDecision) -> AXUIElement? {
        let buttons = collectButtons(from: window, depth: 0, maxDepth: 6)
        guard !buttons.isEmpty else { return nil }

        let rejectTokens = [
            "cancel",
            "stay",
            "dont",
            "don't",
            "no",
            "close",
            "deny",
            "not now"
        ]
        let acceptTokens = [
            "ok",
            "yes",
            "allow",
            "continue",
            "open",
            "leave",
            "empty",
            "erase",
            "delete",
            "remove",
            "replace"
        ]

        let tokens = decision == .reject ? rejectTokens : acceptTokens
        if let matched = buttons.first(where: { button in
            let title = normalizedButtonTitle(button)
            return tokens.contains(where: { title.contains($0) })
        }) {
            return matched
        }

        if decision == .accept {
            return buttons.last
        }
        return buttons.first
    }

    private func collectButtons(from element: AXUIElement, depth: Int, maxDepth: Int) -> [AXUIElement] {
        guard depth <= maxDepth else { return [] }

        let role = copyStringAttribute(from: element, attribute: kAXRoleAttribute as CFString) ?? ""
        var buttons: [AXUIElement] = role == (kAXButtonRole as String) ? [element] : []

        let children = copyElementArrayAttribute(from: element, attribute: kAXChildrenAttribute as CFString)
        for child in children {
            buttons.append(contentsOf: collectButtons(from: child, depth: depth + 1, maxDepth: maxDepth))
        }

        return buttons
    }

    private func normalizedButtonTitle(_ element: AXUIElement) -> String {
        let title = copyStringAttribute(from: element, attribute: kAXTitleAttribute as CFString) ?? ""
        return title.lowercased()
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
