import SwiftUI

struct RoastsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var intensity: Double = 2
    @State private var roasts: [Roast] = Roast.samples(intensity: 2)

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .split).frame(height: 280)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        (Text("the ").font(.display(48)) + Text("receipts.").font(.display(48)).italic().foregroundStyle(theme.gradient2))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("12 new")
                            .font(.mono(11))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .overlay(alignment: .leading) {
                                Text("12").font(.mono(11, weight: .bold)).foregroundStyle(theme.g1)
                            }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 22)

                    // Intensity dial
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "roast intensity")
                        Slider(value: $intensity, in: 0...3, step: 1)
                            .tint(theme.g1)
                            .onChange(of: intensity) { _, v in
                                withAnimation { roasts = Roast.samples(intensity: Int(v)) }
                            }
                        HStack {
                            ForEach(["polite", "nudgy", "spicy", "unhinged"], id: \.self) { l in
                                Text(l)
                                    .font(.mono(9))
                                    .tracking(0.6)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                    .glassCard(radius: 14, padding: .init(top: 14, leading: 14, bottom: 14, trailing: 14))
                    .padding(.bottom, 24)

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
                    ReactionChip(reaction: reaction)
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
    @Environment(\.flakeTheme) private var theme
    @State private var count: Int?
    @State private var bumped = false

    var body: some View {
        Button {
            count = currentCount + 1
            withAnimation(.spring(response: 0.24, dampingFraction: 0.45)) {
                bumped = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) {
                    bumped = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(reaction.emoji).font(.system(size: 12))
                Text("\(currentCount)")
                    .font(.mono(10, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(reaction.isHot ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.18), theme.g2.opacity(0.1)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(0.06)))
            .foregroundStyle(reaction.isHot ? theme.g1 : Color.white.opacity(0.7))
            .overlay(Capsule().stroke(reaction.isHot ? theme.g1.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(Capsule())
            .scaleEffect(bumped ? 1.18 : 1)
        }
        .buttonStyle(.plain)
    }

    private var currentCount: Int {
        count ?? reaction.count
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
