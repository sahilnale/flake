import SwiftUI

@main
struct FlakeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.flakeTheme, appState.theme)
                .preferredColorScheme(.dark)
        }
    }
}
