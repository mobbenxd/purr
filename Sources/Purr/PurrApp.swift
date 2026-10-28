import SwiftUI

@main
struct PurrApp: App {
    @StateObject private var model = PurrModel()

    var body: some Scene {
        MenuBarExtra {
            PurrPanel()
                .environmentObject(model)
        } label: {
            Image(nsImage: CatFace.menuBarImage(busy: model.isRunning))
        }
        .menuBarExtraStyle(.window)
    }
}
