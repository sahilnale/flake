import SwiftUI

struct LeaderboardView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var selectedTab = 0
    let tabs = ["season", "all time", "flake rate"]

    var sortedMembers: [Member] {
        switch selectedTab {
        case 1:  return state.activeLeaderboardMembers.sorted { $0.score > $1.score }
        case 2:  return state.activeLeaderboardMembers.sorted { $0.showRate > $1.showRate }
        default: return state.seasonLeaderboardMembers.sorted { $0.score > $1.score }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .top).frame(height: 300)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        EyebrowLabel(text: "season \(String(format: "%02d", state.selectedGroup?.season ?? 1)) · week \(state.currentSeasonWeek) of \(state.currentSeasonTotalWeeks)")
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                state.featureScreen = .groups
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(state.selectedGroup?.name ?? "thursday crew")
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                    .padding(.top, 60)

                    // Title
                    (Text("the ").font(.display(56)) + Text("ranks.").font(.display(56)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)

                    Text(state.selectedGroup?.ranksSubtitle ?? "five weeks left. nothing is decided. someone will be crowned. someone will be cooked.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.bottom, 18)

                    // Tabs
                    HStack(spacing: 4) {
                        ForEach(tabs.indices, id: \.self) { i in
                            Button {
                                withAnimation { selectedTab = i }
                            } label: {
                                Text(tabs[i])
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(selectedTab == i ? .white : Color.white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == i ? Color.white.opacity(0.1) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 16)

                    // Rows
                    VStack(spacing: 0) {
                        ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { i, member in
                            let rank = i + 1
                            let isTop = rank == 1
                            let isBottom = rank == sortedMembers.count
                            let isYou = member.id == state.currentUserID

                            LeaderboardRow(rank: rank, member: member, isTop: isTop,
                                          isBottom: isBottom, isYou: isYou,
                                          displayScore: selectedTab == 2 ? Int(member.showRate * 100) : member.score,
                                          scoreSuffix: selectedTab == 2 ? "%" : "",
                                          weeklyDelta: isYou ? state.weeklyScoreDelta : nil)
                        }
                    }
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let rank: Int
    let member: Member
    let isTop: Bool
    let isBottom: Bool
    let isYou: Bool
    let displayScore: Int
    let scoreSuffix: String
    var weeklyDelta: Int? = nil

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text(String(format: "%02d", rank))
                .font(.display(20, weight: isTop ? .bold : .regular))
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(isTop ? AnyShapeStyle(theme.gradient) : isBottom ? AnyShapeStyle(Color(hex: "ff5a7a")) : AnyShapeStyle(Color.white.opacity(0.4)))

            // Avatar + name
            HStack(spacing: 10) {
                AvatarView(initials: member.initials, colorHex: member.avatarColorHex, size: 28, isYou: isYou)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(member.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        if let delta = weeklyDelta, delta != 0 {
                            Text(delta > 0 ? "+\(delta) this week" : "−\(abs(delta)) this week")
                                .font(.mono(10))
                                .foregroundStyle(delta > 0 ? theme.g1.opacity(0.7) : Color(hex: "ff5a7a").opacity(0.7))
                        }
                        if isBottom && weeklyDelta == nil {
                            Text("flake of the szn")
                                .font(.mono(10))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(member.showCount) show")
                .font(.mono(11))
                .foregroundStyle(Color.white.opacity(0.4))

            // Score
            Text("\(displayScore)\(scoreSuffix)")
                .font(.display(20, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, isYou ? 12 : 0)
        .background(isYou ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.1), .clear], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottom) {
            if !isYou {
                Color.white.opacity(0.06).frame(height: 1)
            }
        }
    }
}
