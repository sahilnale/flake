import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    private var user: Member {
        state.activeLeaderboardMembers.first { $0.id == state.currentUserID } ?? state.currentUser
    }

    private var joinedString: String {
        guard let date = state.currentUser.joinedAt ?? state.backendProfile?.createdAt else {
            return ""
        }
        let f = DateFormatter()
        f.dateFormat = "MMM ''yy"
        return " · joined \(f.string(from: date).lowercased())"
    }

    private var seasonLabel: String {
        "season \(String(format: "%02d", state.selectedGroup?.season ?? 1)) · to the crown"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .top).frame(height: 350)

                VStack(spacing: 0) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 96, height: 96)
                            .shadow(color: theme.g1.opacity(0.35), radius: 24, y: 8)
                        Text(user.initials)
                            .font(.display(36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 18)

                    Text(user.name)
                        .font(.display(44))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)
                    Text(user.handle + joinedString)
                        .font(.mono(12))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.bottom, 22)

                    // Tagline
                    Text("\u{201C}\(user.tagline)\u{201D}")
                        .font(.system(size: 19, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)

                    // Stat grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatCard(number: String(format: "%02d", state.selectedGroup?.userRank ?? 4),
                                 label: "season rank", isAccent: true, isGradient: true)
                        StatCard(number: "\(user.score)", label: "points")
                        StatCard(number: "\(max(0, 100 - Int(user.showRate * 100)))%", label: "flake rate")
                        StatCard(number: "\(user.showCount)", label: "total shows")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // Season meter
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(seasonLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                            Spacer()
                            Text("\(user.score) / \(state.selectedGroup?.userScoreGoal ?? 300)")
                                .font(.mono(12))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.gradient)
                                    .frame(width: g.size.width * min(1, Double(user.score) / Double(state.selectedGroup?.userScoreGoal ?? 300)), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // Badges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("cabinet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        if user.badges.isEmpty {
                            Text("no badges yet. show up and earn them.")
                                .font(.system(size: 13))
                                .italic()
                                .foregroundStyle(Color.white.opacity(0.3))
                        } else {
                            FlowLayout(spacing: 6) {
                                ForEach(user.badges, id: \.name) { badge in
                                    BadgeChip(name: badge.name, isGold: badge.isGold)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.featureScreen = .recap
                        }
                    } label: {
                        HStack {
                            Text("view season recap")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text("→")
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                    if state.authStatus == .signedIn {
                        Button {
                            Task { await state.signOut() }
                        } label: {
                            Text("sign out")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 0)
                        .padding(.bottom, 120)
                }
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let number: String
    let label: String
    var isAccent: Bool = false
    var isGradient: Bool = false
    var isBad: Bool = false

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isGradient {
                Text(number)
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(theme.gradient2)
            } else {
                Text(number)
                    .font(.display(32, weight: .medium))
                    .foregroundStyle(isBad ? theme.bad : .white)
            }
            Text(label)
                .font(.mono(11))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            isAccent
                ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.15), theme.g2.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAccent ? theme.g1.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BadgeChip: View {
    let name: String
    let isGold: Bool
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Text(name)
            .font(.mono(11))
            .tracking(0.2)
            .foregroundStyle(isGold ? theme.g3 : Color.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isGold ? theme.g3.opacity(0.18) : Color.white.opacity(0.06))
            .overlay(Capsule().stroke(isGold ? theme.g3.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, maxH: CGFloat = 0, rowH: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, size.height); x += size.width + spacing
            maxH = max(maxH, y + rowH)
        }
        return CGSize(width: width, height: maxH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height); x += size.width + spacing
        }
    }
}
