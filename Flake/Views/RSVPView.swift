import SwiftUI

struct RSVPView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selected: RSVPStatus? = .lockedIn

    private var isMoveLeader: Bool { state.activeMove.creatorID == state.currentUserID }
    private var flakePenalty: Int {
        state.activeMove.flakePenalty(for: state.currentUserID)
    }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "\(state.activeMove.location) · \(formattedTime(state.activeMove.date))")
                        .padding(.bottom, 16)

                    // Title
                    (Text("you in,\n").font(.display(52)) + Text("or what?").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-4)
                        .padding(.bottom, 12)

                    // Stakes box
                    HStack(spacing: 12) {
                        ZStack {
                            theme.gradient2
                            Text("⚡").font(.system(size: 18))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("flaking now costs ")
                            .foregroundStyle(Color.white.opacity(0.75))
                        + Text("−\(flakePenalty) pts").bold().foregroundStyle(.white)
                        + Text(isMoveLeader ? " as group leader" : "")
                            .foregroundStyle(Color.white.opacity(0.75))
                        + Text(".").foregroundStyle(Color.white.opacity(0.75))
                    }
                    .font(.system(size: 13))
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 24)

                    // Options
                    VStack(spacing: 10) {
                        RSVPCard(status: .lockedIn,
                                 label: "lock in",
                                 desc: "i'll be there. count me in. no excuses.",
                                 pts: "+15 pts",
                                 ptsGood: true,
                                 selected: selected == .lockedIn)
                        { selected = .lockedIn }

                        RSVPCard(status: .sendingIt,
                                 label: "sending it",
                                 desc: "probably. like 80%. you know how it goes.",
                                 pts: "+5 if you show · 0 if you don't",
                                 ptsGood: false,
                                 selected: selected == .sendingIt)
                        { selected = .sendingIt }

                        RSVPCard(status: .flaked,
                                 label: "flake",
                                 desc: isMoveLeader ? "you started this. flaking hits harder." : "can't make it. be honest before the group waits on you.",
                                 pts: "−\(flakePenalty) pts",
                                 ptsGood: false,
                                 selected: selected == .flaked)
                        { selected = .flaked }
                    }
                    .padding(.bottom, 24)

                    // CTA
                    VStack(spacing: 8) {
                        Button {
                            if let s = selected {
                                state.updateMyRSVP(s)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text("confirm")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("→").font(.system(size: 18))
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(selected != nil ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .disabled(selected == nil)

                        Button("back") { dismiss() }
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(14)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
        .onAppear {
            selected = state.myRSVP ?? state.activeMove.rsvps[state.currentUserID] ?? .lockedIn
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE · h:mma"
        return formatter.string(from: date).lowercased()
    }
}

// MARK: - RSVPCard

private struct RSVPCard: View {
    let status: RSVPStatus
    let label: String
    let desc: String
    let pts: String
    let ptsGood: Bool
    let selected: Bool
    let action: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(status.emoji)
                    .font(.system(size: 22))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineSpacing(3)
                    Text(pts)
                        .font(.mono(11))
                        .tracking(0.4)
                        .foregroundStyle(ptsGood ? theme.good : (status == .flaked ? theme.bad : Color.white.opacity(0.4)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(
                selected
                    ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.15), theme.g2.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? theme.g1 : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
