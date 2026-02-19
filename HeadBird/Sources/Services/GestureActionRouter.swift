import Foundation

protocol PromptActionExecuting {
    func execute(decision: PromptDecision) -> GestureActionResult
}

protocol ShortcutActionExecuting {
    func execute(shortcutName: String) -> GestureActionResult
}

enum SystemGestureAction: Equatable {
    case toggleDarkMode
    case playPauseMedia
}

protocol SystemActionExecuting {
    func execute(action: SystemGestureAction) -> GestureActionResult
}

extension PromptActionExecutor: PromptActionExecuting {}
extension ShortcutActionExecutor: ShortcutActionExecuting {}
extension SystemActionExecutor: SystemActionExecuting {}

final class GestureActionRouter {
    private let promptExecutor: PromptActionExecuting
    private let shortcutExecutor: ShortcutActionExecuting
    private let systemExecutor: SystemActionExecuting

    init(
        promptExecutor: PromptActionExecuting,
        shortcutExecutor: ShortcutActionExecuting,
        systemExecutor: SystemActionExecuting
    ) {
        self.promptExecutor = promptExecutor
        self.shortcutExecutor = shortcutExecutor
        self.systemExecutor = systemExecutor
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

        case .focusModeShortcut:
            let shortcutName = event.gesture == .nod ? config.nodShortcutName : config.shakeShortcutName
            return shortcutExecutor.execute(shortcutName: shortcutName)

        case .toggleDarkMode:
            return systemExecutor.execute(action: .toggleDarkMode)

        case .playPauseMedia:
            return systemExecutor.execute(action: .playPauseMedia)

        case .recenterMotion:
            recenterMotion()
            return .success("Motion recentered.")

        case .toggleControlMode:
            let isEnabled = toggleControlMode()
            return .success(isEnabled ? "Control mode enabled." : "Control mode disabled.")
        }
    }
}
