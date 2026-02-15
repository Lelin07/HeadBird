import AppKit
import Combine
import CoreImage
import SwiftUI

@MainActor
final class HeadBirdAppDelegate: NSObject, NSApplicationDelegate {
    private let model = HeadBirdModel()
    private let statusBarController = StatusBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.requestRequiredPermissions()
        statusBarController.start(with: model)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.requestRequiredPermissions()
        model.refreshNow()
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private let iconProvider = MenuBarIconProvider()
    private var statusItem: NSStatusItem?
    private var model: HeadBirdModel?
    private var cancellables = Set<AnyCancellable>()

    func start(with model: HeadBirdModel) {
        guard statusItem == nil else { return }
        self.model = model
        configurePopover(with: model)
        configureContextMenu()
        configureStatusItem()
        bindModel(model)
        updateAppearance(for: model.headState)
    }

    private func configurePopover(with model: HeadBirdModel) {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(model)
                .frame(width: 420)
        )
    }

    private func configureContextMenu() {
        contextMenu.removeAllItems()

        let quitItem = NSMenuItem(title: "Quit HeadBird", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = iconProvider.templateImage()
        button.toolTip = "HeadBird"
    }

    private func bindModel(_ model: HeadBirdModel) {
        model.objectWillChange
            .sink { [weak self, weak model] _ in
                guard let self, let model else { return }
                self.updateAppearance(for: model.headState)
            }
            .store(in: &cancellables)
    }

    private func updateAppearance(for state: HeadState) {
        guard let button = statusItem?.button else { return }
        button.image = iconProvider.templateImage()
        button.alphaValue = state == .asleep ? 0.62 : 1.0

        if let model {
            button.toolTip = "\(model.statusTitle) - \(model.statusSubtitle)"
        } else {
            button.toolTip = "HeadBird"
        }
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        let isRightClick = event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if isRightClick {
            showContextMenu()
            return
        }

        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model?.requestRequiredPermissions()
            model?.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        popover.performClose(nil)
        guard let statusItem, let button = statusItem.button else { return }
        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}

@MainActor
private final class MenuBarIconProvider {
    private let ciContext = CIContext()
    private var cachedTemplateImage: NSImage?

    func templateImage() -> NSImage {
        if let cachedTemplateImage {
            return cachedTemplateImage
        }

        if let source = NSImage(named: NSImage.Name("MenuBarIconSource")),
           let template = makeTemplateImage(from: source) {
            cachedTemplateImage = template
            return template
        }

        let names = ["bird.fill", "dot.radiowaves.left.and.right", "circle"]
        for name in names {
            if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "HeadBird") {
                symbol.isTemplate = true
                cachedTemplateImage = symbol
                return symbol
            }
        }

        let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "HeadBird") ?? NSImage()
        fallback.isTemplate = true
        cachedTemplateImage = fallback
        return fallback
    }

    private func makeTemplateImage(from source: NSImage) -> NSImage? {
        var proposedRect = NSRect(origin: .zero, size: source.size)
        guard let cgSource = source.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        let inputImage = CIImage(cgImage: cgSource)

        let grayscale = inputImage.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 2.2,
                kCIInputBrightnessKey: 0.35
            ]
        )
        let alphaMask = grayscale.applyingFilter("CIMaskToAlpha")

        guard let cgImage = ciContext.createCGImage(alphaMask, from: alphaMask.extent.integral) else {
            return nil
        }

        let baseMask = NSImage(cgImage: cgImage, size: source.size)
        let finalSize = source.size
        let canvas = NSImage(size: finalSize)
        canvas.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: finalSize).fill()
        baseMask.draw(in: NSRect(origin: .zero, size: finalSize))

        // Add a circular outline to improve visibility in the menu bar.
        let inset = min(finalSize.width, finalSize.height) * 0.1
        let lineWidth = min(finalSize.width, finalSize.height) * 0.07
        let ringRect = NSRect(
            x: inset,
            y: inset,
            width: finalSize.width - (inset * 2.0),
            height: finalSize.height - (inset * 2.0)
        )
        NSColor.white.setStroke()
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = lineWidth
        ring.lineCapStyle = .round
        ring.stroke()
        canvas.unlockFocus()

        let template = NSImage(cgImage: canvas.cgImage(forProposedRect: nil, context: nil, hints: nil) ?? cgImage, size: NSSize(width: 18, height: 18))
        template.isTemplate = true
        return template
    }
}
