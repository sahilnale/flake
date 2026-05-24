import SwiftUI

struct RoastsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    private var roasts: [Roast] { state.generateRoasts(intensity: 3) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .split).frame(height: 280)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        (Text("the ").font(.display(48)) + Text("receipts.").font(.display(48)).italic().foregroundStyle(theme.gradient2))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 22)

                    // Roast list
                    VStack(spacing: 0) {
                        ForEach(roasts) { roast in
                            RoastRow(roast: roast)
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

// MARK: - RoastRow

private struct RoastRow: View {
    let roast: Roast
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(roast.targetName)
                    .font(.mono(10))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                Text(roast.timeAgo)
                    .font(.mono(10))
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.bottom, 10)

            // Text with italic emphasis support
            ItalicRoastText(text: roast.text)
                .padding(.bottom, 12)

            // Reactions
            HStack(spacing: 6) {
                ForEach(roast.reactions) { reaction in
                    ReactionChip(reaction: reaction, targetID: roast.id)
                }
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}

private struct ReactionChip: View {
    let reaction: Roast.Reaction
    let targetID: UUID
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @State private var bumped = false

    var body: some View {
        Button {
            state.toggleRoastReaction(targetID: targetID, emoji: reaction.emoji)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.45)) { bumped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) { bumped = false }
            }
        } label: {
            HStack(spacing: 4) {
                Text(reaction.emoji).font(.system(size: 12))
                Text("\(liveCount)")
                    .font(.mono(10, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.22), theme.g2.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.white.opacity(0.06))
            )
            .foregroundStyle(isActive ? theme.g1 : Color.white.opacity(0.7))
            .overlay(Capsule().stroke(isActive ? theme.g1.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(Capsule())
            .scaleEffect(bumped ? 1.18 : 1)
        }
        .buttonStyle(.plain)
    }

    /// Count from AppState (live), falls back to the seeded value from generateRoasts.
    private var liveCount: Int {
        state.roastReactionCounts[targetID]?[reaction.emoji] ?? reaction.count
    }

    /// True if the current user has reacted with this emoji.
    private var isActive: Bool {
        state.myRoastReactions[targetID]?.contains(reaction.emoji) == true
    }
}

// Renders *italic* markdown-style text in a roast
private struct ItalicRoastText: View {
    let text: String
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        let parts = parseItalic(text)
        parts.reduce(Text("")) { acc, part in
            if part.isItalic {
                return acc + Text(part.content)
                    .italic()
                    .foregroundStyle(theme.gradient2)
            } else {
                return acc + Text(part.content)
            }
        }
        .font(.system(size: 21, weight: .regular, design: .serif))
        .foregroundStyle(.white)
        .lineSpacing(4)
    }

    private struct Part { let content: String; let isItalic: Bool }
    private func parseItalic(_ s: String) -> [Part] {
        var parts: [Part] = []
        var cur = "", inItalic = false
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "*" {
                parts.append(Part(content: cur, isItalic: inItalic))
                cur = ""; inItalic.toggle()
            } else {
                cur.append(s[i])
            }
            i = s.index(after: i)
        }
        if !cur.isEmpty { parts.append(Part(content: cur, isItalic: inItalic)) }
        return parts
    }
}
