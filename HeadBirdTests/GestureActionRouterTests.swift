import XCTest
@testable import HeadBird

final class GestureActionRouterTests: XCTestCase {
    func testRoutesNodToPromptDecisionAccept() async {
        await MainActor.run {
            let prompt = PromptMock(result: .success("ok"))
            let router = GestureActionRouter(promptExecutor: prompt)

            let result = router.route(
                event: HeadGestureEvent(gesture: .nod, timestamp: 1, confidence: 0.9),
                mode: .promptResponses
            )

            XCTAssertEqual(prompt.decisions, [.accept])
            XCTAssertEqual(result, .success("ok"))
        }
    }

    func testRoutesShakeToPromptDecisionReject() async {
        await MainActor.run {
            let prompt = PromptMock(result: .success("ok"))
            let router = GestureActionRouter(promptExecutor: prompt)

            let result = router.route(
                event: HeadGestureEvent(gesture: .shake, timestamp: 1, confidence: 0.9),
                mode: .promptResponses
            )

            XCTAssertEqual(prompt.decisions, [.reject])
            XCTAssertEqual(result, .success("ok"))
        }
    }

}

private final class PromptMock: PromptActionExecuting {
    private let result: GestureActionResult
    private(set) var decisions: [PromptDecision] = []

    init(result: GestureActionResult) {
        self.result = result
    }

    func execute(decision: PromptDecision) -> GestureActionResult {
        decisions.append(decision)
        return result
    }
}
