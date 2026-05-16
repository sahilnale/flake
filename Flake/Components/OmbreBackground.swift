import SwiftUI

enum OmbreStyle {
    case top, split, center, celebrate
}

struct OmbreBackground: View {
    var style: OmbreStyle = .top
    var opacity: Double = 0.85

    @Environment(\.flakeTheme) private var t

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch style {
                case .top:
                    RadialGradient(colors: [t.g1.opacity(0.9), .clear], center: .init(x: 0.5, y: -0.1), startRadius: 0, endRadius: geo.size.width * 0.8)
                    RadialGradient(colors: [t.g2.opacity(0.7), .clear], center: .init(x: 0.8, y: 0),    startRadius: 0, endRadius: geo.size.width * 0.7)
                    RadialGradient(colors: [t.g3.opacity(0.6), .clear], center: .init(x: 0.2, y: 0.05), startRadius: 0, endRadius: geo.size.width * 0.6)

                case .split:
                    RadialGradient(colors: [t.g1.opacity(0.7), .clear], center: .topLeading,    startRadius: 0, endRadius: geo.size.width * 0.8)
                    RadialGradient(colors: [t.g2.opacity(0.7), .clear], center: .bottomTrailing, startRadius: 0, endRadius: geo.size.width * 0.8)

                case .center:
                    RadialGradient(colors: [t.g2.opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: geo.size.width * 0.75)

                case .celebrate:
                    RadialGradient(colors: [t.g1.opacity(0.8), .clear], center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: geo.size.width * 0.9)
                    RadialGradient(colors: [t.g3.opacity(0.6), .clear], center: .init(x: 0.2, y: 0.9), startRadius: 0, endRadius: geo.size.width * 0.7)
                    RadialGradient(colors: [t.g2.opacity(0.6), .clear], center: .init(x: 0.9, y: 0.8), startRadius: 0, endRadius: geo.size.width * 0.7)
                }

                // Fade edges
                RadialGradient(colors: [.clear, Color.flakeBG], center: .center, startRadius: geo.size.width * 0.5, endRadius: geo.size.width * 1.1)
            }
            .blur(radius: 20)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
    }
}
