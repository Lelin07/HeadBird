import AppKit
import SwiftUI

struct MenuBarIconView: View {
    let state: HeadState

    var body: some View {
        Image(nsImage: symbolImage)
            .renderingMode(.template)
            .frame(width: 18, height: 18)
            .opacity(state == .asleep ? 0.6 : 1.0)
            .accessibilityLabel("HeadBar")
    }

    private var symbolImage: NSImage {
        if let custom = NSImage(named: "MenuBarIcon") {
            return custom
        }
        let names = ["airpodspro", "airpods", "headphones", "head.profile", "person.circle"]
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "HeadBar") {
                return image
            }
        }
        return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "HeadBar") ?? NSImage()
    }
}
