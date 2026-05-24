import SwiftUI

/// Shown briefly at startup while AppState checks for a stored Supabase session.
/// Disappears as soon as we know whether to show the app or the auth gate.
struct SessionRestoreView: View {
    @Environment(\.flakeTheme) private var theme
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()

            // Soft glow
            RadialGradient(
                colors: [theme.g1.opacity(0.22), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("flake.")
                    .font(.display(52))
                    .italic()
                    .foregroundStyle(theme.gradient2)
                    .scaleEffect(pulsing ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsing)

                ProgressView()
                    .tint(Color.white.opacity(0.35))
            }
        }
        .onAppear { pulsing = true }
    }
}
