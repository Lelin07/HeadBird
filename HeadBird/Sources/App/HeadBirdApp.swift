import SwiftUI

@main
struct HeadBirdApp: App {
    @StateObject private var model = HeadBirdModel()

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
