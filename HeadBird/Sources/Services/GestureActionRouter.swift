import Foundation

protocol PromptActionExecuting {
    func execute(decision: PromptDecision) -> GestureActionResult
}

protocol ShortcutActionExecuting {
    func execute(shortcutName: String) -> GestureActionResult
}

extension PromptActionExecutor: PromptActionExecuting {}
extension ShortcutActionExecutor: ShortcutActionExecuting {}

final class GestureActionRouter {
    private let promptExecutor: PromptActionExecuting
    private let shortcutExecutor: ShortcutActionExecuting

    init(
        promptExecutor: PromptActionExecuting,
        shortcutExecutor: ShortcutActionExecuting
    ) {
        self.promptExecutor = promptExecutor
        self.shortcutExecutor = shortcutExecutor
    }

    func route(
        event: HeadGestureEvent,
        config: GestureActionRouteConfig,
        recenterMotion: () -> Void,
        toggleControlMode: () -> Bool
    ) -> GestureActionResult {
        let action: GestureMappedAction
        switch event.gesture {
        case .nod:
            action = config.nodAction
        case .shake:
            action = config.shakeAction
        }

        switch action {
        case .promptResponse:
            let decision: PromptDecision = event.gesture == .nod ? .accept : .reject
            return promptExecutor.execute(decision: decision)

        case .runShortcut:
            let shortcutName = event.gesture == .nod ? config.nodShortcutName : config.shakeShortcutName
            return shortcutExecutor.execute(shortcutName: shortcutName)

        case .recenterMotion:
            recenterMotion()
            return .success("Motion recentered.")

        case .toggleControlMode:
            let isEnabled = toggleControlMode()
            return .success(isEnabled ? "Control mode enabled." : "Control mode disabled.")
        }
    }
}
