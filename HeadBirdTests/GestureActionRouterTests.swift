import XCTest
@testable import HeadBird

final class GestureActionRouterTests: XCTestCase {
    func testRoutesNodToPromptDecisionAccept() async {
        await MainActor.run {
            let prompt = PromptMock(result: .success("ok"))
            let shortcut = ShortcutMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut)

            let result = router.route(
                event: HeadGestureEvent(gesture: .nod, timestamp: 1, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .promptResponse,
                    shakeAction: .runShortcut,
                    nodShortcutName: "",
                    shakeShortcutName: "QuickToggle"
                ),
                recenterMotion: {},
                toggleControlMode: { false }
            )

            XCTAssertEqual(prompt.decisions, [.accept])
            XCTAssertEqual(shortcut.shortcutNames, [])
            XCTAssertEqual(result, .success("ok"))
        }
    }

    func testRoutesShakeToShortcut() async {
        await MainActor.run {
            let prompt = PromptMock(result: .ignored("unused"))
            let shortcut = ShortcutMock(result: .success("shortcut"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut)

            let result = router.route(
                event: HeadGestureEvent(gesture: .shake, timestamp: 1, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .promptResponse,
                    shakeAction: .runShortcut,
                    nodShortcutName: "A",
                    shakeShortcutName: "B"
                ),
                recenterMotion: {},
                toggleControlMode: { true }
            )

            XCTAssertEqual(shortcut.shortcutNames, ["B"])
            XCTAssertEqual(result, .success("shortcut"))
        }
    }

    func testRoutesToLocalActions() async {
        await MainActor.run {
            let prompt = PromptMock(result: .ignored("unused"))
            let shortcut = ShortcutMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut)

            var recentered = false
            var mode = false

            let recenterResult = router.route(
                event: HeadGestureEvent(gesture: .nod, timestamp: 1, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .recenterMotion,
                    shakeAction: .toggleControlMode,
                    nodShortcutName: "",
                    shakeShortcutName: ""
                ),
                recenterMotion: { recentered = true },
                toggleControlMode: {
                    mode.toggle()
                    return mode
                }
            )

            let toggleResult = router.route(
                event: HeadGestureEvent(gesture: .shake, timestamp: 2, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .recenterMotion,
                    shakeAction: .toggleControlMode,
                    nodShortcutName: "",
                    shakeShortcutName: ""
                ),
                recenterMotion: { recentered = true },
                toggleControlMode: {
                    mode.toggle()
                    return mode
                }
            )

            XCTAssertTrue(recentered)
            XCTAssertEqual(recenterResult, .success("Motion recentered."))
            XCTAssertEqual(toggleResult, .success("Control mode enabled."))
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

private final class ShortcutMock: ShortcutActionExecuting {
    private let result: GestureActionResult
    private(set) var shortcutNames: [String] = []

    init(result: GestureActionResult) {
        self.result = result
    }

    func execute(shortcutName: String) -> GestureActionResult {
        shortcutNames.append(shortcutName)
        return result
    }
}
