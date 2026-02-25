import AppKit
import ApplicationServices
import Foundation

nonisolated(unsafe) private let axSheetsAttribute = "AXSheets" as CFString
private let axDialogRole = "AXDialog"
nonisolated(unsafe) private let axFocusedUIElementAttribute = "AXFocusedUIElement" as CFString
nonisolated(unsafe) private let axWindowsAttribute = "AXWindows" as CFString
nonisolated(unsafe) private let axFocusedApplicationAttribute = "AXFocusedApplication" as CFString
nonisolated(unsafe) private let axValueAttribute = "AXValue" as CFString
nonisolated(unsafe) private let axIdentifierAttribute = "AXIdentifier" as CFString
nonisolated(unsafe) private let axParentAttribute = "AXParent" as CFString
nonisolated(unsafe) private let axTopLevelUIElementAttribute = "AXTopLevelUIElement" as CFString
nonisolated(unsafe) private let axWindowAttribute = "AXWindow" as CFString
nonisolated(unsafe) private let axVisibleChildrenAttribute = "AXVisibleChildren" as CFString
nonisolated(unsafe) private let axContentsAttribute = "AXContents" as CFString
nonisolated(unsafe) private let axChildrenInNavigationOrderAttribute = "AXChildrenInNavigationOrder" as CFString
nonisolated(unsafe) private let axRowsAttribute = "AXRows" as CFString
nonisolated(unsafe) private let axSelectedChildrenAttribute = "AXSelectedChildren" as CFString
nonisolated(unsafe) private let axLinkedUIElementsAttribute = "AXLinkedUIElements" as CFString
nonisolated(unsafe) private let axLabelUIElementsAttribute = "AXLabelUIElements" as CFString
nonisolated(unsafe) private let axTitleUIElementAttribute = "AXTitleUIElement" as CFString
nonisolated(unsafe) private let axButtonsAttribute = "AXButtons" as CFString
nonisolated(unsafe) private let axLabelAttribute = "AXLabel" as CFString

enum PromptDebugFailureReason: String, Equatable, Sendable {
    case accessibilityPermissionRequired
    case noFocusedAppContext
    case noFocusedPromptContainer
    case noActionablePromptButtons
    case ambiguousButtons
    case unknown
}

struct PromptAXResolverRootTrace: Equatable, Sendable {
    let source: PromptTargetSource
    let elementID: UInt
    let role: String?
}

struct PromptAXResolverButtonCandidateTrace: Equatable, Sendable {
    let elementID: UInt
    let role: String?
    let title: String
    let normalizedTitle: String
    let enabled: Bool?
}

struct PromptAXResolverTrace: Equatable, Sendable {
    let appSelection: String
    let roots: [PromptAXResolverRootTrace]
    let promptContextDetected: Bool
    let buttonCandidates: [PromptAXResolverButtonCandidateTrace]
    let rejectionReasons: [String]
    let finalResolution: String
    let failureReason: PromptDebugFailureReason?
}

struct PromptAXDebugNode: Equatable, Sendable {
    let elementID: UInt
    let depth: Int
    let viaAttribute: String?
    let role: String?
    let subrole: String?
    let title: String?
    let value: String?
    let detailDescription: String?
    let label: String?
    let identifier: String?
    let enabled: Bool?
    let attributeNames: [String]
}

struct PromptAXDebugEdge: Equatable, Sendable {
    let fromElementID: UInt
    let toElementID: UInt
    let attribute: String
}

struct PromptAXDebugSnapshot: Equatable, Sendable {
    let capturedAt: Date
    let appProcessIdentifier: pid_t?
    let appSelectionMessage: String
    let promptSignature: String?
    let evaluationDebugMessage: String
    let promptName: String?
    let promptContextDetected: Bool
    let capabilities: PromptTargetCapabilities
    let rootsCount: Int
    let promptLikeContainerCount: Int
    let buttonCandidateCount: Int
    let failureReason: PromptDebugFailureReason?
    let nodes: [PromptAXDebugNode]
    let edges: [PromptAXDebugEdge]
    let resolverTrace: PromptAXResolverTrace

