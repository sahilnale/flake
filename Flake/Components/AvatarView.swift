import SwiftUI

struct AvatarView: View {
    let initials: String
    let colorHex: String
    var size: CGFloat = 32
    var isYou: Bool = false

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ZStack {
            if isYou {
                theme.gradient2
            } else {
                Color(hex: colorHex)
            }
            Text(initials)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(isYou ? 0 : 0.1), lineWidth: 1))
    }
}

struct AvatarStack: View {
    let members: [Member]
    var maxVisible: Int = 4
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(members.prefix(maxVisible))) { m in
                AvatarView(initials: m.initials, colorHex: m.avatarColorHex, size: size)
                    .overlay(Circle().stroke(Color.flakeBG, lineWidth: 2))
            }
            if members.count > maxVisible {
                Text("+\(members.count - maxVisible)")
                    .font(.mono(10))
                    .foregroundStyle(.textMuted)
                    .padding(.leading, 6)
            }
        }
    }
}
