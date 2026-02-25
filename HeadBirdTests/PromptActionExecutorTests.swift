import AppKit
import XCTest
@testable import HeadBird

nonisolated(unsafe) private var retainedMockNodes: [NSObject] = []

final class PromptActionExecutorTests: XCTestCase {
    func testPrefersFocusedApplicationOverFrontmostFallback() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let focusedApp = Self.makeElement(100)
            let frontmostApp = Self.makeElement(101)
            let focusedWindow = Self.makeElement(102)
            let frontmostWindow = Self.makeElement(103)
            let focusedAccept = Self.makeElement(104)
            let focusedReject = Self.makeElement(105)
            let frontmostAccept = Self.makeElement(106)
            let frontmostReject = Self.makeElement(107)

            driver.accessibilityTrusted = true
            driver.focusedApplication = focusedApp
            driver.frontmostApplication = frontmostApp
            driver.setApplicationProcessIdentifier(focusedApp, pid: 2100)
            driver.setApplicationProcessIdentifier(frontmostApp, pid: 2200)

            driver.setElementAttribute(element: focusedApp, attribute: kAXFocusedWindowAttribute as CFString, value: focusedWindow)
            driver.setStringAttribute(element: focusedWindow, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setElementAttribute(element: focusedWindow, attribute: kAXDefaultButtonAttribute as CFString, value: focusedAccept)
            driver.setElementAttribute(element: focusedWindow, attribute: kAXCancelButtonAttribute as CFString, value: focusedReject)

            driver.setElementAttribute(element: frontmostApp, attribute: kAXFocusedWindowAttribute as CFString, value: frontmostWindow)
            driver.setStringAttribute(element: frontmostWindow, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setElementAttribute(element: frontmostWindow, attribute: kAXDefaultButtonAttribute as CFString, value: frontmostAccept)
            driver.setElementAttribute(element: frontmostWindow, attribute: kAXCancelButtonAttribute as CFString, value: frontmostReject)

            let executor = PromptActionExecutor(driver: driver)
            let result = executor.execute(decision: .accept)

            XCTAssertEqual(result, .success("Accepted prompt"))
            XCTAssertEqual(driver.pressedElements, [focusedAccept])
        }
    }

