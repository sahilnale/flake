import SwiftUI

struct RecapView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    // MARK: - Derived data

    private var group: FlakeGroup? { state.selectedGroup }
    private var members: [Member]  { state.activeLeaderboardMembers.sorted { $0.score > $1.score } }

    private var seasonNumber: Int  { group?.season ?? 1 }
    private var totalWeeks: Int    { group?.seasonWeeks ?? 12 }
    private var memberCount: Int   { group?.members.count ?? 0 }

    private var champion:    Member? { state.season.champion }
    private var biggestFlake: Member? { state.season.biggestFlake }

    // Stat string helpers
    private func statLine(_ m: Member) -> String {
        let total = m.showCount + m.flakeCount
        let scoreStr = m.score < 0 ? "−\(abs(m.score)) pts" : "\(m.score) pts"
        return "\(m.showCount)/\(total) shows · \(m.flakeCount) flakes · \(scoreStr)"
    }

    // Number → written word (1-20, digits beyond that)
    private func wordify(_ n: Int) -> String {
        let words = ["one","two","three","four","five","six","seven",
                     "eight","nine","ten","eleven","twelve","thirteen",
                     "fourteen","fifteen","sixteen","seventeen","eighteen","nineteen","twenty"]
        return n >= 1 && n <= 20 ? words[n - 1] : "\(n)"
    }

    private var subtitle: String {
        let w = wordify(totalWeeks)
        let f = memberCount == 1 ? "one friend" : "\(wordify(memberCount)) friends"
        return "\(w) weeks. \(f). one trophy. one cautionary tale."
    }

    // MARK: - Superlatives

    private var mostReliable: String {
        let candidates = members.filter { $0.showCount + $0.flakeCount > 0 }
        guard let m = candidates.max(by: {
            let ra = Double($0.showCount) / Double($0.showCount + $0.flakeCount)
            let rb = Double($1.showCount) / Double($1.showCount + $1.flakeCount)
            return ra < rb || (ra == rb && $0.showCount < $1.showCount)
        }) else { return "—" }
        let total = m.showCount + m.flakeCount
        return "\(m.name) · \(m.showCount)/\(total) shows"
    }

    private var theCutch: String {
        guard let g = group, !g.moves.isEmpty else { return "—" }
        var counts: [UUID: Int] = [:]
        for move in g.moves { counts[move.creatorID, default: 0] += 1 }
        guard let topEntry = counts.max(by: { $0.value < $1.value }),
              let m = members.first(where: { $0.id == topEntry.key }) else { return "—" }
        let n = topEntry.value
        return "\(m.name) · called \(n) move\(n == 1 ? "" : "s")"
    }

    private var fullSender: String {
        guard let g = group else { return "—" }
        var counts: [UUID: Int] = [:]
        for move in g.moves {
            for (uid, rsvp) in move.rsvps where rsvp == .sendingIt {
                counts[uid, default: 0] += 1
            }
        }
        guard let topEntry = counts.max(by: { $0.value < $1.value }),
              let m = members.first(where: { $0.id == topEntry.key }) else { return "—" }
        let n = topEntry.value
        return "\(m.name) · \(n) \"maybe\"s"
    }

    private var runnerUp: String {
        guard members.count >= 2 else { return "—" }
        let m = members[1]
        return "\(m.name) · \(m.score) pts"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .celebrate).frame(height: 400)

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

                        EyebrowLabel(
                            text: "★ season \(String(format: "%02d", seasonNumber)) · final",
                            color: theme.g3
                        )
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 12)

                    (Text("that's a\n").font(.display(72)) +
                     Text("wrap.").font(.display(72)).italic().foregroundStyle(theme.gradient))
                        .foregroundStyle(.white)
                        .lineSpacing(-8)
                        .padding(.bottom, 10)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineSpacing(3)
                        .padding(.bottom, 28)

                    // Champion
                    AwardCard(
                        label: "★ champion of the season",
                        name: champion?.name ?? "—",
                        stat: champion.map { statLine($0) } ?? "no settled moves yet",
                        isWinner: true
                    )
                    .padding(.bottom, 12)

                    // Biggest flake
                    AwardCard(
                        label: "flake of the season",
                        name: biggestFlake?.name ?? "—",
                        stat: biggestFlake.map { statLine($0) } ?? "no settled moves yet",
                        isWinner: false
                    )
                    .padding(.bottom, 28)

                    EyebrowLabel(text: "superlatives").padding(.bottom, 8)

                    VStack(spacing: 0) {
                        SuperlativeRow(title: "most reliable",  isItalic: true,  who: mostReliable)
                        SuperlativeRow(title: "the clutch",     isItalic: false, italicWord: "clutch", who: theCutch)
                        SuperlativeRow(title: "full sender",    isItalic: true,  who: fullSender)
                        SuperlativeRow(title: "runner up",      isItalic: false, italicWord: "up",     who: runnerUp)
                    }
                    .padding(.bottom, 22)

                    let isGroupLeader = state.selectedGroup?.groupLeaderID == state.currentUserID
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Group leader goes to Groups where they can configure the new season.
                            // Everyone else goes home.
                            state.featureScreen = isGroupLeader ? .groups : nil
                            if !isGroupLeader { state.selectedTab = .home }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("start season \(String(format: "%02d", seasonNumber + 1))")
                                    .font(.system(size: 16, weight: .semibold))
                                if isGroupLeader {
                                    Text("configure season settings →")
                                        .font(.mono(10))
                                        .tracking(0.4)
                                        .opacity(0.65)
                                }
                            }
                            Spacer()
                            Text("→").font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(theme.gradient2)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: theme.g1.opacity(0.3), radius: 16, y: 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - AwardCard

private struct AwardCard: View {
    let label: String
    let name: String
    let stat: String
    let isWinner: Bool

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.mono(10, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isWinner ? theme.g3 : theme.bad)
                .padding(.bottom, 8)
            Text(name)
                .font(.display(42))
                .foregroundStyle(.white)
            Text(stat)
                .font(.mono(12))
                .tracking(0.3)
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            isWinner
                ? AnyShapeStyle(LinearGradient(colors: [theme.g3.opacity(0.18), theme.g2.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(LinearGradient(colors: [theme.bad.opacity(0.15), theme.bad.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isWinner ? theme.g3.opacity(0.4) : theme.bad.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - SuperlativeRow

private struct SuperlativeRow: View {
    let title: String
    var isItalic: Bool = false
    var italicWord: String = ""
    let who: String

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if isItalic {
                Text(title)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(theme.gradient2)
            } else if !italicWord.isEmpty {
                let parts = title.components(separatedBy: italicWord)
                (Text(parts.first ?? "")
                 + Text(italicWord).italic().foregroundStyle(theme.gradient2)
                 + Text(parts.last ?? ""))
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
            } else {
                Text(title)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(who)
                .font(.mono(11))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Color.white.opacity(0.06).frame(height: 1) }
    }
}
