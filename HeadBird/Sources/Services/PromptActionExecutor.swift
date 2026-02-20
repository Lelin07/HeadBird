import AppKit
import ApplicationServices
import Foundation

struct PromptTargetCapabilities: Equatable, Sendable {
    let canAccept: Bool
    let canReject: Bool

    var hasAnyTarget: Bool {
        canAccept || canReject
    }

    func supports(_ decision: PromptDecision) -> Bool {
        switch decision {
        case .accept:
            return canAccept
        case .reject:
            return canReject
        }
    }

    static let none = PromptTargetCapabilities(canAccept: false, canReject: false)
}

final class PromptActionExecutor {
    func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    func currentPromptTargetCapabilities() -> PromptTargetCapabilities {
        guard isAccessibilityTrusted() else {
            return .none
        }
        guard let focusedWindow = focusedWindowElement() else {
            return .none
        }
        let canAccept = promptButton(decision: .accept, in: focusedWindow) != nil
        let canReject = promptButton(decision: .reject, in: focusedWindow) != nil
        return PromptTargetCapabilities(canAccept: canAccept, canReject: canReject)
    }

    func execute(decision: PromptDecision) -> GestureActionResult {
        guard isAccessibilityTrusted() else {
            return .failure("Accessibility permission is required for prompt control.")
        }
        guard let focusedWindow = focusedWindowElement(),
              let targetButton = promptButton(decision: decision, in: focusedWindow) else {
            return .ignored("No prompt target")
        }

        let status = AXUIElementPerformAction(targetButton, kAXPressAction as CFString)
        return status == .success ? .success(message(for: decision)) : .failure("Couldn't control the current prompt.")
    }

    private func message(for decision: PromptDecision) -> String {
        let base: String
        switch decision {
        case .accept:
            base = "Accepted prompt"
        case .reject:
            base = "Rejected prompt"
        }
        return base
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

    private func targetAttribute(for decision: PromptDecision) -> CFString {
        switch decision {
        case .accept:
            return kAXDefaultButtonAttribute as CFString
        case .reject:
            return kAXCancelButtonAttribute as CFString
        }
    }

    private func promptButton(decision: PromptDecision, in focusedWindow: AXUIElement) -> AXUIElement? {
        copyElementAttribute(from: focusedWindow, attribute: targetAttribute(for: decision))
    }
}
