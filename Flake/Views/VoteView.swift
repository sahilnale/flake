import SwiftUI

struct VoteView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            ScrollView(showsIndicators: false) {
                if let vote = state.activeExcusedVote {
                    VoteContent(vote: vote)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        EyebrowLabel(text: "no open vote", color: theme.g3)
                            .padding(.bottom, 14)

                        (Text("nothing to\n").font(.display(52)) + Text("decide.").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                            .foregroundStyle(.white)
                            .lineSpacing(-5)
                            .padding(.bottom, 12)

                        Text("No one has requested an excused absence for this move yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .padding(.bottom, 22)

                        Button("close") { dismiss() }
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(14)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
    }
}

private struct VoteContent: View {
    let vote: ExcusedVote

    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: eyebrowText(for: vote), color: theme.g3)
                .padding(.bottom, 14)

            (Text("\(vote.petitioner.name) wants an\n").font(.display(44)) + Text("excused absence.").font(.display(44)).italic().foregroundStyle(theme.gradient2))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            Text("\(vote.petitioner.name) missed \(vote.move.title). They say it was real. The group decides: if it passes, no points lost.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineSpacing(3)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    AvatarView(initials: vote.petitioner.initials, colorHex: vote.petitioner.avatarColorHex, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vote.petitioner.name)
                            .font(.display(22))
                            .foregroundStyle(.white)
                        Text("missed: \(shortDate(vote.move.date)) · \(vote.move.location) · \(pendingPointsText(for: vote))")
                            .font(.mono(10))
                            .tracking(0.4)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 14)

                Divider().overlay(Color.white.opacity(0.06))

                Text(vote.excuse)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineSpacing(4)
                    .padding(.top, 12)
            }
            .padding(18)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.bottom, 14)

            (Text("at stake → ").bold().foregroundStyle(.white)
             + Text("−\(vote.pointsAtRisk) points.\n")
             + Text(vote.move.creatorID == vote.petitioner.id ? "move leader penalty applies — they called this one." : "move leader penalty does not apply — they didn't call this one."))
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineSpacing(3)
                .padding(.bottom, 14)

            GeometryReader { g in
                HStack(spacing: 0) {
                    theme.good.frame(width: g.size.width * vote.approvalFraction)
                    theme.bad.frame(width: g.size.width * (Double(vote.denyCount) / Double(max(1, vote.totalVotes))))
                    Color.white.opacity(0.06)
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 6)
            .padding(.bottom, 14)

            HStack(spacing: 8) {
                TallyCard(label: "approve · \(vote.approvalCount)",
                          count: "approve",
                          who: vote.approvers.isEmpty ? "no one yet" : vote.approvers.map(\.name).joined(separator: " · "),
                          isApprove: true)
                TallyCard(label: "deny · \(vote.denyCount)",
                          count: "deny",
                          who: vote.deniers.isEmpty ? "no one yet" : vote.deniers.map(\.name).joined(separator: " · "),
                          isApprove: false)
            }
            .padding(.bottom, 18)

            let isVoteExpired = vote.closesAt < Date()
            let isPetitioner  = vote.petitioner.id == state.currentUserID
            let canResolve = vote.outcome == .pending
                && !isPetitioner   // petitioner can't judge their own case
                && (vote.totalVotes > 0 || isVoteExpired)
                && (state.activeMove.creatorID == state.currentUserID
                    || state.selectedGroup?.groupLeaderID == state.currentUserID)
            if canResolve {
                Button {
                    state.resolveActiveExcusedVote()
                } label: {
                    HStack {
                        if isVoteExpired && vote.totalVotes == 0 {
                            Text("vote expired — close")
                                .font(.system(size: 14, weight: .semibold))
                        } else {
                            Text("resolve vote")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Spacer()
                        Text(vote.approvalCount > vote.denyCount ? "approve → 0 pts" : "deny → −\(vote.pointsAtRisk)")
                            .font(.mono(10))
                            .tracking(0.6)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isVoteExpired ? theme.bad.opacity(0.35) : theme.g3.opacity(0.25), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }

            EyebrowLabel(text: vote.outcome == .pending ? (vote.petitioner.id == state.currentUserID ? "group decides" : "your call") : "final")
                .padding(.bottom, 8)

            if vote.outcome != .pending {
                Text(vote.isApproved ? "Approved. This flake lands as 0 points lost." : "Denied. The flake penalty stands.")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else if vote.petitioner.id == state.currentUserID {
                Text("Your request is live. The group votes — majority wins, tie goes to denied. Auto-closes \(relativeClose(vote.closesAt)).")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                HStack(spacing: 8) {
                    Button {
                        state.castVote(.approve)
                    } label: {
                        VStack(spacing: 2) {
                            Text("approve")
                                .font(.system(size: 14, weight: .semibold))
                            Text("no points lost")
                                .font(.mono(9))
                                .tracking(0.6)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Color(hex: "02230f"))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(LinearGradient(colors: [Color(hex: "66e0a3"), Color(hex: "2dbb74")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.castVote(.deny)
                    } label: {
                        VStack(spacing: 2) {
                            Text("deny")
                                .font(.system(size: 14, weight: .semibold))
                            Text("−\(vote.pointsAtRisk) pts stands")
                                .font(.mono(9))
                                .tracking(0.6)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(theme.bad)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(theme.bad.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }

            Text("fair enough, but you still have to face the group.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date).lowercased()
    }

    private func relativeClose(_ date: Date) -> String {
        let minutes = max(1, Int(date.timeIntervalSinceNow / 60))
        if minutes >= 60 {
            return "in \(minutes / 60)h"
        }
        return "in \(minutes)m"
    }

    private func eyebrowText(for vote: ExcusedVote) -> String {
        switch vote.outcome {
        case .pending:
            let expired = vote.closesAt < Date()
            return expired
                ? "★ vote expired · auto-resolving"
                : "★ open vote · auto-closes \(relativeClose(vote.closesAt))"
        case .approved:
            return "★ approved · 0 pts lost"
        case .denied:
            return "★ denied · penalty stands"
        }
    }

    private func pendingPointsText(for vote: ExcusedVote) -> String {
        switch vote.outcome {
        case .pending:
            return "−\(vote.pointsAtRisk) pts pending"
        case .approved:
            return "0 pts lost"
        case .denied:
            return "−\(vote.pointsAtRisk) pts"
        }
    }
}

private struct TallyCard: View {
    let label: String
    let count: String
    let who: String
    let isApprove: Bool

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.mono(9))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(isApprove ? theme.good : theme.bad)
                .padding(.bottom, 2)
            Text(count)
                .font(.display(28))
                .foregroundStyle(.white)
            Text(who)
                .font(.mono(10))
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isApprove ? theme.good.opacity(0.08) : theme.bad.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isApprove ? theme.good.opacity(0.25) : theme.bad.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
