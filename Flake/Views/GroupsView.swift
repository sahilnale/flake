import SwiftUI

struct GroupsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .split).frame(height: 300)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                state.featureScreen = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("‹")
                                Text("back")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        EyebrowLabel(text: "your groups · \(state.groups.count)")
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 8)

                    // Title
                    VStack(alignment: .leading, spacing: 0) {
                        (Text("be #1 here.\n").font(.display(52)) + Text("last ").font(.display(52)) + Text("there.").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 6)

                    Text("one leaderboard per thread. stats per group. the gap between them is, frankly, very funny.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.bottom, 24)

                    // Group cards
                    VStack(spacing: 12) {
                        ForEach(state.groups) { group in
                            GroupCard(group: group, isActive: group.id == state.selectedGroupID)
                                .onTapGesture {
                                    withAnimation { state.selectGroup(group) }
                                }
                        }
                    }
                    .padding(.bottom, 14)

                    // New group CTA
                    Button {
                    } label: {
                        HStack {
                            Text("start a new group from a thread")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text("→").font(.system(size: 15))
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)

                    Text("groups appear automatically when someone sends a move.")
                        .font(.system(size: 14))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - GroupCard

private struct GroupCard: View {
    let group: FlakeGroup
    let isActive: Bool

    @Environment(\.flakeTheme) private var theme

    var rankColor: AnyShapeStyle {
        if group.userRank == 1 { return AnyShapeStyle(theme.gradient) }
        if group.members.count > 0 && group.userRank == group.members.count { return AnyShapeStyle(Color(hex: "ff5a7a")) }
        return AnyShapeStyle(Color.white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(group.name)
                    .font(.display(24))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(group.members.count) friends · \(group.moves.count) moves · szn \(group.season)")
                    .font(.mono(10))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.bottom, 10)

            // Pile + rank
            HStack {
                AvatarStack(members: group.members, maxVisible: 4, size: 24)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%02d", group.userRank))
                        .font(.display(28, weight: group.userRank == 1 ? .bold : .medium))
                        .foregroundStyle(rankColor)
                    Text("of \(group.members.count)")
                        .font(.mono(9))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            // Next move
            if group.currentMove != nil || !group.nextSummary.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.vertical, 10)
                    .frame(height: 1)
                    .overlay(alignment: .center) {
                        Color.white.opacity(0.08).frame(height: 1)
                    }

                if let move = group.currentMove {
                    Text("next move · \(move.location) · ")
                        .foregroundStyle(Color.white.opacity(0.55))
                    + Text("\(move.lockedInCount) locked in")
                        .foregroundStyle(.white)
                        .bold()
                    + Text(" · \(timeUntilString(move.date))")
                        .foregroundStyle(theme.gradient2)
                        .italic()
                } else {
                    Text(group.nextSummary)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .font(.system(size: 12))
        .padding(18)
        .background(
            isActive
                ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.12), theme.g2.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? theme.g1.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func timeUntilString(_ date: Date) -> String {
        let days = Int(date.timeIntervalSinceNow) / 86400
        if days > 1 { return "\(days) days out." }
        if days == 1 { return "tomorrow." }
        return "today."
    }
}
