import SwiftUI

struct RecapView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

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

                        EyebrowLabel(text: "★ season 03 · final", color: theme.g3)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 12)

                    (Text("that's a\n").font(.display(72)) + Text("wrap.").font(.display(72)).italic().foregroundStyle(theme.gradient))
                        .foregroundStyle(.white)
                        .lineSpacing(-8)
                        .padding(.bottom, 10)

                    Text("twelve weeks. nine friends. one trophy. one cautionary tale.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineSpacing(3)
                        .padding(.bottom, 28)

                    // Champion
                    AwardCard(
                        label: "★ champion of the season",
                        name: state.season.champion?.name ?? "luca",
                        stat: "11/12 shows · 0 flakes · 412 pts",
                        isWinner: true
                    )
                    .padding(.bottom, 12)

                    // Biggest flake
                    AwardCard(
                        label: "flake of the season",
                        name: state.season.biggestFlake?.name ?? "mo",
                        stat: "2/12 shows · 6 flakes · −14 pts",
                        isWinner: false
                    )
                    .padding(.bottom, 28)

                    EyebrowLabel(text: "superlatives").padding(.bottom, 8)

                    VStack(spacing: 0) {
                        SuperlativeRow(title: "most reliable",  isItalic: true,  who: "nina · 11/12 shows")
                        SuperlativeRow(title: "the clutch",     isItalic: false, italicWord: "clutch", who: "maya · saved 3 moves")
                        SuperlativeRow(title: "full sender",    isItalic: true,  who: "iggy · 14 \"maybe\"s")
                        SuperlativeRow(title: "most improved",  isItalic: false, italicWord: "improved", who: "jamie · +4 ranks")
                    }
                    .padding(.bottom, 22)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.featureScreen = nil
                            state.selectedTab = .home
                        }
                    } label: {
                        HStack {
                            Text("start season 04")
                                .font(.system(size: 16, weight: .semibold))
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
