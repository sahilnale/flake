import SwiftUI

// MARK: - Compact bubble (app strip / drawer)

struct CompactBubbleView: View {
    let onTap: () -> Void
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    theme.gradient
                    Text("f.")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("flake.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("send a move →")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(16)
            .background(Color.flakeBG)
        }
        .buttonStyle(.plain)
    }
}

struct CompactSelectedMoveView: View {
    let move: Move
    let onTap: () -> Void
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    theme.gradient
                    Text("rsvp")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(move.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("tap to RSVP →")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(16)
            .background(Color.flakeBG)
        }
        .buttonStyle(.plain)
    }
}

struct TranscriptMoveCardView: View {
    let move: Move
    let participants: [MessageParticipant]
    let onTap: () -> Void

    @Environment(\.flakeTheme) private var theme

    private var selectedStatus: RSVPStatus {
        move.rsvps[move.creatorID] ?? .lockedIn
    }

    private var respondedCount: Int {
        participants.filter { move.rsvps[$0.id] != nil }.count
    }

    private var everyoneResponded: Bool {
        !participants.isEmpty && respondedCount == participants.count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.flakeBG

            RadialGradient(
                colors: [statusColor(selectedStatus).opacity(0.7), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 260
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("flake.")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundColor(Color(hex: "ff8c42"))
                    Spacer(minLength: 12)
                    Text(everyoneResponded ? "everyone responded" : "\(respondedCount)/\(max(1, participants.count)) responded")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundColor(everyoneResponded ? theme.good : Color.white.opacity(0.62))
                        .lineLimit(1)
                }
                .padding(.bottom, 14)

                Text(move.title.isEmpty ? "new move" : move.title)
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .padding(.bottom, 6)

                Text("leader +25 · \(move.location)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(0.2)
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.bottom, 16)

                HStack(spacing: 8) {
                    TranscriptOptionPill(label: "yes", status: .lockedIn, selected: selectedStatus == .lockedIn)
                    TranscriptOptionPill(label: "maybe", status: .sendingIt, selected: selectedStatus == .sendingIt)
                    TranscriptOptionPill(label: "flake", status: .flaked, selected: selectedStatus == .flaked)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func statusColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .lockedIn: return theme.good
        case .sendingIt: return theme.g3
        case .flaked: return theme.bad
        case .silent: return theme.g1
        }
    }
}

private struct TranscriptOptionPill: View {
    let label: String
    let status: RSVPStatus
    let selected: Bool

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundColor(selected && status == .lockedIn ? Color(hex: "062511") : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(selected ? statusColor : Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.white.opacity(0.55) : Color.white.opacity(0.12), lineWidth: selected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        switch status {
        case .lockedIn: return theme.good
        case .sendingIt: return theme.g3
        case .flaked: return theme.bad
        case .silent: return theme.g1
        }
    }
}

// MARK: - Move bubble (as seen in the thread — rendered by MSMessageTemplateLayout)
//  This view is used to generate the live preview image for the message layout.

struct MoveBubbleView: View {
    let move: Move
    let members: [Member]
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ZStack {
            Color.flakeBG

            // Ombre bg
            RadialGradient(colors: [theme.g1.opacity(0.55), .clear], center: .init(x: 0.5, y: 0), startRadius: 0, endRadius: 200)
                .blur(radius: 20)

            VStack(alignment: .leading, spacing: 0) {
                // App tag
                HStack {
                    Text("flake.")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(theme.gradient2)
                    Spacer()
                    Text("a move · live")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Title
                (Text(move.title.components(separatedBy: " at ").first ?? move.title) + Text("\nat ").foregroundStyle(.white) + Text(move.location + ".").italic().foregroundStyle(theme.gradient2))
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineSpacing(-2)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)

                // When
                Text(formattedDate(move.date))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                // Tally pips
                HStack(spacing: 6) {
                    HStack(spacing: -5) {
                        ForEach(Array(members.prefix(4))) { m in
                            AvatarView(initials: m.initials, colorHex: m.avatarColorHex, size: 18)
                                .overlay(Circle().stroke(Color.flakeBG, lineWidth: 1.5))
                        }
                    }
                    Text("\(move.lockedInCount) locked in · \(move.sendingItCount) sending it")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                // RSVP row
                HStack(spacing: 5) {
                    RSVPMiniBtn(emoji: "⚡", label: "lock in", isPrimary: true)
                    RSVPMiniBtn(emoji: "🤞", label: "sending it", isPrimary: false)
                    RSVPMiniBtn(emoji: "💀", label: "flake", isPrimary: false)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                // Footer
                HStack {
                    Text("tap to rsvp · no download")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Text("open the ranks →")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(theme.g1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.35))
                .overlay(alignment: .top) {
                    Color.white.opacity(0.06).frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mma"
        return f.string(from: date).lowercased()
    }
}

private struct RSVPMiniBtn: View {
    let emoji: String
    let label: String
    let isPrimary: Bool
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 13))
            Text(label)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(0.4)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isPrimary ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
