import AppKit
import SwiftUI

@main
struct HeadBirdApp: App {
    @NSApplicationDelegateAdaptor(HeadBirdAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
