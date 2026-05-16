import SwiftUI

struct PillView: View {
    let status: RSVPStatus

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Text(status.label)
            .font(.mono(10, weight: .medium))
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bgColor.opacity(0.15))
            .foregroundStyle(fgColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bgColor: Color {
        switch status {
        case .lockedIn:  return theme.good
        case .sendingIt: return theme.g3
        case .flaked:    return theme.bad
        case .silent:    return .white
        }
    }
    private var fgColor: Color {
        switch status {
        case .lockedIn:  return theme.good
        case .sendingIt: return theme.g3
        case .flaked:    return theme.bad
        case .silent:    return .white.opacity(0.4)
        }
    }
}

struct EyebrowLabel: View {
    let text: String
    var color: Color = .white.opacity(0.5)

    var body: some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(radius: CGFloat = 16, padding: EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)) -> some View {
        modifier(GlassCard(cornerRadius: radius, padding: padding))
    }
}
