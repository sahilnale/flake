import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    // MARK: - Theme
    var theme: FlakeTheme = .sunset

    // MARK: - Current user
    let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var currentUser: Member = Member.currentUser

    // MARK: - Groups & current group

    var groups: [FlakeGroup] = FlakeGroup.sampleGroups
    var selectedGroupID: UUID = FlakeGroup.sampleGroups[0].id
    var selectedMoveIDByGroup: [UUID: UUID] = [:]

    var selectedGroup: FlakeGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    var selectedGroupIndex: Int? {
        groups.firstIndex { $0.id == selectedGroupID }
    }

    // MARK: - Members

    var members: [Member] = Member.sampleMembers

    var activeFriends: [Member] {
        var all = selectedGroup?.members ?? members
        if !all.contains(where: { $0.id == currentUserID }) {
            all.append(currentUser)
        }
        return all
    }

    var activeLeaderboardMembers: [Member] {
        var all = activeFriends
        if let selectedGroup {
            all = all.map { member in
                var member = member
                member.score += scoreAdjustment(for: member.id, in: selectedGroup)
                for move in selectedGroup.moves where move.isSettled {
                    switch move.attendance[member.id] {
                    case .showed:
                        member.showCount += 1
                    case .missed:
                        if !isExcused(member.id, for: move) {
                            member.flakeCount += 1
                        }
                    case nil:
                        break
                    }
                }
                return member
            }

            var user = currentUser
            user.score = selectedGroup.userScore
            user.score += scoreAdjustment(for: currentUserID, in: selectedGroup)
            for move in selectedGroup.moves where move.isSettled {
                switch move.attendance[currentUserID] {
                case .showed:
                    user.showCount += 1
                case .missed:
                    if !isExcused(currentUserID, for: move) {
                        user.flakeCount += 1
                    }
                case nil:
                    break
                }
            }
            if let index = all.firstIndex(where: { $0.id == currentUserID }) {
                all[index] = user
            } else {
                all.append(user)
            }
        }
        return all
    }

    // MARK: - Current move

    var currentMove: Move = Move.sampleMove

    var activeMove: Move {
        guard let selectedGroup else { return currentMove }
        if let selectedMoveID = selectedMoveIDByGroup[selectedGroup.id],
           let selectedMove = selectedGroup.moves.first(where: { $0.id == selectedMoveID }) {
            return selectedMove
        }
        return selectedGroup.currentMove ?? currentMove
    }

    var activeMoves: [Move] {
        selectedGroup?.moves.sorted { $0.date < $1.date } ?? [currentMove]
    }

    var activeMoveIndex: Int? {
        guard let selectedGroupIndex,
              let moveIndex = groups[selectedGroupIndex].moves.firstIndex(where: { $0.id == activeMove.id }) else {
            return nil
        }
        return moveIndex
    }

    // MARK: - Current RSVP
    var myRSVPByMove: [UUID: RSVPStatus] = [:]

    var myRSVP: RSVPStatus? {
        get { myRSVPByMove[activeMove.id] }
        set { myRSVPByMove[activeMove.id] = newValue }
    }

    // MARK: - Navigation
    var selectedTab: Tab = .home
    var rsvpSheetVisible = false
    var voteSheetVisible = false
    var createMoveSheetVisible = false
    var calendarSheetVisible = false
    var excusedRequestSheetVisible = false
    var attendanceSheetVisible = false
    var featureScreen: FeatureScreen?

    // MARK: - Season
    var season = Season(number: 3, totalWeeks: 12, currentWeek: 7,
                        champion: Member.sampleMembers.first,
                        biggestFlake: Member.sampleMembers.last)

    // MARK: - Vote
    var excusedVotesByMove: [UUID: ExcusedVote] = [:]
    var myVoteByMove: [UUID: ExcusedVoteChoice] = [:]

    var activeExcusedVote: ExcusedVote? {
        excusedVotesByMove[activeMove.id]
    }

    var myVote: ExcusedVoteChoice? {
        get { myVoteByMove[activeMove.id] }
        set { myVoteByMove[activeMove.id] = newValue }
    }

    func castVote(_ choice: ExcusedVoteChoice) {
        guard activeExcusedVote != nil else { return }
        if myVote == choice { return }
        switch myVote {
        case .approve:
            excusedVotesByMove[activeMove.id]?.approvers.removeAll { $0.id == currentUserID }
        case .deny:
            excusedVotesByMove[activeMove.id]?.deniers.removeAll { $0.id == currentUserID }
        case nil:
            break
        }

        switch choice {
        case .approve:
            excusedVotesByMove[activeMove.id]?.approvers.append(currentUser)
        case .deny:
            excusedVotesByMove[activeMove.id]?.deniers.append(currentUser)
        }
        myVote = choice
    }

    func requestExcusedAbsence(reason: String) {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let penalty = activeMove.flakePenalty(for: currentUserID)
        excusedVotesByMove[activeMove.id] = ExcusedVote(
            id: UUID(),
            petitioner: currentUser,
            move: activeMove,
            excuse: trimmed,
            approvers: [],
            deniers: [],
            closesAt: Date().addingTimeInterval(4 * 3600),
            pointsAtRisk: penalty
        )
        myVote = nil
    }

    func resolveActiveExcusedVote() {
        guard var vote = activeExcusedVote else { return }
        vote.outcome = vote.approvalCount > vote.denyCount ? .approved : .denied
        excusedVotesByMove[activeMove.id] = vote
    }

    func selectGroup(_ group: FlakeGroup) {
        selectedGroupID = group.id
        featureScreen = nil
    }

    func selectMove(_ move: Move) {
        selectedMoveIDByGroup[selectedGroupID] = move.id
    }

    var allEventEntries: [EventEntry] {
        groups.flatMap { group in
            group.moves.map { move in
                EventEntry(groupID: group.id, groupName: group.name, move: move)
            }
        }
        .sorted { $0.move.date < $1.move.date }
    }

    func selectEvent(_ entry: EventEntry) {
        selectedGroupID = entry.groupID
        selectedMoveIDByGroup[entry.groupID] = entry.move.id
        featureScreen = nil
        selectedTab = .home
    }

    func createMove(title: String, subtitle: String, location: String, date: Date) {
        guard let selectedGroupIndex else { return }
        var move = Move(
            id: UUID(),
            title: title,
            subtitle: subtitle,
            location: location,
            date: date,
            creatorID: currentUserID,
            rsvps: [currentUserID: .lockedIn],
            groupID: selectedGroupID
        )
        for member in groups[selectedGroupIndex].members where move.rsvps[member.id] == nil {
            move.rsvps[member.id] = .silent
        }
        groups[selectedGroupIndex].moves.append(move)
        selectedMoveIDByGroup[selectedGroupID] = move.id
        myRSVPByMove[move.id] = .lockedIn
    }

    func updateMyRSVP(_ status: RSVPStatus) {
        myRSVP = status
        guard let selectedGroupIndex,
              let activeMoveIndex else { return }
        groups[selectedGroupIndex].moves[activeMoveIndex].rsvps[currentUserID] = status
        if status != .flaked {
            excusedVotesByMove.removeValue(forKey: activeMove.id)
            myVoteByMove.removeValue(forKey: activeMove.id)
        }
    }

    func settleActiveMove(attendance: [UUID: AttendanceStatus]) {
        guard let selectedGroupIndex,
              let activeMoveIndex else { return }
        groups[selectedGroupIndex].moves[activeMoveIndex].attendance = attendance
    }

    func defaultAttendance(for move: Move) -> [UUID: AttendanceStatus] {
        var attendance: [UUID: AttendanceStatus] = [:]
        for member in activeFriends {
            let rsvp = move.rsvps[member.id] ?? .silent
            attendance[member.id] = rsvp == .flaked ? .missed : .showed
        }
        return attendance
    }

    func isExcused(_ memberID: UUID, for move: Move) -> Bool {
        guard let vote = excusedVotesByMove[move.id],
              vote.petitioner.id == memberID else { return false }
        return vote.isApproved
    }

    func pointDelta(for memberID: UUID, in move: Move, attendance: AttendanceStatus? = nil) -> Int {
        move.pointDelta(for: memberID, excusedApproved: isExcused(memberID, for: move), attendance: attendance)
    }

    func scoreAdjustment(for memberID: UUID, in group: FlakeGroup) -> Int {
        group.moves.reduce(0) { total, move in
            total + pointDelta(for: memberID, in: move)
        }
    }

    enum Tab: Int, CaseIterable {
        case home, ranks, roasts, you
        var icon: String {
            switch self {
            case .home:   return "house"
            case .ranks:  return "list.number"
            case .roasts: return "flame"
            case .you:    return "person.circle"
            }
        }
        var label: String {
            switch self {
            case .home:   return "home"
            case .ranks:  return "ranks"
            case .roasts: return "roasts"
            case .you:    return "you"
            }
        }
    }

    enum FeatureScreen {
        case groups
        case recap
    }

    struct EventEntry: Identifiable {
        let groupID: UUID
        let groupName: String
        let move: Move

        var id: String { "\(groupID.uuidString)-\(move.id.uuidString)" }
    }
}