    var formattedText: String {
        var lines: [String] = []
        lines.append("HeadBird Prompt AX Snapshot")
        lines.append("capturedAt=\(capturedAt)")
        lines.append("appPID=\(appProcessIdentifier.map(String.init) ?? "nil")")
        lines.append("promptSignature=\(promptSignature ?? "nil")")
        lines.append("promptContextDetected=\(promptContextDetected)")
        lines.append("capabilities=accept:\(capabilities.canAccept) reject:\(capabilities.canReject)")
        lines.append("promptName=\(promptName ?? "nil")")
        lines.append("evaluation=\(evaluationDebugMessage)")
        if let failureReason {
            lines.append("failureReason=\(failureReason.rawValue)")
        }
        lines.append("rootsCount=\(rootsCount) promptLikeContainers=\(promptLikeContainerCount) buttonCandidates=\(buttonCandidateCount)")
        lines.append("")
        lines.append("[Resolver Trace]")
        lines.append("appSelection: \(resolverTrace.appSelection)")
        lines.append("promptContextDetected: \(resolverTrace.promptContextDetected)")
        if resolverTrace.roots.isEmpty {
            lines.append("roots: none")
        } else {
            for root in resolverTrace.roots {
                lines.append("root: id=\(root.elementID) source=\(root.source.rawValue) role=\(root.role ?? "nil")")
            }
        }
        if resolverTrace.buttonCandidates.isEmpty == false {
            for button in resolverTrace.buttonCandidates {
                lines.append("button: id=\(button.elementID) role=\(button.role ?? "nil") enabled=\(button.enabled.map(String.init) ?? "nil") title=\(button.title)")
            }
        }
        if resolverTrace.rejectionReasons.isEmpty == false {
            lines.append("rejections:")
            for reason in resolverTrace.rejectionReasons {
                lines.append("- \(reason)")
            }
        }
        lines.append("finalResolution: \(resolverTrace.finalResolution)")
        lines.append("")
        lines.append("[AX Nodes]")
        for node in nodes {
            let indent = String(repeating: "  ", count: min(node.depth, 7))
            lines.append("\(indent)- id=\(node.elementID) via=\(node.viaAttribute ?? "root") role=\(node.role ?? "nil") subrole=\(node.subrole ?? "nil") title=\(node.title ?? "nil") value=\(node.value ?? "nil") label=\(node.label ?? "nil") identifier=\(node.identifier ?? "nil") enabled=\(node.enabled.map(String.init) ?? "nil") attrs=\(node.attributeNames.joined(separator: ","))")
        }
        if edges.isEmpty == false {
            lines.append("")
            lines.append("[AX Edges]")
            for edge in edges {
                lines.append("- \(edge.fromElementID) --\(edge.attribute)--> \(edge.toElementID)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct PromptTargetDebugCapture: Equatable, Sendable {
    let evaluation: PromptTargetEvaluation
    let snapshot: PromptAXDebugSnapshot
}

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

struct PromptTargetEvaluation: Equatable, Sendable {
    let promptContextDetected: Bool
    let capabilities: PromptTargetCapabilities
    let debugMessage: String
    let promptName: String?
    let promptSignature: String?
    let promptNameSource: PromptNameSource
    let targetSourceSummary: String?
}

enum PromptTargetSource: String, Equatable, Sendable {
    case windowAttribute
    case sheetAttribute
    case dialogAttribute
    case heuristic
}

enum PromptNameSource: String, Equatable, Sendable {
    case acceptButton
    case containerTitle
    case staticText
    case unknown
}

protocol PromptAXDriving {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
    func focusedApplicationElement() -> AXUIElement?
    func frontmostApplicationElement() -> AXUIElement?
    func systemWideFocusedUIElement() -> AXUIElement?
    func systemWideFocusedWindowElement() -> AXUIElement?
    func copyElementAttribute(from element: AXUIElement, attribute: CFString) -> AXUIElement?
    func copyElementArrayAttribute(from element: AXUIElement, attribute: CFString) -> [AXUIElement]
    func copyStringAttribute(from element: AXUIElement, attribute: CFString) -> String?
    func copyAttributeNames(from element: AXUIElement) -> [String]
    func isElementEnabled(_ element: AXUIElement) -> Bool?
    func performPress(on element: AXUIElement) -> Bool
    func processIdentifier(of applicationElement: AXUIElement) -> pid_t?
    func currentProcessIdentifier() -> pid_t
}

private final class LivePromptAXDriver: PromptAXDriving {
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    func focusedApplicationElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return copyElementAttribute(from: systemWide, attribute: axFocusedApplicationAttribute)
    }

    func frontmostApplicationElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    func systemWideFocusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return copyElementAttribute(from: systemWide, attribute: axFocusedUIElementAttribute)
    }

    func systemWideFocusedWindowElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return copyElementAttribute(from: systemWide, attribute: kAXFocusedWindowAttribute as CFString)
    }

    func copyElementAttribute(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        guard let value = copyAttributeValue(from: element, attribute: attribute) else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    func copyElementArrayAttribute(from element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        guard let value = copyAttributeValue(from: element, attribute: attribute) else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    func copyStringAttribute(from element: AXUIElement, attribute: CFString) -> String? {
        guard let value = copyAttributeValue(from: element, attribute: attribute) else {
            return nil
        }
        if let stringValue = value as? String {
            return stringValue
        }
        return nil
    }

    func copyAttributeNames(from element: AXUIElement) -> [String] {
        var value: CFArray?
        let status = AXUIElementCopyAttributeNames(element, &value)
        guard status == .success, let value else {
            return []
        }
        return (value as? [String]) ?? []
    }

    func isElementEnabled(_ element: AXUIElement) -> Bool? {
        guard let value = copyAttributeValue(from: element, attribute: kAXEnabledAttribute as CFString) else {
            return nil
        }
        if let boolValue = value as? Bool {
            return boolValue
        }
        return nil
    }

    func performPress(on element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    func processIdentifier(of applicationElement: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        let status = AXUIElementGetPid(applicationElement, &pid)
        guard status == .success else {
            return nil
        }
        return pid
    }

    func currentProcessIdentifier() -> pid_t {
        ProcessInfo.processInfo.processIdentifier
    }

    private func copyAttributeValue(from element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else {
            return nil
        }
        return value
    }
}

final class PromptActionExecutor {
    private let driver: PromptAXDriving

    init(driver: PromptAXDriving = LivePromptAXDriver()) {
        self.driver = driver
    }

    func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        driver.isAccessibilityTrusted(prompt: prompt)
    }

    func currentPromptTargetEvaluation() -> PromptTargetEvaluation {
        let bundle = resolveCurrentPromptTargets()
        let resolution = bundle.resolution
        return PromptTargetEvaluation(
            promptContextDetected: resolution.promptContextDetected,
            capabilities: resolution.capabilities,
            debugMessage: resolution.debugMessage,
            promptName: resolution.promptName,
            promptSignature: resolution.promptSignature,
            promptNameSource: resolution.promptNameSource,
            targetSourceSummary: resolution.targetSourceSummary
        )
    }

    func currentPromptTargetEvaluation(includeDebugSnapshot: Bool) -> PromptTargetEvaluation {
        if includeDebugSnapshot {
            return currentPromptDebugCapture().evaluation
        }
        return currentPromptTargetEvaluation()
    }

    func currentPromptDebugSnapshot() -> PromptAXDebugSnapshot {
        currentPromptDebugCapture().snapshot
    }

    func currentPromptDebugCapture() -> PromptTargetDebugCapture {
        let bundle = resolveCurrentPromptTargets()
        let evaluation = PromptTargetEvaluation(
            promptContextDetected: bundle.resolution.promptContextDetected,
            capabilities: bundle.resolution.capabilities,
            debugMessage: bundle.resolution.debugMessage,
            promptName: bundle.resolution.promptName,
            promptSignature: bundle.resolution.promptSignature,
            promptNameSource: bundle.resolution.promptNameSource,
            targetSourceSummary: bundle.resolution.targetSourceSummary
        )
        let snapshot = buildDebugSnapshot(from: bundle)
        return PromptTargetDebugCapture(evaluation: evaluation, snapshot: snapshot)
    }

    func currentPromptTargetCapabilities() -> PromptTargetCapabilities {
        currentPromptTargetEvaluation().capabilities
    }

    func execute(decision: PromptDecision) -> GestureActionResult {
        guard driver.isAccessibilityTrusted(prompt: false) else {
            return .failure("Accessibility permission is required for prompt control.")
        }

        let resolution = resolveCurrentPromptTargets().resolution
        guard let target = target(for: decision, in: resolution) else {
            return .ignored("No prompt target")
        }

        return driver.performPress(on: target.element)
            ? .success(message(for: decision))
            : .failure("Couldn't control the current prompt.")
    }

    private func message(for decision: PromptDecision) -> String {
        switch decision {
        case .accept:
            return "Accepted prompt"
        case .reject:
            return "Rejected prompt"
        }
    }

    private struct PromptResolvedTarget {
        let element: AXUIElement
        let source: PromptTargetSource
        let confidence: Double
    }

    private struct PromptTargetResolution {
        var accept: PromptResolvedTarget?
        var reject: PromptResolvedTarget?
        var debugMessage: String
        var promptContextDetected: Bool
        var promptName: String?
        var promptSignature: String?
        var promptNameSource: PromptNameSource
        var targetSourceSummary: String?
        var failureReason: PromptDebugFailureReason?

        var capabilities: PromptTargetCapabilities {
            PromptTargetCapabilities(canAccept: accept != nil, canReject: reject != nil)
        }
    }

    private struct PromptRoot {
        let element: AXUIElement
        let source: PromptTargetSource
    }

    private struct TargetApplicationContext {
        let element: AXUIElement?
        let debugMessage: String
        let processIdentifier: pid_t?
    }

    private struct PromptResolutionBundle {
        let appContext: TargetApplicationContext
        let roots: [PromptRoot]
        let resolution: PromptTargetResolution
    }

    private struct ButtonCandidate {
        let element: AXUIElement
        let normalizedTitle: String
    }

    private let maxDialogSearchDepth = 4
    private let maxButtonSearchDepth = 6
    private let maxPromptLikeContainerDepth = 6
    private let maxParentChainDepth = 8
    private let minHeuristicConfidence = 0.72

    private let rejectTokens = [
        "cancel",
        "dont",
        "donot",
        "no",
        "notnow",
        "deny",
        "decline",
        "abort",
        "close",
        "keep",
        "stay"
    ]

    private let acceptTokens = [
        "ok",
        "okay",
        "yes",
        "allow",
        "continue",
        "open",
        "save",
        "delete",
        "remove",
        "erase",
        "replace",
        "emptytrash",
        "move"
    ]

    private func resolveCurrentPromptTargets() -> PromptResolutionBundle {
        guard driver.isAccessibilityTrusted(prompt: false) else {
            return PromptResolutionBundle(
                appContext: TargetApplicationContext(
                    element: nil,
                    debugMessage: "Accessibility permission required.",
                    processIdentifier: nil
                ),
                roots: [],
                resolution: PromptTargetResolution(
                    accept: nil,
                    reject: nil,
                    debugMessage: "Accessibility permission required.",
                    promptContextDetected: false,
                    promptName: nil,
                    promptSignature: nil,
                    promptNameSource: .unknown,
                    targetSourceSummary: nil,
                    failureReason: .accessibilityPermissionRequired
                )
            )
        }

        let appContext = resolveTargetApplicationElement()
        guard let appElement = appContext.element else {
            return PromptResolutionBundle(
                appContext: appContext,
                roots: [],
                resolution: PromptTargetResolution(
                    accept: nil,
                    reject: nil,
                    debugMessage: appContext.debugMessage,
                    promptContextDetected: false,
                    promptName: nil,
                    promptSignature: nil,
                    promptNameSource: .unknown,
                    targetSourceSummary: nil,
                    failureReason: .noFocusedAppContext
                )
            )
        }

        let roots = promptRoots(in: appElement)
        guard roots.isEmpty == false else {
            return PromptResolutionBundle(
                appContext: appContext,
                roots: [],
                resolution: PromptTargetResolution(
                    accept: nil,
                    reject: nil,
                    debugMessage: "No focused prompt container.",
                    promptContextDetected: false,
                    promptName: nil,
                    promptSignature: nil,
                    promptNameSource: .unknown,
                    targetSourceSummary: nil,
                    failureReason: .noFocusedPromptContainer
                )
            )
        }

        var resolution = resolveUsingRootAttributes(roots: roots)
        resolution.promptContextDetected = detectPromptContext(in: roots)
        resolution = resolveUsingDescendantAttributes(roots: roots, current: resolution)
        resolution = resolveUsingHeuristicButtons(roots: roots, current: resolution)
        let promptNameInfo = promptNameInfo(for: resolution, roots: roots)
        resolution.promptName = promptNameInfo.name
        resolution.promptNameSource = promptNameInfo.source
        resolution.targetSourceSummary = targetSourceSummary(for: resolution)
        resolution.promptSignature = promptSignature(
            appProcessIdentifier: appContext.processIdentifier,
            roots: roots,
            resolution: resolution
        )

        if resolution.capabilities.hasAnyTarget {
            resolution.debugMessage = finalDebugMessage(for: resolution)
            resolution.failureReason = nil
        } else if resolution.debugMessage.isEmpty {
            resolution.debugMessage = "No actionable prompt buttons found."
            resolution.failureReason = .noActionablePromptButtons
        }

        return PromptResolutionBundle(appContext: appContext, roots: roots, resolution: resolution)
    }

    private func resolveTargetApplicationElement() -> TargetApplicationContext {
        let focusedApplication = driver.focusedApplicationElement()
        if let focusedApplication, !isCurrentProcessApplication(focusedApplication) {
            return TargetApplicationContext(
                element: focusedApplication,
                debugMessage: "Prompt target ready.",
                processIdentifier: driver.processIdentifier(of: focusedApplication)
            )
        }

        let frontmostApplication = driver.frontmostApplicationElement()
        if let frontmostApplication, !isCurrentProcessApplication(frontmostApplication) {
            return TargetApplicationContext(
                element: frontmostApplication,
                debugMessage: "Prompt target ready.",
                processIdentifier: driver.processIdentifier(of: frontmostApplication)
            )
        }

        if let focusedApplication, isCurrentProcessApplication(focusedApplication) {
            return TargetApplicationContext(
                element: nil,
                debugMessage: "HeadBird popover is focused. Focus the prompt dialog.",
                processIdentifier: driver.processIdentifier(of: focusedApplication)
            )
        }
        if let frontmostApplication, isCurrentProcessApplication(frontmostApplication) {
            return TargetApplicationContext(
                element: nil,
                debugMessage: "HeadBird is frontmost. Focus the prompt dialog.",
                processIdentifier: driver.processIdentifier(of: frontmostApplication)
            )
        }

        return TargetApplicationContext(element: nil, debugMessage: "No focused app context.", processIdentifier: nil)
    }

    private func isCurrentProcessApplication(_ applicationElement: AXUIElement) -> Bool {
        guard let appPID = driver.processIdentifier(of: applicationElement) else {
            return false
        }
        return appPID == driver.currentProcessIdentifier()
    }

    private func promptRoots(in appElement: AXUIElement) -> [PromptRoot] {
        var roots: [PromptRoot] = []

        if let systemWideFocusedUIElement = driver.systemWideFocusedUIElement() {
            roots.append(contentsOf: promptRoots(fromFocusedElement: systemWideFocusedUIElement))
        }

        if let focusedUIElement = driver.copyElementAttribute(from: appElement, attribute: axFocusedUIElementAttribute) {
            roots.append(contentsOf: promptRoots(fromFocusedElement: focusedUIElement))
        }

        if let systemWideFocusedWindow = driver.systemWideFocusedWindowElement() {
            roots.append(PromptRoot(element: systemWideFocusedWindow, source: source(for: systemWideFocusedWindow, fallback: .windowAttribute)))
        }

        if let focusedWindow = driver.copyElementAttribute(from: appElement, attribute: kAXFocusedWindowAttribute as CFString) {
            roots.append(PromptRoot(element: focusedWindow, source: source(for: focusedWindow, fallback: .windowAttribute)))
        }

        if let mainWindow = driver.copyElementAttribute(from: appElement, attribute: kAXMainWindowAttribute as CFString) {
            roots.append(PromptRoot(element: mainWindow, source: source(for: mainWindow, fallback: .windowAttribute)))
        }

        let windows = driver.copyElementArrayAttribute(from: appElement, attribute: axWindowsAttribute)
        for window in windows {
            roots.append(PromptRoot(element: window, source: source(for: window, fallback: .windowAttribute)))
        }

        let baseWindowRoots = roots.filter { $0.source == .windowAttribute }
        for root in baseWindowRoots {
            let sheets = driver.copyElementArrayAttribute(from: root.element, attribute: axSheetsAttribute)
            for sheet in sheets {
                roots.append(PromptRoot(element: sheet, source: .sheetAttribute))
            }

            let dialogDescendants = collectDescendants(
                of: root.element,
                maxDepth: maxDialogSearchDepth,
                matchingRoles: [kAXSheetRole as String, axDialogRole]
            )
            for dialog in dialogDescendants {
                roots.append(PromptRoot(element: dialog, source: source(for: dialog, fallback: .dialogAttribute)))
            }
        }

        return deduplicatedRoots(roots)
    }

    private func promptRoots(fromFocusedElement focusedElement: AXUIElement) -> [PromptRoot] {
        var roots: [PromptRoot] = []

        let parentChain = ancestorChain(of: focusedElement, maxDepth: maxParentChainDepth)
        let promptAncestor = parentChain.first(where: { isPromptContainerRoleElement($0) })
        let topLevelUIElement = driver.copyElementAttribute(from: focusedElement, attribute: axTopLevelUIElementAttribute)
        let elementWindow = driver.copyElementAttribute(from: focusedElement, attribute: axWindowAttribute)

        if let topLevelUIElement {
            roots.append(PromptRoot(element: topLevelUIElement, source: source(for: topLevelUIElement, fallback: .dialogAttribute)))
        }

        if let promptAncestor {
            roots.append(PromptRoot(element: promptAncestor, source: source(for: promptAncestor, fallback: .dialogAttribute)))
        }

        if let elementWindow {
            roots.append(PromptRoot(element: elementWindow, source: source(for: elementWindow, fallback: .windowAttribute)))
        }

        roots.append(PromptRoot(element: focusedElement, source: source(for: focusedElement, fallback: .dialogAttribute)))

        for ancestor in parentChain {
            let fallback: PromptTargetSource = .dialogAttribute
            roots.append(PromptRoot(element: ancestor, source: source(for: ancestor, fallback: fallback)))
        }

        return deduplicatedRoots(roots)
    }

    private func ancestorChain(of element: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        guard maxDepth > 0 else { return [] }

        var chain: [AXUIElement] = []
        var current: AXUIElement? = element
        var visited = Set<UInt>([elementIdentifier(element)])

        for _ in 0..<maxDepth {
            guard let currentElement = current else { break }
            guard let parent = driver.copyElementAttribute(from: currentElement, attribute: axParentAttribute) else {
                break
            }
            let identifier = elementIdentifier(parent)
            if visited.contains(identifier) {
                break
            }
            visited.insert(identifier)
            chain.append(parent)
            current = parent
        }

        return chain
    }

    private func isPromptContainerRoleElement(_ element: AXUIElement) -> Bool {
        guard let role = driver.copyStringAttribute(from: element, attribute: kAXRoleAttribute as CFString) else {
            return false
        }
        return role == kAXSheetRole as String || role == axDialogRole || role == kAXWindowRole as String
    }

    private func resolveUsingRootAttributes(roots: [PromptRoot]) -> PromptTargetResolution {
        var resolution = PromptTargetResolution(
            accept: nil,
            reject: nil,
            debugMessage: "",
            promptContextDetected: false,
            promptName: nil,
            promptSignature: nil,
            promptNameSource: .unknown,
            targetSourceSummary: nil,
            failureReason: nil
        )

        for root in roots {
            if resolution.accept == nil,
               let target = driver.copyElementAttribute(from: root.element, attribute: kAXDefaultButtonAttribute as CFString) {
                resolution.accept = PromptResolvedTarget(element: target, source: root.source, confidence: 1.0)
            }

            if resolution.reject == nil,
               let target = driver.copyElementAttribute(from: root.element, attribute: kAXCancelButtonAttribute as CFString) {
                resolution.reject = PromptResolvedTarget(element: target, source: root.source, confidence: 1.0)
            }

            if resolution.accept != nil && resolution.reject != nil {
                return resolution
            }
        }

        return resolution
    }

    private func resolveUsingDescendantAttributes(
        roots: [PromptRoot],
        current: PromptTargetResolution
    ) -> PromptTargetResolution {
        var resolution = current
        guard resolution.accept == nil || resolution.reject == nil else {
            return resolution
        }

        for root in roots {
            let containers = collectDescendants(
                of: root.element,
                maxDepth: maxDialogSearchDepth,
                matchingRoles: [kAXSheetRole as String, axDialogRole]
            )

            for container in containers {
                let containerSource = source(for: container, fallback: .dialogAttribute)
                if resolution.accept == nil,
                   let target = driver.copyElementAttribute(from: container, attribute: kAXDefaultButtonAttribute as CFString) {
                    resolution.accept = PromptResolvedTarget(element: target, source: containerSource, confidence: 1.0)
                }

                if resolution.reject == nil,
                   let target = driver.copyElementAttribute(from: container, attribute: kAXCancelButtonAttribute as CFString) {
                    resolution.reject = PromptResolvedTarget(element: target, source: containerSource, confidence: 1.0)
                }

                if resolution.accept != nil && resolution.reject != nil {
                    return resolution
                }
            }
        }

        return resolution
    }

    private func resolveUsingHeuristicButtons(
        roots: [PromptRoot],
        current: PromptTargetResolution
    ) -> PromptTargetResolution {
        var resolution = current
        guard resolution.accept == nil || resolution.reject == nil else {
            return resolution
        }

        for root in roots {
            let containers = heuristicContainers(for: root)
            for container in containers {
                let buttons = collectButtonCandidates(in: container)
                guard buttons.count == 2 else {
                    if buttons.count > 2, resolution.capabilities == .none {
                        resolution.failureReason = .ambiguousButtons
                    }
                    continue
                }
                resolution.promptContextDetected = true

                let heuristic = heuristicTargets(from: buttons)
                if heuristic.accept == nil && heuristic.reject == nil && resolution.capabilities == .none {
                    resolution.failureReason = .ambiguousButtons
                }
                if resolution.reject == nil {
                    resolution.reject = heuristic.reject
                }
                if resolution.accept == nil {
                    resolution.accept = heuristic.accept
                }

                if resolution.accept != nil && resolution.reject != nil {
                    return resolution
                }
            }
        }

        return resolution
    }

    private func heuristicContainers(for root: PromptRoot) -> [AXUIElement] {
        if root.source != .windowAttribute {
            return [root.element]
        }

        let dialogDescendants = collectDescendants(
            of: root.element,
            maxDepth: maxDialogSearchDepth,
            matchingRoles: [kAXSheetRole as String, axDialogRole]
        )
        let sheets = driver.copyElementArrayAttribute(from: root.element, attribute: axSheetsAttribute)
        let promptContainers = deduplicatedElements(sheets + dialogDescendants)
        if promptContainers.isEmpty {
            // Some system prompts are AXWindow + nested AXGroup (no AXDialog/AXSheet role).
            // Prefer prompt-like descendants first so titlebar/window chrome buttons do not pollute the heuristic.
            let promptLikeDescendants = promptLikeHeuristicContainers(in: root.element)
            if promptLikeDescendants.isEmpty == false {
                return promptLikeDescendants
            }
            // Final fallback keeps compatibility with simpler window-root prompts.
            return [root.element]
        }
        return promptContainers
    }

    private func heuristicTargets(from buttons: [ButtonCandidate]) -> (accept: PromptResolvedTarget?, reject: PromptResolvedTarget?) {
        let rejectMatches = buttons.filter { containsAnyToken($0.normalizedTitle, tokens: rejectTokens) }
        let acceptMatches = buttons.filter { containsAnyToken($0.normalizedTitle, tokens: acceptTokens) }

        guard rejectMatches.count <= 1, acceptMatches.count <= 1 else {
            return (nil, nil)
        }

        var rejectTarget: PromptResolvedTarget?
        var acceptTarget: PromptResolvedTarget?

        if rejectMatches.count == 1 {
            rejectTarget = PromptResolvedTarget(element: rejectMatches[0].element, source: .heuristic, confidence: 0.90)
        }

        if acceptMatches.count == 1,
           rejectMatches.first.map({ !isSameElement($0.element, acceptMatches[0].element) }) ?? true {
            acceptTarget = PromptResolvedTarget(element: acceptMatches[0].element, source: .heuristic, confidence: 0.88)
        }

        if let rejectTarget, acceptTarget == nil,
           let inferred = buttons.first(where: { !isSameElement($0.element, rejectTarget.element) }) {
            acceptTarget = PromptResolvedTarget(element: inferred.element, source: .heuristic, confidence: 0.74)
        }

        if let acceptTarget, rejectTarget == nil,
           let inferred = buttons.first(where: { !isSameElement($0.element, acceptTarget.element) }) {
            rejectTarget = PromptResolvedTarget(element: inferred.element, source: .heuristic, confidence: 0.74)
        }

        return (acceptTarget, rejectTarget)
    }

    private func collectButtonCandidates(in root: AXUIElement) -> [ButtonCandidate] {
        let buttons = collectDescendants(of: root, maxDepth: maxButtonSearchDepth, matchingRoles: [kAXButtonRole as String])
        var candidates: [ButtonCandidate] = []
        candidates.reserveCapacity(buttons.count)

        for button in buttons {
            if let isEnabled = driver.isElementEnabled(button), !isEnabled {
                continue
            }

            let title = buttonTitle(for: button)
            guard title.isEmpty == false else {
                continue
            }

            candidates.append(
                ButtonCandidate(
                    element: button,
                    normalizedTitle: normalize(title)
                )
            )
        }

        return deduplicatedButtons(candidates)
    }

    private func promptLikeHeuristicContainers(in windowRoot: AXUIElement) -> [AXUIElement] {
        var candidates: [(element: AXUIElement, score: Int)] = []
        var seen = Set<UInt>()

        let groupLikeRoles = [
            "AXGroup",
            "AXLayoutArea",
            "AXScrollArea",
            "AXSplitGroup",
            "AXUnknown",
            kAXWindowRole as String
        ]

        let containers = collectDescendants(of: windowRoot, maxDepth: maxPromptLikeContainerDepth, matchingRoles: groupLikeRoles)
        for container in containers {
            let id = elementIdentifier(container)
            guard !seen.contains(id) else { continue }
            seen.insert(id)

            guard let score = promptLikeContainerScore(for: container) else {
                continue
            }
            candidates.append((container, score))
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return elementIdentifier(lhs.element) < elementIdentifier(rhs.element)
            }
            .map(\.element)
    }

    private func promptLikeContainerScore(for element: AXUIElement) -> Int? {
        let buttons = collectButtonCandidates(in: element)
        guard (2...4).contains(buttons.count) else {
            return nil
        }

        let staticTextCount = collectDescendants(
            of: element,
            maxDepth: 4,
            matchingRoles: [kAXStaticTextRole as String]
        ).count
        guard staticTextCount >= 1 else {
            return nil
        }

        let rejectMatchCount = buttons.filter { containsAnyToken($0.normalizedTitle, tokens: rejectTokens) }.count
        let acceptMatchCount = buttons.filter { containsAnyToken($0.normalizedTitle, tokens: acceptTokens) }.count

        var score = 0
        if buttons.count == 2 { score += 30 } else if buttons.count == 3 { score += 20 } else { score += 10 }
        score += min(staticTextCount, 3) * 5
        if rejectMatchCount == 1 { score += 20 }
        if acceptMatchCount == 1 { score += 15 }
        if rejectMatchCount > 1 || acceptMatchCount > 1 { score -= 10 }

        return score
    }

    private func collectDescendants(
        of root: AXUIElement,
        maxDepth: Int,
        matchingRoles roles: [String]
    ) -> [AXUIElement] {
        guard maxDepth > 0 else {
            return []
        }

        var matches: [AXUIElement] = []
        var queue: [(element: AXUIElement, depth: Int)] = [(root, 0)]
        var visited = Set<UInt>()

        while let current = queue.first {
            queue.removeFirst()
            let identifier = elementIdentifier(current.element)
            if visited.contains(identifier) {
                continue
            }
            visited.insert(identifier)

            if current.depth > 0,
               let role = driver.copyStringAttribute(from: current.element, attribute: kAXRoleAttribute as CFString),
               roles.contains(role) {
                matches.append(current.element)
            }

            if current.depth >= maxDepth {
                continue
            }

            let nextChildren = descendantChildren(of: current.element)
            for child in nextChildren {
                queue.append((child, current.depth + 1))
            }
        }

        return matches
    }

    private func descendantChildren(of element: AXUIElement) -> [AXUIElement] {
        var collected: [AXUIElement] = []

        let staticArrayAttributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            axVisibleChildrenAttribute,
            axChildrenInNavigationOrderAttribute,
            axContentsAttribute,
            axSheetsAttribute,
            axRowsAttribute,
            axSelectedChildrenAttribute,
            axLinkedUIElementsAttribute,
            axLabelUIElementsAttribute,
            axButtonsAttribute
        ]

        var seenAttributeNames = Set<String>()
        for attribute in staticArrayAttributes {
            seenAttributeNames.insert(attribute as String)
            collected.append(contentsOf: driver.copyElementArrayAttribute(from: element, attribute: attribute))
        }

        let staticSingleElementAttributes: [CFString] = [
            axContentsAttribute,
            axTitleUIElementAttribute
        ]
        for attribute in staticSingleElementAttributes {
            seenAttributeNames.insert(attribute as String)
            if let child = driver.copyElementAttribute(from: element, attribute: attribute) {
                collected.append(child)
            }
        }

        for attributeName in dynamicTraversalAttributeNames(for: element) where !seenAttributeNames.contains(attributeName) {
            let attribute = attributeName as CFString
            collected.append(contentsOf: driver.copyElementArrayAttribute(from: element, attribute: attribute))
            if let child = driver.copyElementAttribute(from: element, attribute: attribute) {
                collected.append(child)
            }
        }

        return deduplicatedElements(collected)
    }

    private func dynamicTraversalAttributeNames(for element: AXUIElement) -> [String] {
        let attributes = driver.copyAttributeNames(from: element)
        guard attributes.isEmpty == false else { return [] }

        return attributes.filter { name in
            guard name.hasPrefix("AX") else { return false }
            if name == (kAXParentAttribute as String) { return false }
            if name == (kAXFocusedWindowAttribute as String) { return false }
            if name == (kAXMainWindowAttribute as String) { return false }
            if name == (kAXFocusedUIElementAttribute as String) { return false }
            if name == (kAXDefaultButtonAttribute as String) { return false }
            if name == (kAXCancelButtonAttribute as String) { return false }

            let likelyRelationship =
                name.contains("Children") ||
                name.contains("Contents") ||
                name.contains("UIElement") ||
                name.contains("Buttons") ||
                name.contains("Rows") ||
                name.contains("Cells") ||
                name.contains("Items") ||
                name.contains("Elements") ||
                name.contains("Groups")
            return likelyRelationship
        }
    }

    private func source(for element: AXUIElement, fallback: PromptTargetSource) -> PromptTargetSource {
        guard let role = driver.copyStringAttribute(from: element, attribute: kAXRoleAttribute as CFString) else {
            return fallback
        }
        if role == kAXSheetRole as String {
            return .sheetAttribute
        }
        if role == kAXWindowRole as String {
            return .windowAttribute
        }
        if role == axDialogRole {
            return .dialogAttribute
        }
        return fallback
    }

    private func buttonTitle(for element: AXUIElement) -> String {
        if let title = driver.copyStringAttribute(from: element, attribute: kAXTitleAttribute as CFString), !title.isEmpty {
            return title
        }
        if let description = driver.copyStringAttribute(from: element, attribute: kAXDescriptionAttribute as CFString), !description.isEmpty {
            return description
        }
        if let value = driver.copyStringAttribute(from: element, attribute: axValueAttribute), !value.isEmpty {
            return value
        }
        if let identifier = driver.copyStringAttribute(from: element, attribute: axIdentifierAttribute), !identifier.isEmpty {
            return identifier
        }
        if let label = driver.copyStringAttribute(from: element, attribute: axLabelAttribute), !label.isEmpty {
            return label
        }
        let labelText = collectDescendants(of: element, maxDepth: 2, matchingRoles: [kAXStaticTextRole as String])
            .compactMap { driver.copyStringAttribute(from: $0, attribute: kAXValueAttribute as CFString) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
        if let labelText {
            return labelText
        }
        return ""
    }

    private func promptNameInfo(
        for resolution: PromptTargetResolution,
        roots: [PromptRoot]
    ) -> (name: String?, source: PromptNameSource) {
        if let accept = resolution.accept,
           let acceptTitle = sanitizedPromptName(buttonTitle(for: accept.element)) {
            return (acceptTitle, .acceptButton)
        }

        for root in roots {
            if let title = promptContainerTitleInfo(for: root.element) {
                return title
            }
        }

        return (nil, .unknown)
    }

    private func promptContainerTitleInfo(for element: AXUIElement) -> (String, PromptNameSource)? {
        if let ownTitle = sanitizedPromptName(
            firstNonEmptyStringAttribute(
                of: element,
                attributes: [kAXTitleAttribute as CFString, kAXDescriptionAttribute as CFString, axValueAttribute]
            )
        ) {
            return (ownTitle, .containerTitle)
        }

        let textDescendants = collectDescendants(
            of: element,
            maxDepth: 3,
            matchingRoles: [kAXStaticTextRole as String]
        )
        for textElement in textDescendants {
            if let candidate = sanitizedPromptName(
                firstNonEmptyStringAttribute(
                    of: textElement,
                    attributes: [kAXValueAttribute as CFString, kAXTitleAttribute as CFString, kAXDescriptionAttribute as CFString]
                )
            ) {
                return (candidate, .staticText)
            }
        }

        return nil
    }

    private func firstNonEmptyStringAttribute(of element: AXUIElement, attributes: [CFString]) -> String? {
        for attribute in attributes {
            if let value = driver.copyStringAttribute(from: element, attribute: attribute),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private func sanitizedPromptName(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if value.count > 80 {
            value = String(value.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }

    private func targetSourceSummary(for resolution: PromptTargetResolution) -> String? {
        var components: [String] = []
        if let accept = resolution.accept {
            components.append("accept=\(accept.source.rawValue)")
        }
        if let reject = resolution.reject {
            components.append("reject=\(reject.source.rawValue)")
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private func detectPromptContext(in roots: [PromptRoot]) -> Bool {
        if roots.contains(where: { $0.source == .sheetAttribute || $0.source == .dialogAttribute }) {
            return true
        }

        let windowRoots = roots.filter { $0.source == .windowAttribute }
        for root in windowRoots {
            if promptLikeHeuristicContainers(in: root.element).isEmpty == false {
                return true
            }
            let buttonCount = collectDescendants(
                of: root.element,
                maxDepth: 4,
                matchingRoles: [kAXButtonRole as String]
            ).count
            let staticTextCount = collectDescendants(
                of: root.element,
                maxDepth: 4,
                matchingRoles: [kAXStaticTextRole as String]
            ).count
            if (1...4).contains(buttonCount), staticTextCount >= 1 {
                return true
            }
        }

        return false
    }

    private func target(for decision: PromptDecision, in resolution: PromptTargetResolution) -> PromptResolvedTarget? {
        let selectedTarget: PromptResolvedTarget?
        switch decision {
        case .accept:
            selectedTarget = resolution.accept
        case .reject:
            selectedTarget = resolution.reject
        }

        guard let selectedTarget else {
            return nil
        }
        guard selectedTarget.source != .heuristic || selectedTarget.confidence >= minHeuristicConfidence else {
            return nil
        }
        return selectedTarget
    }

    private func finalDebugMessage(for resolution: PromptTargetResolution) -> String {
        let capabilities = resolution.capabilities
        if capabilities.canAccept && capabilities.canReject {
            return "Prompt target ready."
        }
        if capabilities.canAccept {
            return "Only accept target found in frontmost prompt."
        }
        if capabilities.canReject {
            return "Only reject target found in frontmost prompt."
        }
        return "No actionable prompt buttons found."
    }

    private func promptSignature(
        appProcessIdentifier: pid_t?,
        roots: [PromptRoot],
        resolution: PromptTargetResolution
    ) -> String? {
        guard resolution.promptContextDetected else { return nil }
        let appPart = appProcessIdentifier.map(String.init) ?? "na"
        let rootPart = roots.prefix(4)
            .map { "\($0.source.rawValue):\(elementIdentifier($0.element))" }
            .joined(separator: "|")
        let namePart = normalize(resolution.promptName ?? resolution.debugMessage)
        let capabilityPart = "a\(resolution.capabilities.canAccept ? 1 : 0)r\(resolution.capabilities.canReject ? 1 : 0)"
        let raw = [appPart, rootPart, namePart, capabilityPart].joined(separator: "::")
        return raw.isEmpty ? nil : raw
    }

    private func buildDebugSnapshot(from bundle: PromptResolutionBundle) -> PromptAXDebugSnapshot {
        let buttonCandidateTraces = collectButtonCandidateTraces(for: bundle.roots)
        let promptLikeContainerCount = bundle.roots
            .filter { $0.source == .windowAttribute }
            .reduce(0) { partialResult, root in
                partialResult + promptLikeHeuristicContainers(in: root.element).count
            }
        let debugTree = debugNodesAndEdges(for: bundle.roots)
        let failureReason = inferredFailureReason(for: bundle.resolution)
        let trace = PromptAXResolverTrace(
            appSelection: bundle.appContext.debugMessage,
            roots: bundle.roots.map {
                PromptAXResolverRootTrace(
                    source: $0.source,
                    elementID: elementIdentifier($0.element),
                    role: driver.copyStringAttribute(from: $0.element, attribute: kAXRoleAttribute as CFString)
                )
            },
            promptContextDetected: bundle.resolution.promptContextDetected,
            buttonCandidates: buttonCandidateTraces,
            rejectionReasons: debugRejectionReasons(bundle: bundle, buttonCandidates: buttonCandidateTraces),
            finalResolution: bundle.resolution.targetSourceSummary ?? bundle.resolution.debugMessage,
            failureReason: failureReason
        )

        return PromptAXDebugSnapshot(
            capturedAt: Date(),
            appProcessIdentifier: bundle.appContext.processIdentifier,
            appSelectionMessage: bundle.appContext.debugMessage,
            promptSignature: bundle.resolution.promptSignature,
            evaluationDebugMessage: bundle.resolution.debugMessage,
            promptName: bundle.resolution.promptName,
            promptContextDetected: bundle.resolution.promptContextDetected,
            capabilities: bundle.resolution.capabilities,
            rootsCount: bundle.roots.count,
            promptLikeContainerCount: promptLikeContainerCount,
            buttonCandidateCount: buttonCandidateTraces.count,
            failureReason: failureReason,
            nodes: debugTree.nodes,
            edges: debugTree.edges,
            resolverTrace: trace
        )
    }

    private func collectButtonCandidateTraces(for roots: [PromptRoot]) -> [PromptAXResolverButtonCandidateTrace] {
        var traces: [PromptAXResolverButtonCandidateTrace] = []
        var seen = Set<UInt>()

        for root in roots {
            for container in heuristicContainers(for: root) {
                let buttons = collectDescendants(of: container, maxDepth: maxButtonSearchDepth, matchingRoles: [kAXButtonRole as String])
                for button in buttons {
                    let id = elementIdentifier(button)
                    guard seen.insert(id).inserted else { continue }
                    let title = buttonTitle(for: button)
                    traces.append(
                        PromptAXResolverButtonCandidateTrace(
                            elementID: id,
                            role: driver.copyStringAttribute(from: button, attribute: kAXRoleAttribute as CFString),
                            title: sanitizedDebugText(title) ?? "",
                            normalizedTitle: normalize(title),
                            enabled: driver.isElementEnabled(button)
                        )
                    )
                }
            }
        }

        return traces
    }

    private func debugRejectionReasons(
        bundle: PromptResolutionBundle,
        buttonCandidates: [PromptAXResolverButtonCandidateTrace]
    ) -> [String] {
        var reasons: [String] = []
        let resolution = bundle.resolution
        if !resolution.promptContextDetected {
            reasons.append("Prompt context not detected in current roots.")
        }
        if buttonCandidates.isEmpty {
            reasons.append("No heuristic AXButton candidates were found in prompt-scoped containers.")
        }
        let disabledCount = buttonCandidates.filter { $0.enabled == false }.count
        if disabledCount > 0 {
            reasons.append("\(disabledCount) button candidate(s) were disabled.")
        }
        let unnamedCount = buttonCandidates.filter { $0.title.isEmpty }.count
        if unnamedCount > 0 {
            reasons.append("\(unnamedCount) button candidate(s) had no readable label.")
        }
        if resolution.capabilities == .none && buttonCandidates.count > 2 {
            reasons.append("Heuristic intentionally skipped ambiguous prompt with >2 button candidates.")
        }
        if resolution.capabilities == .none && resolution.debugMessage.isEmpty == false {
            reasons.append(resolution.debugMessage)
        }
        return reasons
    }

    private func inferredFailureReason(for resolution: PromptTargetResolution) -> PromptDebugFailureReason? {
        if resolution.capabilities.hasAnyTarget {
            return nil
        }
        if let failureReason = resolution.failureReason {
            return failureReason
        }
        if resolution.debugMessage.contains("Accessibility permission") {
            return .accessibilityPermissionRequired
        }
        if resolution.debugMessage.contains("No focused app context") || resolution.debugMessage.contains("HeadBird") {
            return .noFocusedAppContext
        }
        if resolution.debugMessage.contains("No focused prompt container") {
            return .noFocusedPromptContainer
        }
        if resolution.debugMessage.contains("No actionable") {
            return .noActionablePromptButtons
        }
        return .unknown
    }

    private func debugNodesAndEdges(for roots: [PromptRoot]) -> (nodes: [PromptAXDebugNode], edges: [PromptAXDebugEdge]) {
        let maxNodes = 120
        let maxDepth = 7

        var nodes: [PromptAXDebugNode] = []
        var edges: [PromptAXDebugEdge] = []
        var queue: [(element: AXUIElement, depth: Int, via: String?)] = roots.map { ($0.element, 0, Optional<String>("root:\($0.source.rawValue)")) }
        var visited = Set<UInt>()

        while let current = queue.first, nodes.count < maxNodes {
            queue.removeFirst()
            let id = elementIdentifier(current.element)
            if !visited.insert(id).inserted {
                continue
            }

            let role = driver.copyStringAttribute(from: current.element, attribute: kAXRoleAttribute as CFString)
            let subrole = driver.copyStringAttribute(from: current.element, attribute: kAXSubroleAttribute as CFString)
            let attributes = Array(driver.copyAttributeNames(from: current.element).prefix(40))
            let isSecureText = (subrole?.localizedCaseInsensitiveContains("secure") ?? false)
                || ((role == kAXTextFieldRole as String) && (subrole?.localizedCaseInsensitiveContains("password") ?? false))

            let rawValue = driver.copyStringAttribute(from: current.element, attribute: axValueAttribute)
            let maskedValue = isSecureText ? "<redacted>" : rawValue

            nodes.append(
                PromptAXDebugNode(
                    elementID: id,
                    depth: current.depth,
                    viaAttribute: current.via,
                    role: sanitizedDebugText(role),
                    subrole: sanitizedDebugText(subrole),
                    title: sanitizedDebugText(driver.copyStringAttribute(from: current.element, attribute: kAXTitleAttribute as CFString)),
                    value: sanitizedDebugText(maskedValue),
                    detailDescription: sanitizedDebugText(driver.copyStringAttribute(from: current.element, attribute: kAXDescriptionAttribute as CFString)),
                    label: sanitizedDebugText(driver.copyStringAttribute(from: current.element, attribute: axLabelAttribute)),
                    identifier: sanitizedDebugText(driver.copyStringAttribute(from: current.element, attribute: axIdentifierAttribute)),
                    enabled: driver.isElementEnabled(current.element),
                    attributeNames: attributes
                )
            )

            guard current.depth < maxDepth else { continue }
            for childRef in debugTraversalChildren(of: current.element) {
                let childID = elementIdentifier(childRef.element)
                edges.append(PromptAXDebugEdge(fromElementID: id, toElementID: childID, attribute: childRef.attribute))
                queue.append((childRef.element, current.depth + 1, childRef.attribute))
            }
        }

        return (nodes: nodes, edges: edges)
    }

    private func debugTraversalChildren(of element: AXUIElement) -> [(attribute: String, element: AXUIElement)] {
        var refs: [(attribute: String, element: AXUIElement)] = []
        var seen = Set<UInt>()

        let prioritizedAttributes = [
            kAXChildrenAttribute as String,
            axVisibleChildrenAttribute as String,
            axChildrenInNavigationOrderAttribute as String,
            axContentsAttribute as String,
            axSheetsAttribute as String,
            axRowsAttribute as String,
            axSelectedChildrenAttribute as String,
            axLinkedUIElementsAttribute as String,
            axLabelUIElementsAttribute as String,
            axTitleUIElementAttribute as String,
            axButtonsAttribute as String
        ]

        let dynamicAttributes = dynamicTraversalAttributeNames(for: element)
        for attributeName in deduplicateStrings(prioritizedAttributes + dynamicAttributes) {
            let attribute = attributeName as CFString
            for child in driver.copyElementArrayAttribute(from: element, attribute: attribute) {
                let id = elementIdentifier(child)
                if seen.insert(id).inserted {
                    refs.append((attributeName, child))
                }
            }
            if let child = driver.copyElementAttribute(from: element, attribute: attribute) {
                let id = elementIdentifier(child)
                if seen.insert(id).inserted {
                    refs.append((attributeName, child))
                }
            }
        }

        return refs
    }

    private func deduplicateStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        output.reserveCapacity(values.count)
        for value in values where seen.insert(value).inserted {
            output.append(value)
        }
        return output
    }

    private func sanitizedDebugText(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if value.count > 120 {
            value = String(value.prefix(120))
        }
        return value
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func containsAnyToken(_ text: String, tokens: [String]) -> Bool {
        tokens.contains(where: { text.contains($0) })
    }

    private func deduplicatedRoots(_ roots: [PromptRoot]) -> [PromptRoot] {
        var seen = Set<UInt>()
        var deduplicated: [PromptRoot] = []
        deduplicated.reserveCapacity(roots.count)

        for root in roots {
            let identifier = elementIdentifier(root.element)
            if seen.insert(identifier).inserted {
                deduplicated.append(root)
            }
        }

        return deduplicated
    }

    private func deduplicatedButtons(_ buttons: [ButtonCandidate]) -> [ButtonCandidate] {
        var seen = Set<UInt>()
        var deduplicated: [ButtonCandidate] = []
        deduplicated.reserveCapacity(buttons.count)

        for button in buttons {
            let identifier = elementIdentifier(button.element)
            if seen.insert(identifier).inserted {
                deduplicated.append(button)
            }
        }

        return deduplicated
    }

    private func deduplicatedElements(_ elements: [AXUIElement]) -> [AXUIElement] {
        var seen = Set<UInt>()
        var deduplicated: [AXUIElement] = []
        deduplicated.reserveCapacity(elements.count)

        for element in elements {
            let identifier = elementIdentifier(element)
            if seen.insert(identifier).inserted {
                deduplicated.append(element)
            }
        }

        return deduplicated
    }

    private func elementIdentifier(_ element: AXUIElement) -> UInt {
        UInt(CFHash(element))
    }

    private func isSameElement(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
        CFEqual(lhs, rhs)
    }
}
