import SwiftUI

@main
struct FlakeApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.flakeTheme, appState.theme)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.handleScenePhaseChanged(.active)
                }
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhaseChanged(newPhase)
        }
    }
}