    func testFindsTargetsFromFocusedUIElementRoot() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(200)
            let dialog = Self.makeElement(201)
            let accept = Self.makeElement(202)
            let reject = Self.makeElement(203)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3100)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: dialog)
            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setElementAttribute(element: dialog, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: dialog, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: kAXTitleAttribute as CFString, value: "OK")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .reject)

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptNameSource, .acceptButton)
            XCTAssertEqual(evaluation.targetSourceSummary, "accept=dialogAttribute, reject=dialogAttribute")
            XCTAssertEqual(result, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [reject])
        }
    }

    func testFindsTargetsFromFocusedButtonAncestorChain() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(250)
            let dialog = Self.makeElement(251)
            let group = Self.makeElement(252)
            let accept = Self.makeElement(253)
            let reject = Self.makeElement(254)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3200)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: accept)

            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")
            driver.setElementAttribute(element: accept, attribute: "AXParent" as CFString, value: group)

            driver.setStringAttribute(element: group, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setElementAttribute(element: group, attribute: "AXParent" as CFString, value: dialog)

            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setElementAttribute(element: dialog, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: dialog, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .accept)

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(evaluation.promptNameSource, .acceptButton)
            XCTAssertEqual(result, .success("Accepted prompt"))
            XCTAssertEqual(driver.pressedElements, [accept])
        }
    }

    func testFindsTargetsFromSystemWideFocusedElementWhenAppFocusedElementMissing() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(255)
            let focusedButton = Self.makeElement(256)
            let dialog = Self.makeElement(257)
            let accept = Self.makeElement(258)
            let reject = Self.makeElement(259)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3250)
            driver.systemWideFocusedUIElementValue = focusedButton

            driver.setStringAttribute(element: focusedButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: focusedButton, attribute: "AXValue" as CFString, value: "Empty Trash")
            driver.setElementAttribute(element: focusedButton, attribute: "AXParent" as CFString, value: dialog)

            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setElementAttribute(element: dialog, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: dialog, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(evaluation.promptNameSource, .acceptButton)
        }
    }

    func testFindsTargetsFromFocusedElementTopLevelUIElement() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(260)
            let focusedButton = Self.makeElement(261)
            let sheet = Self.makeElement(262)
            let accept = Self.makeElement(263)
            let reject = Self.makeElement(264)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3300)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: focusedButton)

            driver.setStringAttribute(element: focusedButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setElementAttribute(element: focusedButton, attribute: "AXTopLevelUIElement" as CFString, value: sheet)

            driver.setStringAttribute(element: sheet, attribute: kAXRoleAttribute as CFString, value: kAXSheetRole as String)
            driver.setElementAttribute(element: sheet, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: sheet, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: kAXTitleAttribute as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(evaluation.targetSourceSummary, "accept=sheetAttribute, reject=sheetAttribute")
        }
    }

    func testFindsTargetsFromFocusedElementWindowAttributeFallback() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(270)
            let focusedButton = Self.makeElement(271)
            let window = Self.makeElement(272)
            let sheet = Self.makeElement(273)
            let accept = Self.makeElement(274)
            let reject = Self.makeElement(275)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3400)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: focusedButton)
            driver.setStringAttribute(element: focusedButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setElementAttribute(element: focusedButton, attribute: "AXWindow" as CFString, value: window)

            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: "AXSheets" as CFString, value: [sheet])
            driver.setStringAttribute(element: sheet, attribute: kAXRoleAttribute as CFString, value: kAXSheetRole as String)
            driver.setElementAttribute(element: sheet, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: sheet, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let result = executor.execute(decision: .reject)

            XCTAssertEqual(result, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [reject])
        }
    }

    func testUsesHeuristicOnWindowRootWhenNoDialogOrSheetRolesExist() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(276)
            let window = Self.makeElement(277)
            let group = Self.makeElement(278)
            let reject = Self.makeElement(279)
            let accept = Self.makeElement(280)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3450)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: kAXChildrenAttribute as CFString, value: [group])

            driver.setStringAttribute(element: group, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: group, attribute: kAXChildrenAttribute as CFString, value: [reject, accept])

            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let acceptResult = executor.execute(decision: .accept)
            let rejectResult = executor.execute(decision: .reject)

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(evaluation.promptNameSource, .acceptButton)
            XCTAssertEqual(acceptResult, .success("Accepted prompt"))
            XCTAssertEqual(rejectResult, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [accept, reject])
        }
    }

    func testUsesHeuristicOnNestedPromptGroupWhenWindowHasExtraButtons() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(281)
            let window = Self.makeElement(282)
            let chromeGroup = Self.makeElement(283)
            let promptGroup = Self.makeElement(284)
            let closeButton = Self.makeElement(285)
            let miniButton = Self.makeElement(286)
            let zoomButton = Self.makeElement(287)
            let promptText = Self.makeElement(288)
            let reject = Self.makeElement(289)
            let accept = Self.makeElement(290)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3460)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: kAXChildrenAttribute as CFString, value: [chromeGroup, promptGroup])

            driver.setStringAttribute(element: chromeGroup, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: chromeGroup, attribute: kAXChildrenAttribute as CFString, value: [closeButton, miniButton, zoomButton])
            driver.setStringAttribute(element: closeButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: closeButton, attribute: kAXTitleAttribute as CFString, value: "Close")
            driver.setStringAttribute(element: miniButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: miniButton, attribute: kAXTitleAttribute as CFString, value: "Minimize")
            driver.setStringAttribute(element: zoomButton, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: zoomButton, attribute: kAXTitleAttribute as CFString, value: "Zoom")

            driver.setStringAttribute(element: promptGroup, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: promptGroup, attribute: kAXChildrenAttribute as CFString, value: [promptText, reject, accept])
            driver.setStringAttribute(element: promptText, attribute: kAXRoleAttribute as CFString, value: kAXStaticTextRole as String)
            driver.setStringAttribute(element: promptText, attribute: kAXValueAttribute as CFString, value: "Are you sure?")
            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let acceptResult = executor.execute(decision: .accept)
            let rejectResult = executor.execute(decision: .reject)

            XCTAssertTrue(evaluation.promptContextDetected)
            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(acceptResult, .success("Accepted prompt"))
            XCTAssertEqual(rejectResult, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [accept, reject])
        }
    }

    func testFindsPromptButtonsUnderSingleAXContentsElement() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(291)
            let window = Self.makeElement(292)
            let contentsGroup = Self.makeElement(293)
            let promptGroup = Self.makeElement(294)
            let text = Self.makeElement(295)
            let reject = Self.makeElement(296)
            let accept = Self.makeElement(297)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3470)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)

            // Finder/system prompts can expose the visible subtree via AXContents as a single AXUIElement.
            driver.setElementAttribute(element: window, attribute: "AXContents" as CFString, value: contentsGroup)
            driver.setStringAttribute(element: contentsGroup, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: contentsGroup, attribute: kAXChildrenAttribute as CFString, value: [promptGroup])

            driver.setStringAttribute(element: promptGroup, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: promptGroup, attribute: kAXChildrenAttribute as CFString, value: [text, reject, accept])
            driver.setStringAttribute(element: text, attribute: kAXRoleAttribute as CFString, value: kAXStaticTextRole as String)
            driver.setStringAttribute(element: text, attribute: kAXValueAttribute as CFString, value: "Are you sure?")
            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let acceptResult = executor.execute(decision: .accept)
            let rejectResult = executor.execute(decision: .reject)

            XCTAssertTrue(evaluation.promptContextDetected)
            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(acceptResult, .success("Accepted prompt"))
            XCTAssertEqual(rejectResult, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [accept, reject])
        }
    }

    func testFindsPromptButtonsViaAXChildrenInNavigationOrder() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(298)
            let window = Self.makeElement(299)
            let promptGroup = Self.makeElement(300)
            let text = Self.makeElement(301)
            let reject = Self.makeElement(302)
            let accept = Self.makeElement(303)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3475)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: "AXChildrenInNavigationOrder" as CFString, value: [promptGroup])

            driver.setStringAttribute(element: promptGroup, attribute: kAXRoleAttribute as CFString, value: "AXGroup")
            driver.setArrayAttribute(element: promptGroup, attribute: kAXChildrenAttribute as CFString, value: [text, reject, accept])
            driver.setStringAttribute(element: text, attribute: kAXRoleAttribute as CFString, value: kAXStaticTextRole as String)
            driver.setStringAttribute(element: text, attribute: kAXValueAttribute as CFString, value: "Are you sure?")
            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()

            XCTAssertTrue(evaluation.promptContextDetected)
            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
        }
    }

    func testCurrentPromptDebugSnapshotIncludesAttributeNamesAndTrace() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(304)
            let dialog = Self.makeElement(305)
            let accept = Self.makeElement(306)
            let reject = Self.makeElement(307)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 3480)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: dialog)
            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setElementAttribute(element: dialog, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: dialog, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: kAXTitleAttribute as CFString, value: "OK")
            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")

            let executor = PromptActionExecutor(driver: driver)
            let capture = executor.currentPromptDebugCapture()

            XCTAssertTrue(capture.evaluation.promptContextDetected)
            XCTAssertNotNil(capture.evaluation.promptSignature)
            XCTAssertFalse(capture.snapshot.nodes.isEmpty)
            XCTAssertFalse(capture.snapshot.resolverTrace.roots.isEmpty)
            XCTAssertTrue(capture.snapshot.formattedText.contains("Resolver Trace"))
        }
    }

    func testFindsTargetsFromWindowsListWhenFocusedWindowIsMissing() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(300)
            let window = Self.makeElement(301)
            let sheet = Self.makeElement(302)
            let accept = Self.makeElement(303)
            let reject = Self.makeElement(304)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 4100)
            driver.setArrayAttribute(element: app, attribute: "AXWindows" as CFString, value: [window])
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: "AXSheets" as CFString, value: [sheet])
            driver.setStringAttribute(element: sheet, attribute: kAXRoleAttribute as CFString, value: kAXSheetRole as String)
            driver.setElementAttribute(element: sheet, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: sheet, attribute: kAXCancelButtonAttribute as CFString, value: reject)

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .accept)

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(result, .success("Accepted prompt"))
            XCTAssertEqual(driver.pressedElements, [accept])
        }
    }

    func testUsesHeuristicForFinderLikeTwoButtonPromptIncludingAXValue() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(400)
            let window = Self.makeElement(401)
            let dialog = Self.makeElement(402)
            let reject = Self.makeElement(403)
            let accept = Self.makeElement(404)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 5100)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: kAXChildrenAttribute as CFString, value: [dialog])
            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setArrayAttribute(element: dialog, attribute: kAXChildrenAttribute as CFString, value: [reject, accept])

            driver.setStringAttribute(element: reject, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: reject, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: accept, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: accept, attribute: "AXValue" as CFString, value: "Empty Trash")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let acceptResult = executor.execute(decision: .accept)
            let rejectResult = executor.execute(decision: .reject)

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptName, "Empty Trash")
            XCTAssertEqual(evaluation.promptNameSource, .acceptButton)
            XCTAssertEqual(evaluation.targetSourceSummary, "accept=heuristic, reject=heuristic")
            XCTAssertEqual(acceptResult, .success("Accepted prompt"))
            XCTAssertEqual(rejectResult, .success("Rejected prompt"))
            XCTAssertEqual(driver.pressedElements, [accept, reject])
        }
    }

    func testPromptNameFallsBackToStaticTextWhenButtonLabelMissing() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(450)
            let dialog = Self.makeElement(451)
            let text = Self.makeElement(452)
            let accept = Self.makeElement(453)
            let reject = Self.makeElement(454)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 5200)
            driver.setElementAttribute(element: app, attribute: "AXFocusedUIElement" as CFString, value: dialog)
            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setElementAttribute(element: dialog, attribute: kAXDefaultButtonAttribute as CFString, value: accept)
            driver.setElementAttribute(element: dialog, attribute: kAXCancelButtonAttribute as CFString, value: reject)
            driver.setArrayAttribute(element: dialog, attribute: kAXChildrenAttribute as CFString, value: [text, accept, reject])

            driver.setStringAttribute(element: text, attribute: kAXRoleAttribute as CFString, value: kAXStaticTextRole as String)
            driver.setStringAttribute(element: text, attribute: kAXValueAttribute as CFString, value: "Are you sure you want to permanently erase the items in the Trash?")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()

            XCTAssertEqual(evaluation.capabilities, PromptTargetCapabilities(canAccept: true, canReject: true))
            XCTAssertEqual(evaluation.promptNameSource, .staticText)
            XCTAssertNotNil(evaluation.promptName)
            XCTAssertEqual(
                evaluation.promptName,
                "Are you sure you want to permanently erase the items in the Trash?"
            )
        }
    }

    func testRefusesAmbiguousMultiButtonHeuristicPrompt() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(500)
            let window = Self.makeElement(501)
            let dialog = Self.makeElement(502)
            let cancel = Self.makeElement(503)
            let emptyTrash = Self.makeElement(504)
            let keep = Self.makeElement(505)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 6100)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)
            driver.setArrayAttribute(element: window, attribute: kAXChildrenAttribute as CFString, value: [dialog])
            driver.setStringAttribute(element: dialog, attribute: kAXRoleAttribute as CFString, value: "AXDialog")
            driver.setArrayAttribute(element: dialog, attribute: kAXChildrenAttribute as CFString, value: [cancel, emptyTrash, keep])

            driver.setStringAttribute(element: cancel, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: cancel, attribute: kAXTitleAttribute as CFString, value: "Cancel")
            driver.setStringAttribute(element: emptyTrash, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: emptyTrash, attribute: kAXTitleAttribute as CFString, value: "Empty Trash")
            driver.setStringAttribute(element: keep, attribute: kAXRoleAttribute as CFString, value: kAXButtonRole as String)
            driver.setStringAttribute(element: keep, attribute: kAXTitleAttribute as CFString, value: "Keep")

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .accept)

            XCTAssertEqual(evaluation.capabilities, .none)
            XCTAssertEqual(evaluation.debugMessage, "No actionable prompt buttons found.")
            XCTAssertEqual(result, .ignored("No prompt target"))
            XCTAssertTrue(driver.pressedElements.isEmpty)
        }
    }

    func testReturnsIgnoredWhenNoPromptTarget() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(600)
            let window = Self.makeElement(601)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 7100)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .accept)

            XCTAssertEqual(evaluation.capabilities, .none)
            XCTAssertEqual(evaluation.debugMessage, "No actionable prompt buttons found.")
            XCTAssertEqual(result, .ignored("No prompt target"))
            XCTAssertTrue(driver.pressedElements.isEmpty)
        }
    }

    func testReturnsFailureWhenAccessibilityIsDenied() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            driver.accessibilityTrusted = false

            let executor = PromptActionExecutor(driver: driver)
            let evaluation = executor.currentPromptTargetEvaluation()
            let result = executor.execute(decision: .reject)

            XCTAssertEqual(evaluation.capabilities, .none)
            XCTAssertEqual(evaluation.debugMessage, "Accessibility permission required.")
            XCTAssertEqual(result, .failure("Accessibility permission is required for prompt control."))
        }
    }

    func testDoesNotFallbackToGlobalKeysWhenNoTargetExists() async {
        await MainActor.run {
            let driver = PromptAXDriverMock()
            let app = Self.makeElement(700)
            let window = Self.makeElement(701)

            driver.accessibilityTrusted = true
            driver.focusedApplication = app
            driver.setApplicationProcessIdentifier(app, pid: 8100)
            driver.setElementAttribute(element: app, attribute: kAXFocusedWindowAttribute as CFString, value: window)
            driver.setStringAttribute(element: window, attribute: kAXRoleAttribute as CFString, value: kAXWindowRole as String)

            let executor = PromptActionExecutor(driver: driver)
            let result = executor.execute(decision: .reject)

            XCTAssertEqual(result, .ignored("No prompt target"))
            XCTAssertTrue(driver.pressedElements.isEmpty)
        }
    }

    private static func makeElement(_ pid: pid_t) -> AXUIElement {
        _ = pid
        let node = NSObject()
        retainedMockNodes.append(node)
        return unsafeBitCast(node, to: AXUIElement.self)
    }
}

