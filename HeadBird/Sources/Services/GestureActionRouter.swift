import Foundation

protocol PromptActionExecuting {
    func execute(decision: PromptDecision) -> GestureActionResult
}

extension PromptActionExecutor: PromptActionExecuting {}

final class GestureActionRouter {
    private let promptExecutor: PromptActionExecuting

    init(
        promptExecutor: PromptActionExecuting
    ) {
        self.promptExecutor = promptExecutor
    }

    func route(
        event: HeadGestureEvent,
        mode: GestureActionMode
    ) -> GestureActionResult {
        switch mode {
        case .promptResponses:
            let decision: PromptDecision = event.gesture == .nod ? .accept : .reject
            return promptExecutor.execute(decision: decision)
        }
    }
}