// MARK: - Sample data

extension Member {
    static let currentUser = Member(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "maya",
        handle: "@maya",
        initials: "M",
        avatarColorHex: "ff6b9d",
        score: 196,
        flakeCount: 4,
        showCount: 28,
        badges: [
            .init(name: "clutch · saved 3 moves", isGold: true),
            .init(name: "on time always", isGold: false),
            .init(name: "runner up s02", isGold: false),
        ]
    )

    static let sampleMembers: [Member] = [
        Member(id: UUID(), name: "luca",  handle: "@luca",  initials: "LM", avatarColorHex: "ff6b9d", score: 284, flakeCount: 0, showCount: 11, badges: [.init(name: "champion s03", isGold: true)]),
        Member(id: UUID(), name: "nina",  handle: "@nina",  initials: "NK", avatarColorHex: "ff8c42", score: 271, flakeCount: 1, showCount: 11, badges: [.init(name: "most reliable", isGold: true)]),
        Member(id: UUID(), name: "ade",   handle: "@ade",   initials: "AT", avatarColorHex: "5eead4", score: 218, flakeCount: 1, showCount: 10, badges: []),
        Member(id: UUID(), name: "jamie", handle: "@jamie", initials: "JS", avatarColorHex: "ffd166", score: 174, flakeCount: 2, showCount:  9, badges: [.init(name: "most improved", isGold: false)]),
        Member(id: UUID(), name: "priya", handle: "@priya", initials: "PR", avatarColorHex: "93c5fd", score: 141, flakeCount: 2, showCount:  8, badges: []),
        Member(id: UUID(), name: "iggy",  handle: "@iggy",  initials: "IG", avatarColorHex: "c084ff", score:  98, flakeCount: 4, showCount:  6, badges: [.init(name: "full sender", isGold: false)]),
        Member(id: UUID(), name: "sam",   handle: "@sam",   initials: "SH", avatarColorHex: "86efac", score:  62, flakeCount: 3, showCount:  5, badges: []),
        Member(id: UUID(), name: "mo",    handle: "@mo",    initials: "MK", avatarColorHex: "fb7185", score: -14, flakeCount: 6, showCount:  2, badges: [.init(name: "flake of the szn", isGold: false)]),
    ]
}

