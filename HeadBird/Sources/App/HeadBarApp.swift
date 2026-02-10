import SwiftUI

@main
struct HeadBarApp: App {
    @StateObject private var model = HeadBarModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
                .frame(width: 420)
        } label: {
            MenuBarIconView(state: model.headState)
        }
        .menuBarExtraStyle(.window)
    }
}
