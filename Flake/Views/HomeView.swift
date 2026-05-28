import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var showDeleteMoveConfirm = false

    private var move: Move { state.activeMove }
    private var friends: [Member] {
        state.activeFriends.filter { $0.id != state.currentUserID }
    }
    private var myStatus: RSVPStatus {
        state.myRSVP ?? move.rsvps[state.currentUserID] ?? .silent
    }
    /// True when the current user called this specific move.
    private var isMoveLeader: Bool {
        move.creatorID == state.currentUserID
    }

    /// Past moves (within 7 days) that the current user hasn't attested yet.
    private var movesNeedingAttestation: [Move] {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return state.activeMoves.filter { m in
            m.date < Date()
            && m.date >= cutoff
            && !state.hasAttested(moveID: m.id)
        }
    }
    /// True when the current user created the group itself.
    private var isGroupAdmin: Bool {
        state.selectedGroup?.groupLeaderID == state.currentUserID
    }
    private var lockedInCount: Int {
        var count = move.lockedInCount
        if move.rsvps[state.currentUserID] != .lockedIn && myStatus == .lockedIn { count += 1 }
        return count
    }
    private var timeComponents: (days: Int, hours: Int, mins: Int) {
        let interval = max(0, move.date.timeIntervalSinceNow)
        let days  = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let mins  = (Int(interval) % 3600)  / 60
        return (days, hours, mins)
    }

    var body: some View {
        if state.groups.isEmpty {
            NoGroupsView()
        } else if state.activeMoves.isEmpty {
            NoMovesView()
        } else {
            homeContent
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .top)
                    .frame(height: 400)
                VStack(alignment: .leading, spacing: 0) {
                    // Top bar
                    HStack {
                        EyebrowLabel(text: "live · \(shortDate(move.date))", color: theme.g1)
                            .overlay(alignment: .leading) {
                                Circle().fill(theme.g1).frame(width: 6, height: 6)
                                    .offset(x: -12)
                            }
                            .padding(.leading, 12)
                        Spacer()
                        Button {
                            state.calendarSheetVisible = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.08))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

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
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 18)

                    HStack(spacing: 10) {
                        Text("\(state.activeMoves.count) moves")
                            .font(.mono(11))
                            .tracking(0.7)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.45))
                        Spacer()
                        Button {
                            state.createMoveSheetVisible = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("new move")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(state.activeMoves) { candidate in
                                MoveChip(move: candidate, isSelected: candidate.id == move.id) {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        state.selectMove(candidate)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)

                    // Attestation banners — one per past move awaiting votes
                    if !movesNeedingAttestation.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(movesNeedingAttestation) { pastMove in
                                Button {
                                    state.attestationSheetMoveID = pastMove.id
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            theme.gradient2
                                            Text("👥")
                                                .font(.system(size: 14))
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("who showed up?")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white)
                                            let voterCount = state.attestationVoterCount(moveID: pastMove.id)
                                            Text("\(pastMove.title.lowercased()) · \(voterCount) of \(state.activeFriends.count) voted")
                                                .font(.mono(11))
                                                .tracking(0.3)
                                                .foregroundStyle(Color.white.opacity(0.5))
                                        }

                                        Spacer()
                                        Text("vote →")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.g2)
                                    }
                                    .padding(12)
                                    .background(LinearGradient(
                                        colors: [theme.g2.opacity(0.12), theme.g1.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(theme.g2.opacity(0.25), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    // Move title
                    VStack(alignment: .leading, spacing: 4) {
                        titleText(move.title)
                    }
                    .foregroundStyle(.white)
                    .lineSpacing(-4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                    // Sub
                    Group {
                        Text(move.subtitle.isEmpty ? "the standing one. " : "\(move.subtitle) ") + Text(isMoveLeader ? "you called this one" : "move leader called this one").bold()
                        + Text(isMoveLeader ? "  ★ +25 move bonus · −25 if you flake" : "  ★ move leader gets +25")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.g3)
                        + Text("\n\(moveDetail)")
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                    // Date chip
                    if move.date >= Date() && !move.isSettled {
                        HStack(spacing: 6) {
                            Text(specificDateTime(move.date))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("·")
                                .foregroundStyle(.white.opacity(0.3))
                            Text(relativeClose(move.date))
                                .foregroundStyle(theme.g1)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    } else {
                        Spacer().frame(height: 10)
                    }

                    // Countdown
                    let tc = timeComponents
                    HStack(spacing: 12) {
                        CountdownUnit(value: tc.days,  label: "days")
                        CountdownUnit(value: tc.hours, label: "hours")
                        CountdownUnit(value: tc.mins,  label: "min")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Lineup header
                    HStack {
                        Text(move.isSettled ? "final attendance" : "the lineup")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Spacer()
                        if move.isSettled {
                            let showedCount = move.attendance.values.filter { $0 == .showed }.count
                            Text("\(showedCount) showed · \(move.attendance.values.filter { $0 == .missed }.count) missed")
                                .font(.mono(11))
                                .foregroundStyle(Color.white.opacity(0.4))
                        } else {
                            Text("\(lockedInCount) of \(friends.count + 1) locked in")
                                .font(.mono(11))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Lineup rows
                    VStack(spacing: 0) {
                        LineupRow(
                            initials: "u",
                            colorHex: state.currentUser.avatarColorHex,
                            name: "you",
                            tag: move.isSettled ? nil : "tap to RSVP",
                            status: myStatus,
                            isYou: true,
                            attendance: move.attendance[state.currentUserID],
                            isSettled: move.isSettled
                        )
                        ForEach(friends) { member in
                            LineupRow(
                                initials: member.initials,
                                colorHex: member.avatarColorHex,
                                name: member.name,
                                tag: nil,
                                status: move.rsvps[member.id] ?? .silent,
                                isYou: false,
                                attendance: move.attendance[member.id],
                                isSettled: move.isSettled
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    if let vote = state.activeExcusedVote {
                        let isMyExcusedRequest = vote.petitioner.id == state.currentUserID
                        Button {
                            state.voteSheetVisible = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    theme.gradient2
                                    Text("★")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isMyExcusedRequest
                                         ? "you requested an excused absence"
                                         : "\(vote.petitioner.name) wants an excused absence")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(voteLine(for: vote))
                                        .font(.mono(11))
                                        .tracking(0.4)
                                        .foregroundStyle(Color.white.opacity(0.55))
                                }
                                Spacer()
                                Text("→")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(theme.g3)
                            }
                            .padding(12)
                            .background(LinearGradient(colors: [theme.g3.opacity(0.14), theme.g2.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.g3.opacity(0.3), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                    }

                    // CTA — locked after settlement
                    if move.isSettled {
                        let myAttendance = move.attendance[state.currentUserID]
                        HStack(spacing: 12) {
                            Image(systemName: myAttendance == .showed ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(myAttendance == .showed ? theme.good : theme.bad)
                            Text("attendance settled")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                            Spacer()
                            Text(myAttendance == .showed
                                 ? "+\(state.pointDelta(for: state.currentUserID, in: move)) pts"
                                 : "\(state.pointDelta(for: state.currentUserID, in: move)) pts")
                                .font(.mono(12))
                                .foregroundStyle(myAttendance == .showed ? theme.good : theme.bad)
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    } else {
                        Button {
                            state.rsvpSheetVisible = true
                        } label: {
                            HStack {
                                Text(myStatus == .silent ? "RSVP" : "update RSVP")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("→")
                                    .font(.system(size: 18))
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(theme.gradient2)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: theme.g1.opacity(0.3), radius: 16, y: 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }

                    // Excused absence — available if you flaked OR were settled as missed
                    let canRequestExcused = (myStatus == .flaked ||
                                            (move.isSettled && move.attendance[state.currentUserID] == .missed))
                                           && state.activeExcusedVote == nil
                    if canRequestExcused {
                        Button {
                            state.excusedRequestSheetVisible = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("request excused absence")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("vote")
                                    .font(.mono(10))
                                    .tracking(0.8)
                                    .textCase(.uppercase)
                                    .foregroundStyle(theme.g3)
                            }
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.g3.opacity(0.25), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    }

                    if isMoveLeader && !move.isSettled {
                        Button {
                            state.attendanceSheetVisible = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.2.badge.gearshape")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("settle attendance")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(state.pointDelta(for: state.currentUserID, in: move) >= 0 ? "+" : "")\(state.pointDelta(for: state.currentUserID, in: move)) pts")
                                    .font(.mono(10))
                                    .tracking(0.8)
                                    .textCase(.uppercase)
                                    .foregroundStyle(theme.g3)
                            }
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                        // Delete move — only move creator, with confirmation
                        Button {
                            showDeleteMoveConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("delete move")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(theme.bad)
                            .padding(14)
                            .background(theme.bad.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.bad.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .confirmationDialog("delete \"\(move.title)\"?", isPresented: $showDeleteMoveConfirm, titleVisibility: .visible) {
                            Button("delete move", role: .destructive) {
                                state.deleteMove(move)
                            }
                            Button("cancel", role: .cancel) {}
                        } message: {
                            Text("this removes the move and all RSVPs permanently.")
                        }
                    }

                    Spacer(minLength: 0)
                        .padding(.bottom, 120)
                }
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
    }

    private var moveDetail: String {
        if move.isSettled {
            return "attendance is settled. points are locked."
        }
        if move.date >= Date() {
            return "tap RSVP to lock in."
        }
        return "started \(specificDateTime(move.date)). update RSVP if plans changed."
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date).lowercased()
    }

    private func relativeClose(_ date: Date) -> String {
        let diff = date.timeIntervalSinceNow
        let minutes = max(1, Int(diff / 60))
        let hours = minutes / 60
        let days = hours / 24
        if days >= 1 { return "in \(days)d" }
        if hours >= 1 { return "in \(hours)h" }
        return "in \(minutes)m"
    }

    private func specificDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d 'at' h:mma"
        return formatter.string(from: date).lowercased()
    }

    private func voteLine(for vote: ExcusedVote) -> String {
        switch vote.outcome {
        case .approved:
            return "approved · 0 pts lost"
        case .denied:
            return "denied · −\(vote.pointsAtRisk) pts stands"
        case .pending:
            return "vote closes \(relativeClose(vote.closesAt)) · \(vote.approvalCount) yes, \(vote.denyCount) no"
        }
    }

    private func titleText(_ title: String) -> Text {
        let cleanTitle = title.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if cleanTitle.contains(" at ") {
            let parts = cleanTitle.components(separatedBy: " at ")
            return Text("\(parts[0])\nat ")
                .font(.display(60))
            + Text("\(parts.dropFirst().joined(separator: " at ")).")
                .font(.display(60))
                .italic()
                .foregroundStyle(theme.gradient2)
        }
        let words = cleanTitle.split(separator: " ", maxSplits: 1).map(String.init)
        if words.count == 2 {
            return Text("\(words[0])\n")
                .font(.display(60))
            + Text("\(words[1]).")
                .font(.display(60))
                .italic()
                .foregroundStyle(theme.gradient2)
        }
        return Text(title)
            .font(.display(60))
    }
}

// MARK: - Sub-views

private struct CountdownUnit: View {
    let value: Int
    let label: String
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.display(34, weight: .medium))
                .foregroundStyle(.white)
            Text(label)
                .font(.mono(10))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MoveChip: View {
    let move: Move
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(move.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(shortDate(move.date))
                    Text("·")
                    Text("\(move.lockedInCount) in")
                }
                .font(.mono(10))
                .tracking(0.3)
                .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(width: 150, alignment: .leading)
            .padding(12)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.18), theme.g2.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.05))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? theme.g1.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).lowercased()
    }
}

private struct LineupRow: View {
    let initials: String
    let colorHex: String
    let name: String
    let tag: String?
    let status: RSVPStatus
    let isYou: Bool
    var attendance: AttendanceStatus? = nil
    var isSettled: Bool = false

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initials: initials, colorHex: colorHex, size: 32, isYou: isYou)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    if let tag {
                        Text(tag)
                            .font(.mono(10))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }
            Spacer()
            // After settlement: show attendance result; before: show RSVP pill
            if isSettled, let att = attendance {
                HStack(spacing: 4) {
                    Image(systemName: att == .showed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(att == .showed ? "showed" : "missed")
                        .font(.mono(10))
                        .tracking(0.4)
                }
                .foregroundStyle(att == .showed ? theme.good : theme.bad)
            } else if isSettled {
                // Not in attendance dict — wasn't settled (e.g. member joined after)
                Text("—")
                    .font(.mono(11))
                    .foregroundStyle(Color.white.opacity(0.3))
            } else {
                PillView(status: status)
            }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}

// MARK: - NoMovesView

private struct NoMovesView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            VStack(alignment: .leading, spacing: 0) {

                // ── top bar ────────────────────────────────────────────────
                HStack {
                    EyebrowLabel(text: "0 moves", color: Color.white.opacity(0.3))

                    Spacer()

                    // Group switcher
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.featureScreen = .groups
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(state.selectedGroup?.name ?? "your group")
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
                .padding(.top, 60)
                .padding(.bottom, 64)

                Spacer()

                // ── headline ───────────────────────────────────────────────
                (Text("no\n").font(.display(64))
                    + Text("moves.").font(.display(64)).italic()
                        .foregroundStyle(theme.gradient2))
                    .foregroundStyle(.white)
                    .lineSpacing(-8)
                    .padding(.bottom, 14)

                Text("no moves planned yet. be the move leader — call the spot and earn **+25 points**.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineSpacing(4)
                    .padding(.bottom, 32)

                // ── CTA ────────────────────────────────────────────────────
                Button {
                    state.createMoveSheetVisible = true
                } label: {
                    HStack {
                        Text("call the first move")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("→")
                            .font(.system(size: 18))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(theme.gradient2)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: theme.g1.opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - NoGroupsView

private struct NoGroupsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var showJoin = false

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                (Text("no\n").font(.display(64)) + Text("moves.").font(.display(64)).italic().foregroundStyle(theme.gradient2))
                    .foregroundStyle(.white)
                    .lineSpacing(-8)
                    .padding(.bottom, 12)

                Text("start a group with your crew, or enter a code to join one someone shared.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineSpacing(3)
                    .padding(.bottom, 32)

                // Primary — join with a code
                Button { showJoin = true } label: {
                    HStack {
                        Text("join a group")
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
                .padding(.bottom, 10)

                // Secondary — create a new one
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.featureScreen = .groups
                    }
                } label: {
                    HStack {
                        Text("create a group")
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

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupSheet()
        }
    }
}