extension Move {
    static let sampleMove: Move = {
        var m = Move(
            id: UUID(),
            title: "thursday at luca's.",
            subtitle: "the standing one.",
            location: "luca's place",
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            creatorID: Member.sampleMembers[0].id,
            rsvps: [:],
            groupID: UUID()
        )
        let members = Member.sampleMembers
        m.rsvps[members[0].id] = .lockedIn
        m.rsvps[members[1].id] = .lockedIn
        m.rsvps[members[2].id] = .lockedIn
        m.rsvps[members[3].id] = .lockedIn
        m.rsvps[members[4].id] = .sendingIt
        m.rsvps[members[5].id] = .sendingIt
        m.rsvps[members[6].id] = .flaked
        m.rsvps[members[7].id] = .silent
        return m
    }()

    static func sampleMove(title: String, subtitle: String, location: String, daysOut: Int, creatorID: UUID, members: [Member], rsvps: [RSVPStatus]) -> Move {
        var move = Move(
            id: UUID(),
            title: title,
            subtitle: subtitle,
            location: location,
            date: Calendar.current.date(byAdding: .day, value: daysOut, to: Date())!,
            creatorID: creatorID,
            rsvps: [:],
            groupID: UUID()
        )
        for (member, status) in zip(members, rsvps) {
            move.rsvps[member.id] = status
        }
        return move
    }
}

