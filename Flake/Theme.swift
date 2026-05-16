import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}

// MARK: - App background

extension Color {
    static let flakeBG       = Color(hex: "0a0612")
    static let flakeSurface  = Color.white.opacity(0.05)
    static let flakeBorder   = Color.white.opacity(0.08)
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textMuted     = Color.white.opacity(0.45)
    static let textDimmed    = Color.white.opacity(0.35)
}

// MARK: - Theme

enum FlakeTheme: String, CaseIterable, Identifiable {
    case sunset, grape, lagoon, ember
    var id: String { rawValue }

    var g1: Color {
        switch self {
        case .sunset: return Color(hex: "ff6b9d")
        case .grape:  return Color(hex: "b56bff")
        case .lagoon: return Color(hex: "5eead4")
        case .ember:  return Color(hex: "f97316")
        }
    }
    var g2: Color {
        switch self {
        case .sunset: return Color(hex: "ff8c42")
        case .grape:  return Color(hex: "ff5e9c")
        case .lagoon: return Color(hex: "60a5fa")
        case .ember:  return Color(hex: "ef4444")
        }
    }
    var g3: Color {
        switch self {
        case .sunset: return Color(hex: "ffd166")
        case .grape:  return Color(hex: "ffb86b")
        case .lagoon: return Color(hex: "c084fc")
        case .ember:  return Color(hex: "fbbf24")
        }
    }
    var good: Color {
        switch self {
        case .sunset: return Color(hex: "66e0a3")
        case .grape:  return Color(hex: "84ffb8")
        case .lagoon: return Color(hex: "5eead4")
        case .ember:  return Color(hex: "86efac")
        }
    }
    var bad: Color { Color(hex: "ff5a7a") }

    var gradient: LinearGradient {
        LinearGradient(colors: [g1, g2, g3], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var gradient2: LinearGradient {
        LinearGradient(colors: [g1, g2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var accentGlow: Color { g1.opacity(0.4) }
}

// MARK: - Environment key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: FlakeTheme = .sunset
}
extension EnvironmentValues {
    var flakeTheme: FlakeTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Gradient text modifier

struct GradientTextModifier: ViewModifier {
    let gradient: LinearGradient
    func body(content: Content) -> some View {
        content.overlay(gradient.mask(content))
            .foregroundStyle(.clear)
    }
}

extension View {
    func gradientForeground(_ gradient: LinearGradient) -> some View {
        modifier(GradientTextModifier(gradient: gradient))
    }
}

// MARK: - Avatar colors (fixed per-initial)

let avatarColors: [String: Color] = [
    "a1": Color(hex: "ff6b9d"),
    "a2": Color(hex: "ff8c42"),
    "a3": Color(hex: "ffd166"),
    "a4": Color(hex: "5eead4"),
    "a5": Color(hex: "c084ff"),
    "a6": Color(hex: "93c5fd"),
    "a7": Color(hex: "fb7185"),
    "a8": Color(hex: "86efac"),
]

// MARK: - Fonts

extension Font {
    /// Large editorial display — uses system serif italic as Fraunces substitute
    static func display(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Monospace labels
    static func mono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
