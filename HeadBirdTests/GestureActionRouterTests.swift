import XCTest
@testable import HeadBird

final class GestureActionRouterTests: XCTestCase {
    func testRoutesNodToPromptDecisionAccept() async {
        await MainActor.run {
            let prompt = PromptMock(result: .success("ok"))
            let shortcut = ShortcutMock(result: .ignored("unused"))
            let system = SystemActionMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut, systemExecutor: system)

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
            let system = SystemActionMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut, systemExecutor: system)

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
            let system = SystemActionMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut, systemExecutor: system)

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

    func testRoutesFocusModeShortcut() async {
        await MainActor.run {
            let prompt = PromptMock(result: .ignored("unused"))
            let shortcut = ShortcutMock(result: .success("focus"))
            let system = SystemActionMock(result: .ignored("unused"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut, systemExecutor: system)

            let result = router.route(
                event: HeadGestureEvent(gesture: .shake, timestamp: 1, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .promptResponse,
                    shakeAction: .focusModeShortcut,
                    nodShortcutName: "Nod Focus",
                    shakeShortcutName: "Work Focus"
                ),
                recenterMotion: {},
                toggleControlMode: { false }
            )

            XCTAssertEqual(shortcut.shortcutNames, ["Work Focus"])
            XCTAssertEqual(system.actions, [])
            XCTAssertEqual(result, .success("focus"))
        }
    }

    func testRoutesSystemPresetActions() async {
        await MainActor.run {
            let prompt = PromptMock(result: .ignored("unused"))
            let shortcut = ShortcutMock(result: .ignored("unused"))
            let system = SystemActionMock(result: .success("system"))
            let router = GestureActionRouter(promptExecutor: prompt, shortcutExecutor: shortcut, systemExecutor: system)

            let darkResult = router.route(
                event: HeadGestureEvent(gesture: .nod, timestamp: 1, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .toggleDarkMode,
                    shakeAction: .playPauseMedia,
                    nodShortcutName: "",
                    shakeShortcutName: ""
                ),
                recenterMotion: {},
                toggleControlMode: { false }
            )

            let mediaResult = router.route(
                event: HeadGestureEvent(gesture: .shake, timestamp: 2, confidence: 0.9),
                config: GestureActionRouteConfig(
                    nodAction: .toggleDarkMode,
                    shakeAction: .playPauseMedia,
                    nodShortcutName: "",
                    shakeShortcutName: ""
                ),
                recenterMotion: {},
                toggleControlMode: { false }
            )

            XCTAssertEqual(system.actions, [.toggleDarkMode, .playPauseMedia])
            XCTAssertEqual(darkResult, .success("system"))
            XCTAssertEqual(mediaResult, .success("system"))
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

private final class SystemActionMock: SystemActionExecuting {
    private let result: GestureActionResult
    private(set) var actions: [SystemGestureAction] = []

    init(result: GestureActionResult) {
        self.result = result
    }

    func execute(action: SystemGestureAction) -> GestureActionResult {
        actions.append(action)
        return result
    }
}