extension FlakeGroup {
    static let sampleGroups: [FlakeGroup] = [
        FlakeGroup(id: UUID(), name: "thursday crew", members: Member.sampleMembers,
                   moves: [
                       Move.sampleMove,
                       Move.sampleMove(title: "saturday tacos.", subtitle: "low stakes, high salsa.", location: "taco bell", daysOut: 4, creatorID: Member.sampleMembers[1].id, members: Member.sampleMembers, rsvps: [.lockedIn, .lockedIn, .silent, .sendingIt, .silent, .silent, .silent, .silent]),
                   ], season: 3, userRank: 4, userScore: 196, userScoreGoal: 300,
                   ranksSubtitle: "five weeks left. nothing is decided. someone will be crowned. someone will be cooked.",
                   nextSummary: "thursday · luca's · 4 locked in · 2 days out."),
        FlakeGroup(id: UUID(), name: "house", members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)),
                   moves: [
                       Move.sampleMove(title: "sunday dinner.", subtitle: "your move.", location: "home", daysOut: 3, creatorID: Member.currentUser.id, members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)), rsvps: [.lockedIn, .lockedIn, .lockedIn, .lockedIn]),
                       Move.sampleMove(title: "friday movie.", subtitle: "couch quorum.", location: "living room", daysOut: 8, creatorID: Member.currentUser.id, members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)), rsvps: [.lockedIn, .sendingIt, .silent, .silent]),
                   ], season: 2, userRank: 1, userScore: 318, userScoreGoal: 335,
                   ranksSubtitle: "one week left. the household crown is yours to lose.",
                   nextSummary: "sunday dinner · your move · quorum hit."),
        FlakeGroup(id: UUID(), name: "college group chat", members: Member.sampleMembers,
                   moves: [
                       Move.sampleMove(title: "no move scheduled.", subtitle: "last hangout: 4 months ago.", location: "soon", daysOut: 14, creatorID: Member.sampleMembers[0].id, members: Member.sampleMembers, rsvps: [.lockedIn, .lockedIn, .sendingIt, .sendingIt, .silent, .silent, .silent, .silent]),
                   ], season: 4, userRank: 11, userScore: 8, userScoreGoal: 300,
                   ranksSubtitle: "you're the basement. nothing to defend, only to climb.",
                   nextSummary: "no move scheduled · they're tired of you."),
        FlakeGroup(id: UUID(), name: "soccer sundays", members: Array(Member.sampleMembers.prefix(6)),
                   moves: [
                       Move.sampleMove(title: "sunday kickoff.", subtitle: "field 3.", location: "field 3", daysOut: 3, creatorID: Member.sampleMembers[1].id, members: Array(Member.sampleMembers.prefix(6)), rsvps: [.lockedIn, .lockedIn, .lockedIn, .silent, .lockedIn, .lockedIn]),
                   ], season: 1, userRank: 3, userScore: 84, userScoreGoal: 200,
                   ranksSubtitle: "season is young. anyone can take it.",
                   nextSummary: "sunday 10am · field 3 · 5 locked in."),
    ]
}

extension Roast {
    static func samples(intensity: Int) -> [Roast] {
        let sets: [[String]] = [
            [
                "mo couldn't make it this week. hope everything's okay.",
                "iggy says he's still figuring out his week.",
                "nina's been a real consistent friend lately.",
                "sam's been quiet — might be worth a check-in.",
            ],
            [
                "mo flaked. third time this month. *just saying.*",
                "iggy has hit 'maybe' so many times it's almost a *personality.*",
                "nina is on a heater. four weeks straight. *respect.*",
                "sam hasn't opened the app in over a week. *ghost watch.*",
            ],
            [
                "mo locked in monday, ghosted thursday at 11pm, posted a story from a different bar friday. *iconic.*",
                "iggy has said \"maybe\" *seventeen* times this season. submit a verb that means something, iggy.",
                "nina is 11 for 12 this season. she is now *structurally* incapable of staying home. someone check on her plants.",
                "sam has not opened this app in 11 days. *presumed missing.* last seen sending it.",
            ],
            [
                "mo flaked again. flaking isn't an event for mo anymore — it's a *lifestyle.* devastating commitment to the bit.",
                "iggy's brain processes the word 'thursday' the way a dog processes *algebra.* complete shutdown. fascinating.",
                "nina hasn't been home on a thursday since the *obama administration.* her plants are dust. she IS the function.",
                "sam has achieved a level of social ghosting only seen in *cryptids* and the wifi at your mom's house. legendary.",
            ],
        ]
        let level = min(max(intensity, 0), 3)
        let texts = sets[level]
        let names = ["mo", "iggy", "nina", "sam"]
        let times = ["2h ago", "1d ago", "2d ago", "3d ago"]
        return zip(zip(names, texts), times).map { pair in
            let name = pair.0.0
            let text = pair.0.1
            let time = pair.1
            return Roast(
                id: UUID(),
                targetName: "re: \(name)",
                text: text,
                timeAgo: time,
                reactions: [
                    Roast.Reaction(emoji: "🔥", count: Int.random(in: 3...8), isHot: true),
                    Roast.Reaction(emoji: "💀", count: Int.random(in: 1...6), isHot: false),
                ]
            )
        }
    }
}