private final class PromptAXDriverMock: PromptAXDriving {
    var accessibilityTrusted: Bool = true
    var focusedApplication: AXUIElement?
    var frontmostApplication: AXUIElement?
    var systemWideFocusedUIElementValue: AXUIElement?
    var systemWideFocusedWindowValue: AXUIElement?
    var currentProcessID: pid_t = 999_999
    var pressedElements: [AXUIElement] = []

    private var elementAttributes: [ElementAttributeKey: AXUIElement] = [:]
    private var arrayAttributes: [ElementAttributeKey: [AXUIElement]] = [:]
    private var stringAttributes: [ElementAttributeKey: String] = [:]
    private var attributeNamesByElement: [UInt: Set<String>] = [:]
    private var enabledStates: [UInt: Bool] = [:]
    private var appProcessIdentifiers: [UInt: pid_t] = [:]

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        accessibilityTrusted
    }

    func focusedApplicationElement() -> AXUIElement? {
        focusedApplication
    }

    func frontmostApplicationElement() -> AXUIElement? {
        frontmostApplication
    }

    func systemWideFocusedUIElement() -> AXUIElement? {
        systemWideFocusedUIElementValue
    }

    func systemWideFocusedWindowElement() -> AXUIElement? {
        systemWideFocusedWindowValue
    }

    func copyElementAttribute(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        elementAttributes[ElementAttributeKey(element: element, attribute: attribute)]
    }

    func copyElementArrayAttribute(from element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        arrayAttributes[ElementAttributeKey(element: element, attribute: attribute)] ?? []
    }

    func copyStringAttribute(from element: AXUIElement, attribute: CFString) -> String? {
        stringAttributes[ElementAttributeKey(element: element, attribute: attribute)]
    }

    func copyAttributeNames(from element: AXUIElement) -> [String] {
        let elementID = elementIdentifier(element)
        return Array(attributeNamesByElement[elementID] ?? []).sorted()
    }

    func isElementEnabled(_ element: AXUIElement) -> Bool? {
        enabledStates[elementIdentifier(element)]
    }

    func performPress(on element: AXUIElement) -> Bool {
        pressedElements.append(element)
        return true
    }

    func processIdentifier(of applicationElement: AXUIElement) -> pid_t? {
        appProcessIdentifiers[elementIdentifier(applicationElement)]
    }

    func currentProcessIdentifier() -> pid_t {
        currentProcessID
    }

    func setElementAttribute(element: AXUIElement, attribute: CFString, value: AXUIElement) {
        elementAttributes[ElementAttributeKey(element: element, attribute: attribute)] = value
        recordAttributeName(element: element, attribute: attribute)
    }

    func setArrayAttribute(element: AXUIElement, attribute: CFString, value: [AXUIElement]) {
        arrayAttributes[ElementAttributeKey(element: element, attribute: attribute)] = value
        recordAttributeName(element: element, attribute: attribute)
    }

    func setStringAttribute(element: AXUIElement, attribute: CFString, value: String) {
        stringAttributes[ElementAttributeKey(element: element, attribute: attribute)] = value
        recordAttributeName(element: element, attribute: attribute)
    }

    func setEnabledState(element: AXUIElement, enabled: Bool) {
        enabledStates[elementIdentifier(element)] = enabled
    }

    func setApplicationProcessIdentifier(_ app: AXUIElement, pid: pid_t) {
        appProcessIdentifiers[elementIdentifier(app)] = pid
    }

    private func elementIdentifier(_ element: AXUIElement) -> UInt {
        UInt(CFHash(element))
    }

    private func recordAttributeName(element: AXUIElement, attribute: CFString) {
        let id = elementIdentifier(element)
        var names = attributeNamesByElement[id] ?? []
        names.insert(attribute as String)
        attributeNamesByElement[id] = names
    }
}

private struct ElementAttributeKey: Hashable {
    let elementID: UInt
    let attribute: String

    init(element: AXUIElement, attribute: CFString) {
        self.elementID = UInt(CFHash(element))
        self.attribute = attribute as String
    }
}
