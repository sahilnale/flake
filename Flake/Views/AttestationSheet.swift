import SwiftUI

/// "Who showed up?" — democratic attendance voting.
/// Any group member can submit their attestation after a move's date has passed.
/// Majority (≥50%) of votes determines whether someone showed or missed.
struct AttestationSheet: View {
    let move: Move

    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    // votes[memberID] = .showed | .missed
    @State private var votes: [UUID: AttendanceStatus] = [:]
    @State private var submitted = false

    private var members: [Member] {
        state.activeFriends.sorted { $0.id == state.currentUserID ? false : $0.name < $1.name }
    }

    private var voterCount: Int { state.attestationVoterCount(moveID: move.id) }
    private var memberCount: Int { members.count }
    private var allVoted: Bool { votes.count == memberCount }
    private var alreadyAttested: Bool { state.hasAttested(moveID: move.id) }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .split).frame(height: 260).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    EyebrowLabel(
                        text: submitted || alreadyAttested
                            ? "✓ you voted · \(voterCount)/\(memberCount) done"
                            : "\(voterCount)/\(memberCount) have voted so far",
                        color: submitted || alreadyAttested ? theme.good : theme.g3
                    )
                    .padding(.bottom, 12)

                    (Text("who\n").font(.display(54))
                     + Text("showed?").font(.display(54)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-6)
                        .padding(.bottom, 8)

                    Text("at \(move.title.lowercased()) · \(shortDate(move.date))")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.bottom, 6)

                    Text("majority wins. ≥50% say you showed → you get points.")
                        .font(.mono(11))
                        .tracking(0.3)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.bottom, 24)

                    if submitted || alreadyAttested {
                        // ── Post-submission: show live tally ──
                        liveResultsSection
                    } else {
                        // ── Voting UI ──
                        votingSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
        .onAppear { prefillFromExistingVotes() }
    }

    // MARK: - Voting section

    @ViewBuilder
    private var votingSection: some View {
        VStack(spacing: 0) {
            ForEach(members) { member in
                AttestationRow(
                    member: member,
                    isYou: member.id == state.currentUserID,
                    vote: votes[member.id],
                    onVote: { status in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            votes[member.id] = status
                        }
                    }
                )
            }
        }
        .padding(.bottom, 20)

        Button {
            guard allVoted else { return }
            state.submitAttestation(moveID: move.id, votes: votes)
            withAnimation(.easeInOut(duration: 0.2)) { submitted = true }
        } label: {
            HStack {
                Text(allVoted ? "submit votes" : "vote for everyone first")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if allVoted { Text("→").font(.system(size: 18)) }
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(allVoted ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!allVoted)
        .buttonStyle(.plain)
        .padding(.bottom, 10)

        Button("skip for now") { dismiss() }
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(12)
    }

    // MARK: - Post-submission tally

    @ViewBuilder
    private var liveResultsSection: some View {
        VStack(spacing: 0) {
            ForEach(members) { member in
                let derived = state.derivedAttendance(for: move.id)
                let result = derived[member.id]
                let myVote = state.rawAttestationVotes[move.id]?[state.currentUserID]?[member.id]

                HStack(spacing: 12) {
                    AvatarView(initials: member.initials,
                               colorHex: member.avatarColorHex,
                               size: 32,
                               isYou: member.id == state.currentUserID)

                    Text(member.id == state.currentUserID ? "you" : member.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    // My vote chip
                    if let mv = myVote {
                        Text(mv == .showed ? "i said ✓" : "i said ✗")
                            .font(.mono(10))
                            .foregroundStyle(mv == .showed ? theme.good.opacity(0.7) : theme.bad.opacity(0.7))
                    }

                    // Group result
                    if let r = result {
                        HStack(spacing: 4) {
                            Image(systemName: r == .showed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text(r == .showed ? "showed" : "missed")
                                .font(.mono(10))
                                .tracking(0.4)
                        }
                        .foregroundStyle(r == .showed ? theme.good : theme.bad)
                    } else {
                        Text("no votes")
                            .font(.mono(10))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) {
                    Color.white.opacity(0.06).frame(height: 1)
                }
            }
        }
        .padding(.bottom, 20)

        Button("done") { dismiss() }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helpers

    private func prefillFromExistingVotes() {
        // Pre-fill with any existing votes the user submitted previously
        if let existing = state.rawAttestationVotes[move.id]?[state.currentUserID] {
            votes = existing
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date).lowercased()
    }
}

// MARK: - AttestationRow

private struct AttestationRow: View {
    let member: Member
    let isYou: Bool
    let vote: AttendanceStatus?
    let onVote: (AttendanceStatus) -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initials: member.initials,
                       colorHex: member.avatarColorHex,
                       size: 32,
                       isYou: isYou)

            Text(isYou ? "you" : member.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            // Toggle: showed / missed
            HStack(spacing: 6) {
                AttestButton(
                    label: isYou ? "i was there" : "showed",
                    isSelected: vote == .showed,
                    isGood: true,
                    action: { onVote(.showed) }
                )
                AttestButton(
                    label: isYou ? "i wasn't" : "missed",
                    isSelected: vote == .missed,
                    isGood: false,
                    action: { onVote(.missed) }
                )
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}

private struct AttestButton: View {
    let label: String
    let isSelected: Bool
    let isGood: Bool
    let action: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected
                    ? (isGood ? Color(hex: "02230f") : .white)
                    : Color.white.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? (isGood
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "66e0a3"), Color(hex: "2dbb74")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(theme.bad.opacity(0.8)))
                        : AnyShapeStyle(Color.white.opacity(0.07))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
