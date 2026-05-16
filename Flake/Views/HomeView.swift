import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    private var move: Move { state.activeMove }
    private var friends: [Member] {
        state.activeFriends.filter { $0.id != state.currentUserID }
    }
    private var myStatus: RSVPStatus {
        state.myRSVP ?? move.rsvps[state.currentUserID] ?? .silent
    }
    private var isGroupLeader: Bool {
        move.creatorID == state.currentUserID
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
                        Text(move.subtitle.isEmpty ? "the standing one. " : "\(move.subtitle) ") + Text(isGroupLeader ? "you called this one" : "group leader called this one").bold()
                        + Text(isGroupLeader ? "  ★ +25 leader bonus · −25 if you flake" : "  ★ leader gets +25")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.g3)
                        + Text("\n\(moveDetail)")
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

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
                        Text("the lineup")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Spacer()
                        Text("\(lockedInCount) of \(friends.count + 1) locked in")
                            .font(.mono(11))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Lineup rows
                    VStack(spacing: 0) {
                        LineupRow(
                            initials: "u",
                            colorHex: state.currentUser.avatarColorHex,
                            name: "you",
                            tag: "tap to RSVP",
                            status: myStatus,
                            isYou: true
                        )
                        ForEach(friends) { member in
                            if let rsvp = move.rsvps[member.id] {
                                LineupRow(
                                    initials: member.initials,
                                    colorHex: member.avatarColorHex,
                                    name: member.name,
                                    tag: nil,
                                    status: rsvp,
                                    isYou: false
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    if let vote = state.activeExcusedVote {
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
                                    Text("\(vote.petitioner.name) wants an excused absence")
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

                    // CTA
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

                    if myStatus == .flaked && state.activeExcusedVote == nil {
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

                    if isGroupLeader {
                        Button {
                            state.attendanceSheetVisible = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: move.isSettled ? "checkmark.seal.fill" : "person.2.badge.gearshape")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(move.isSettled ? theme.good : .white)
                                Text(move.isSettled ? "attendance settled" : "settle attendance")
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
        switch state.selectedGroup?.name {
        case "house":
            return "quorum already hit. kira's on dessert, gus is on wine."
        case "college group chat":
            return "last hangout: 4 months ago. devon keeps trying. they remember."
        case "soccer sundays":
            return "10am at field 3. cleats, shin guards, a will to live."
        default:
            return "nina's bringing the lemon thing. iggy always says he's maybe coming."
        }
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
            PillView(status: status)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}
