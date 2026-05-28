import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    // MARK: - Theme
    var theme: FlakeTheme = .sunset

    // MARK: - Current user
    var currentUserID: UUID {
        authStatus == .sample
            ? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            : (backendProfile?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }

    var currentUser: Member = Member(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "you", handle: "@you", initials: "Y", avatarColorHex: "ff6b9d",
        score: 0, flakeCount: 0, showCount: 0, badges: []
    )

    // MARK: - Auth
    var authStatus: AuthStatus = .restoringSession
    var authErrorMessage: String?
    var backendProfile: BackendProfile?
    var pendingAppleSignInNonce: String?
    private var pendingJoinCode: String?
    private var liveSyncTask: Task<Void, Never>?
    private var isAppActive = false

    // MARK: - Loading state
    var isLoadingData = false
    var isBootstrappingData: Bool {
        authStatus == .signedIn && isLoadingData && groups.isEmpty
    }

    // MARK: - Groups & current group

    var groups: [FlakeGroup] = []
    var selectedGroupID: UUID = UUID()
    var selectedMoveIDByGroup: [UUID: UUID] = [:]

    var selectedGroup: FlakeGroup? {
        groups.first { $0.id == selectedGroupID } ?? groups.first
    }

    var selectedGroupIndex: Int? {
        groups.firstIndex { $0.id == selectedGroupID }
    }

    // MARK: - Members

    var activeFriends: [Member] {
        var all = selectedGroup?.members ?? []
        if !all.contains(where: { $0.id == currentUserID }) {
            all.append(currentUser)
        }
        return all
    }

    /// All moves in the selected group, scored from scratch.
    var activeLeaderboardMembers: [Member] { leaderboardMembers(since: nil) }

    /// Only moves on or after the current season's start date.
    /// Falls back to all moves when seasonStartedAt is nil (season not yet configured).
    var seasonLeaderboardMembers: [Member] {
        leaderboardMembers(since: selectedGroup?.seasonStartedAt)
    }

    /// Points the current user has earned in the last 7 days (settled + pending moves).
    var weeklyScoreDelta: Int {
        guard let group = selectedGroup else { return 0 }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return group.moves
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + pointDelta(for: currentUserID, in: $1) }
    }

    /// Core leaderboard computation. Pass `since:` to restrict to moves on/after that date.
    /// Starts every member's score/showCount/flakeCount from zero to avoid double-counting.
    func leaderboardMembers(since cutoff: Date?) -> [Member] {
        guard let group = selectedGroup else { return activeFriends }
        let moves = cutoff.map { c in group.moves.filter { $0.date >= c } } ?? group.moves

        // Build base set from group members (reset counts — applySnapshot already stored badges)
        var all: [Member] = group.members.map { m in
            var m = m; m.score = 0; m.showCount = 0; m.flakeCount = 0; return m
        }

        for i in all.indices {
            let id = all[i].id
            for move in moves {
                all[i].score += pointDelta(for: id, in: move)
                if move.isSettled {
                    switch move.attendance[id] {
                    case .showed: all[i].showCount += 1
                    case .missed: if !isExcused(id, for: move) { all[i].flakeCount += 1 }
                    case nil: break
                    }
                }
            }
        }

        // Merge current user (may or may not already be in the list)
        var user = currentUser; user.score = 0; user.showCount = 0; user.flakeCount = 0
        for move in moves {
            user.score += pointDelta(for: currentUserID, in: move)
            if move.isSettled {
                switch move.attendance[currentUserID] {
                case .showed: user.showCount += 1
                case .missed: if !isExcused(currentUserID, for: move) { user.flakeCount += 1 }
                case nil: break
                }
            }
        }
        if let idx = all.firstIndex(where: { $0.id == currentUserID }) {
            all[idx] = user
        } else {
            all.append(user)
        }
        return all
    }

    // MARK: - Current move

    var currentMove: Move = Move(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
        title: "no move yet.", subtitle: "create your first group to get started.",
        location: "", date: Date().addingTimeInterval(86400),
        creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        rsvps: [:], groupID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    )

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
    var attestationSheetMoveID: UUID? = nil   // nil = closed; non-nil = open for that move
    var featureScreen: FeatureScreen?

    var shouldShowAuthGate: Bool {
        authStatus == .signedOut || authStatus == .signingIn
    }

    // MARK: - Session restoration

    init() {
        // Kick off session restore immediately; UI stays on loading screen
        // until we know whether a stored token exists.
        Task { await restoreSession() }
    }

    func restoreSession() async {
        // Step 1: check stored auth token — no DB call, instant
        guard let userID = await FlakeBackend.shared.currentUserID() else {
            authStatus = .signedOut
            return
        }

        // Step 2: load the real profile from DB (or build a placeholder)
        // IMPORTANT: backendProfile must be set BEFORE authStatus = .signedIn
        // so currentUserID never returns the fake UUID while auth is active.
        let profile: BackendProfile
        do {
            if let fetched = try await FlakeBackend.shared.currentProfile() {
                profile = fetched
            } else {
                profile = BackendProfile(id: userID, displayName: "flaker",
                                         initials: "F", avatarColor: "ff6b9d")
            }
        } catch {
            print("❌ [Flake] restoreSession profile fetch failed:", error.localizedDescription)
            profile = BackendProfile(id: userID, displayName: "flaker",
                                     initials: "F", avatarColor: "ff6b9d")
        }

        // Step 3: commit everything atomically before revealing the app
        backendProfile = profile
        currentUser = Member(
            id: profile.id,
            name: profile.displayName,
            handle: "@\(profile.displayName.lowercased().replacingOccurrences(of: " ", with: ""))",
            initials: profile.initials,
            avatarColorHex: profile.avatarColor,
            score: 0, flakeCount: 0, showCount: 0, badges: [],
            joinedAt: profile.createdAt
        )
        authStatus = .signedIn   // ← only now, after backendProfile is guaranteed non-nil

        await loadBackendData()
        await processPendingJoinIfNeeded()
        startLiveSyncIfNeeded()
    }

    // MARK: - Season (derived from the selected group's real data)

    /// Which week of the season we're currently in, computed from season_started_at.
    var currentSeasonWeek: Int {
        guard let group = selectedGroup,
              let startedAt = group.seasonStartedAt else { return 1 }
        let weeks = Int(Date().timeIntervalSince(startedAt) / (7 * 86400)) + 1
        return max(1, min(weeks, group.seasonWeeks))
    }

    var currentSeasonTotalWeeks: Int { selectedGroup?.seasonWeeks ?? 12 }

    // Derived from the selected group's live leaderboard — always up to date.
    var season: Season {
        let members = activeLeaderboardMembers.sorted { $0.score > $1.score }
        let biggestFlake = members.max(by: {
            $0.flakeCount < $1.flakeCount ||
            ($0.flakeCount == $1.flakeCount && $0.score > $1.score)
        })
        return Season(
            number: selectedGroup?.season ?? 1,
            totalWeeks: selectedGroup?.seasonWeeks ?? 12,
            currentWeek: currentSeasonWeek,
            champion: members.first,
            biggestFlake: biggestFlake
        )
    }

    // MARK: - Attendance Votes ("who showed up?")
    // [moveID: [voterID: [subjectID: AttendanceStatus]]]
    var rawAttestationVotes: [UUID: [UUID: [UUID: AttendanceStatus]]] = [:]

    /// Returns majority-vote attendance for a move, or nil for members with no votes.
    /// Does NOT replace manual attendance — call site decides which to prefer.
    func derivedAttendance(for moveID: UUID) -> [UUID: AttendanceStatus] {
        guard let voterMap = rawAttestationVotes[moveID] else { return [:] }
        // Collect all subjects mentioned across all voters
        var showVotes: [UUID: Int] = [:]
        var totalVotes: [UUID: Int] = [:]
        for (_, subjectMap) in voterMap {
            for (subjectID, status) in subjectMap {
                totalVotes[subjectID, default: 0] += 1
                if status == .showed { showVotes[subjectID, default: 0] += 1 }
            }
        }
        var result: [UUID: AttendanceStatus] = [:]
        for (subjectID, total) in totalVotes {
            let showed = showVotes[subjectID] ?? 0
            // ≥50% majority → showed; strictly less → missed
            result[subjectID] = (showed * 2 >= total) ? .showed : .missed
        }
        return result
    }

    /// True if the current user has submitted attestation votes for this move.
    func hasAttested(moveID: UUID) -> Bool {
        rawAttestationVotes[moveID]?[currentUserID] != nil
    }

    /// How many distinct voters have submitted attestation for this move.
    func attestationVoterCount(moveID: UUID) -> Int {
        rawAttestationVotes[moveID]?.keys.count ?? 0
    }

    /// Submit the current user's "who showed up?" votes for a move.
    /// Updates local state immediately; persists in background.
    func submitAttestation(moveID: UUID, votes: [UUID: AttendanceStatus]) {
        guard !votes.isEmpty else { return }
        let uid = currentUserID

        // Update local attestation state
        if rawAttestationVotes[moveID] == nil { rawAttestationVotes[moveID] = [:] }
        rawAttestationVotes[moveID]![uid] = votes

        // Re-derive attendance and write into the move so scoring stays live
        applyDerivedAttendance(moveID: moveID)

        // Persist to backend
        guard authStatus == .signedIn else { return }
        Task {
            do {
                try await FlakeBackend.shared.submitAttendanceVotes(
                    moveID: moveID, voterID: uid, votes: votes
                )
            } catch {
                print("❌ [Flake] submitAttestation failed:", error.localizedDescription)
            }
        }
    }

    /// Writes vote-derived attendance into the move object so existing scoring code picks it up.
    /// Manual settlement (non-empty attendance) takes priority and is never overwritten.
    private func applyDerivedAttendance(moveID: UUID) {
        guard let gi = groups.firstIndex(where: { $0.moves.contains { $0.id == moveID } }),
              let mi = groups[gi].moves.firstIndex(where: { $0.id == moveID }) else { return }

        let move = groups[gi].moves[mi]
        // If already manually settled, don't touch it
        guard move.attendance.isEmpty else { return }

        let derived = derivedAttendance(for: moveID)
        guard !derived.isEmpty else { return }
        groups[gi].moves[mi].attendance = derived
    }

    // MARK: - Roast Reactions
    // Keyed by group ID → target member ID → emoji → total count
    var roastReactionsByGroup: [UUID: [UUID: [String: Int]]] = [:]
    // Keyed by group ID → target member ID → set of emojis the current user has reacted with
    var myRoastReactionsByGroup: [UUID: [UUID: Set<String>]] = [:]

    /// Counts for the selected group (used by ReactionChip).
    var roastReactionCounts: [UUID: [String: Int]] {
        selectedGroup.flatMap { roastReactionsByGroup[$0.id] } ?? [:]
    }

    /// My reactions for the selected group (used by ReactionChip).
    var myRoastReactions: [UUID: Set<String>] {
        selectedGroup.flatMap { myRoastReactionsByGroup[$0.id] } ?? [:]
    }

    /// Toggle a reaction on/off. Updates local state immediately and persists in background.
    func toggleRoastReaction(targetID: UUID, emoji: String) {
        guard let group = selectedGroup else { return }
        let gid    = group.id
        let season = group.season
        let uid    = currentUserID
        let isOn   = myRoastReactionsByGroup[gid]?[targetID]?.contains(emoji) == true

        if isOn {
            myRoastReactionsByGroup[gid]?[targetID]?.remove(emoji)
            let cur = roastReactionsByGroup[gid]?[targetID]?[emoji] ?? 1
            roastReactionsByGroup[gid]?[targetID]?[emoji] = max(0, cur - 1)
        } else {
            if myRoastReactionsByGroup[gid] == nil { myRoastReactionsByGroup[gid] = [:] }
            if myRoastReactionsByGroup[gid]![targetID] == nil { myRoastReactionsByGroup[gid]![targetID] = [] }
            myRoastReactionsByGroup[gid]![targetID]!.insert(emoji)
            if roastReactionsByGroup[gid] == nil { roastReactionsByGroup[gid] = [:] }
            if roastReactionsByGroup[gid]![targetID] == nil { roastReactionsByGroup[gid]![targetID] = [:] }
            roastReactionsByGroup[gid]![targetID]![emoji, default: 0] += 1
        }

        guard authStatus == .signedIn else { return }
        Task {
            do {
                if isOn {
                    try await FlakeBackend.shared.removeRoastReaction(
                        groupID: gid, targetUserID: targetID,
                        season: season, emoji: emoji, reactorID: uid
                    )
                } else {
                    try await FlakeBackend.shared.addRoastReaction(
                        groupID: gid, targetUserID: targetID,
                        season: season, emoji: emoji, reactorID: uid
                    )
                }
            } catch {
                print("❌ [Flake] toggleRoastReaction failed:", error.localizedDescription)
            }
        }
    }

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
        guard let vote = activeExcusedVote else { return }
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

        // Persist to backend
        if authStatus == .signedIn {
            let voteID = vote.id
            let uid = currentUserID
            let capturedChoice = choice
            Task {
                try? await FlakeBackend.shared.castBallot(
                    voteID: voteID, voterID: uid, choice: capturedChoice
                )
            }
        }
    }

    func requestExcusedAbsence(reason: String) {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let penalty = activeMove.flakePenalty(for: currentUserID)
        let requestID = UUID()
        excusedVotesByMove[activeMove.id] = ExcusedVote(
            id: requestID,
            petitioner: currentUser,
            move: activeMove,
            excuse: trimmed,
            approvers: [],
            deniers: [],
            closesAt: Date().addingTimeInterval(4 * 3600),
            pointsAtRisk: penalty
        )
        myVote = nil

        // Persist to backend
        if authStatus == .signedIn {
            let moveID = activeMove.id
            let uid = currentUserID
            Task {
                try? await FlakeBackend.shared.submitExcusedRequest(
                    moveID: moveID, userID: uid, reason: trimmed, pointsAtRisk: penalty
                )
            }
        }
    }

    func resolveActiveExcusedVote() {
        guard var vote = activeExcusedVote else { return }
        let outcome: ExcusedVoteOutcome = vote.approvalCount > vote.denyCount ? .approved : .denied
        vote.outcome = outcome
        excusedVotesByMove[activeMove.id] = vote

        guard authStatus == .signedIn else { return }
        let voteID     = vote.id
        let outcomeStr = outcome == .approved ? "approved" : "denied"
        Task {
            do {
                try await FlakeBackend.shared.resolveExcusedVote(voteID: voteID, outcome: outcomeStr)
            } catch {
                print("❌ [Flake] resolveExcusedVote failed:", error.localizedDescription)
            }
        }
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
        let moveID = UUID()
        var move = Move(
            id: moveID,
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

        // Persist to backend
        if authStatus == .signedIn {
            let gid = selectedGroupID
            let uid = currentUserID
            Task {
                do {
                    let created = try await FlakeBackend.shared.createMove(
                        groupID: gid, title: title, subtitle: subtitle,
                        location: location, date: date, creatorID: uid
                    )
                    // Replace the local move with the backend-assigned ID
                    await MainActor.run {
                        guard let gi = self.groups.firstIndex(where: { $0.id == gid }),
                              let mi = self.groups[gi].moves.firstIndex(where: { $0.id == moveID })
                        else { return }
                        let old = self.groups[gi].moves[mi]
                        let replacement = Move(
                            id: created.id,
                            title: old.title,
                            subtitle: old.subtitle,
                            location: old.location,
                            date: old.date,
                            creatorID: old.creatorID,
                            rsvps: old.rsvps,
                            groupID: old.groupID,
                            attendance: old.attendance
                        )
                        self.groups[gi].moves[mi] = replacement
                        // Update tracking dicts
                        let rsvp = self.myRSVPByMove.removeValue(forKey: moveID)
                        if let rsvp { self.myRSVPByMove[created.id] = rsvp }
                        if self.selectedMoveIDByGroup[gid] == moveID {
                            self.selectedMoveIDByGroup[gid] = created.id
                        }
                    }
                } catch {
                    // Local state already updated; backend failure is non-fatal
                }
            }
        }
    }

    func createGroup(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempID = UUID()
        let group = FlakeGroup(
            id: tempID, name: trimmed, members: [currentUser],
            moves: [], groupLeaderID: currentUserID,
            season: 1, seasonWeeks: 12, seasonStartedAt: Date(),
            userRank: 1, userScore: 0, userScoreGoal: 300,
            ranksSubtitle: "first season. nothing decided yet.",
            nextSummary: "no moves yet. create one."
        )
        groups.append(group)
        selectedGroupID = tempID

        if authStatus == .signedIn {
            let uid = currentUserID
            Task {
                do {
                    let created = try await FlakeBackend.shared.createGroup(name: trimmed, createdBy: uid)
                    await MainActor.run {
                        guard let i = self.groups.firstIndex(where: { $0.id == tempID }) else { return }
                        let patched = self.groups[i]
                        let updated = FlakeGroup(
                            id: created.id, name: patched.name, members: patched.members,
                            moves: patched.moves, groupLeaderID: created.createdBy,
                            season: patched.season, seasonWeeks: patched.seasonWeeks,
                            seasonStartedAt: patched.seasonStartedAt,
                            userRank: patched.userRank,
                            userScore: patched.userScore, userScoreGoal: patched.userScoreGoal,
                            ranksSubtitle: patched.ranksSubtitle, nextSummary: patched.nextSummary,
                            threadKey: created.threadKey
                        )
                        self.groups[i] = updated
                        if self.selectedGroupID == tempID { self.selectedGroupID = created.id }
                        SharedGroupStore.save(self.groups) // keep extension in sync
                    }
                    // Reload from backend to confirm group_members row was created
                    await loadBackendData()
                } catch {
                    print("❌ [Flake] createGroup backend failed:", error.localizedDescription)
                    await MainActor.run {
                        self.authErrorMessage = "group saved locally but failed to sync: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func updateGroupSeason(seasonNumber: Int, seasonWeeks: Int, seasonStartedAt: Date) async {
        guard let group = selectedGroup,
              group.groupLeaderID == currentUserID else { return }
        // Update local state immediately
        if let i = groups.firstIndex(where: { $0.id == group.id }) {
            groups[i].season = seasonNumber
            groups[i].seasonWeeks = seasonWeeks
            groups[i].seasonStartedAt = seasonStartedAt
        }
        do {
            try await FlakeBackend.shared.updateGroupSeason(
                groupID: group.id,
                seasonNumber: seasonNumber,
                seasonWeeks: seasonWeeks,
                seasonStartedAt: seasonStartedAt
            )
        } catch {
            print("❌ [Flake] updateGroupSeason failed:", error.localizedDescription)
            authErrorMessage = "failed to save season settings: \(error.localizedDescription)"
        }
    }

    func joinGroup(code: String) async {
        guard authStatus == .signedIn else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        do {
            guard let backendGroup = try await FlakeBackend.shared.findGroup(threadKey: trimmed) else {
                authErrorMessage = "group not found. check the code."
                return
            }
            try await FlakeBackend.shared.joinGroup(groupID: backendGroup.id)
            await loadBackendData()
            pendingJoinCode = nil
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    /// Handles flake://join/CODE deep links sent via iMessage invites.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "flake" else { return }
        // flake://join/THREADKEY
        if url.host == "join" {
            let code = (url.pathComponents.dropFirst().first ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            guard !code.isEmpty else { return }
            pendingJoinCode = code
            if authStatus == .signedIn {
                Task { await processPendingJoinIfNeeded() }
            }
        }
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

        // Persist to backend
        if authStatus == .signedIn {
            let moveID = activeMove.id
            let uid = currentUserID
            Task {
                try? await FlakeBackend.shared.updateRSVP(
                    moveID: moveID, userID: uid, status: status
                )
            }
        }
    }

    // MARK: - Delete move

    func deleteMove(_ move: Move) {
        guard authStatus == .signedIn else { return }
        // Optimistic removal
        guard let gi = groups.firstIndex(where: { $0.id == move.groupID }) else { return }
        let previousMoves = groups[gi].moves
        groups[gi].moves.removeAll { $0.id == move.id }
        if selectedMoveIDByGroup[move.groupID] == move.id {
            selectedMoveIDByGroup[move.groupID] = groups[gi].moves.first?.id
        }

        let moveID = move.id
        let groupID = move.groupID
        Task {
            do {
                try await FlakeBackend.shared.deleteMove(moveID: moveID)
            } catch {
                print("❌ [Flake] deleteMove failed:", error.localizedDescription)
                // Roll back
                await MainActor.run {
                    if let gi2 = self.groups.firstIndex(where: { $0.id == groupID }) {
                        self.groups[gi2].moves = previousMoves
                    }
                    self.authErrorMessage = "couldn't delete move: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Leave / delete group

    func leaveGroup(_ group: FlakeGroup) {
        guard authStatus == .signedIn else { return }
        let snapshot = groups
        groups.removeAll { $0.id == group.id }
        if selectedGroupID == group.id { selectedGroupID = groups.first?.id ?? UUID() }
        SharedGroupStore.save(groups)

        let gid = group.id
        Task {
            do {
                try await FlakeBackend.shared.leaveGroup(groupID: gid)
            } catch {
                print("❌ [Flake] leaveGroup failed:", error.localizedDescription)
                await MainActor.run {
                    self.groups = snapshot
                    self.authErrorMessage = "couldn't leave group: \(error.localizedDescription)"
                }
            }
        }
    }

    func deleteGroup(_ group: FlakeGroup) {
        guard authStatus == .signedIn else { return }
        let snapshot = groups
        groups.removeAll { $0.id == group.id }
        if selectedGroupID == group.id { selectedGroupID = groups.first?.id ?? UUID() }
        SharedGroupStore.save(groups)

        let gid = group.id
        Task {
            do {
                try await FlakeBackend.shared.deleteGroup(groupID: gid)
            } catch {
                print("❌ [Flake] deleteGroup failed:", error.localizedDescription)
                // Roll back so the user knows it didn't work
                await MainActor.run {
                    self.groups = snapshot
                    if self.groups.contains(where: { $0.id == gid }) {
                        self.selectedGroupID = gid
                    }
                    self.authErrorMessage = "couldn't delete group: \(error.localizedDescription)"
                }
            }
        }
    }

    func settleActiveMove(attendance: [UUID: AttendanceStatus]) {
        guard let selectedGroupIndex,
              let activeMoveIndex else { return }
        groups[selectedGroupIndex].moves[activeMoveIndex].attendance = attendance

        // Persist to backend
        if authStatus == .signedIn {
            let moveID = activeMove.id
            let capturedAttendance = attendance
            Task {
                try? await FlakeBackend.shared.recordAttendance(
                    moveID: moveID, attendance: capturedAttendance
                )
            }
        }
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

    private func ranksSubtitle(
        group: FlakeGroup,
        sortedScores: [(UUID, String, Int)],
        myRank: Int,
        userID: UUID
    ) -> String {
        let leader      = sortedScores.first.map { (id: $0.0, name: $0.1, score: $0.2) }
        let leaderName  = leader?.name ?? "someone"
        let iAmLeading  = leader?.id == userID
        let startedAt   = group.seasonStartedAt ?? Date()
        let weeksIn     = max(1, Int(Date().timeIntervalSince(startedAt) / (7 * 86400)) + 1)
        let currentWeek = min(weeksIn, group.seasonWeeks)
        let weeksLeft   = max(0, group.seasonWeeks - currentWeek)

        if group.moves.isEmpty {
            return "no moves yet. first one to show up sets the tone."
        }
        if weeksLeft == 0 {
            return iAmLeading
                ? "season's over. the crown is yours."
                : "season's over. \(leaderName) took it."
        }
        if weeksLeft == 1 {
            return iAmLeading
                ? "one week left. the crown is yours to lose."
                : "one week left. \(leaderName) leads. close the gap."
        }
        if weeksLeft <= 3 {
            return iAmLeading
                ? "\(weeksLeft) weeks left. you lead. don't get comfortable."
                : "\(weeksLeft) weeks left. \(leaderName) is ahead. anything can happen."
        }
        if currentWeek <= 2 {
            return "season is young. nothing decided yet."
        }
        return iAmLeading
            ? "week \(currentWeek) of \(group.seasonWeeks). you lead. hold it."
            : "week \(currentWeek) of \(group.seasonWeeks). \(leaderName) leads. still time."
    }

    private func computeBadges(
        rank: Int, memberCount: Int,
        showCount: Int, flakeCount: Int,
        score: Int, total: Int,
        moveLeaderCount: Int, topLeaderCount: Int,
        topScore: Int,
        sortedStats: [(UUID, Int)]   // (id, flakeCount) sorted by score desc
    ) -> [Member.Badge] {
        var badges: [Member.Badge] = []
        let showRate = total > 0 ? Double(showCount) / Double(total) : 0

        // Gold badges
        if rank == 1 && total >= 3 {
            badges.append(.init(name: "season leader", isGold: true))
        }
        if flakeCount == 0 && showCount >= 4 {
            badges.append(.init(name: "zero flakes", isGold: true))
        }
        if showRate >= 0.9 && showCount >= 5 {
            badges.append(.init(name: "most reliable", isGold: true))
        }
        if moveLeaderCount > 0 && moveLeaderCount == topLeaderCount && topLeaderCount >= 2 {
            badges.append(.init(name: "calling shots", isGold: true))
        }

        // Regular badges
        if rank == memberCount && memberCount >= 3 {
            badges.append(.init(name: "basement dweller", isGold: false))
        }
        if showRate >= 0.75 && showCount >= 3 && flakeCount > 0 {
            badges.append(.init(name: "full sender", isGold: false))
        }
        let biggestFlakeID = sortedStats.max(by: { $0.1 < $1.1 })?.0
        if let bfID = biggestFlakeID, bfID == sortedStats.first(where: { $0.0 == bfID })?.0,
           flakeCount >= 3 && flakeCount == sortedStats.map({ $0.1 }).max() {
            badges.append(.init(name: "flake of the szn", isGold: false))
        }
        if showCount == 0 && total == 0 {
            badges.append(.init(name: "ghost", isGold: false))
        }
        if score == topScore && rank == 1 && total >= 3 {
            // already have season leader
        } else if score < 0 {
            badges.append(.init(name: "in the red", isGold: false))
        }

        return badges
    }

    func continueWithSampleData() {
        currentUser = Member.currentUser
        groups = FlakeGroup.sampleGroups
        selectedGroupID = FlakeGroup.sampleGroups[0].id
        authStatus = .sample
        authErrorMessage = nil
        pendingJoinCode = nil
        stopLiveSync()
    }

    func signInWithApple(identityToken: String, nonce: String, displayName: String) async {
        authStatus = .signingIn
        authErrorMessage = nil
        do {
            let profile = try await FlakeBackend.shared.signInWithApple(
                identityToken: identityToken,
                nonce: nonce,
                displayName: displayName
            )
            backendProfile = profile
            currentUser = Member(
                id: profile.id,
                name: profile.displayName,
                handle: "@\(profile.displayName.lowercased().replacingOccurrences(of: " ", with: ""))",
                initials: profile.initials,
                avatarColorHex: profile.avatarColor,
                score: 0, flakeCount: 0, showCount: 0, badges: []
            )
            authStatus = .signedIn
            await loadBackendData()
            await processPendingJoinIfNeeded()
            startLiveSyncIfNeeded()
        } catch {
            authErrorMessage = error.localizedDescription
            authStatus = .signedOut
            stopLiveSync()
        }
    }

    func handleScenePhaseChanged(_ phase: ScenePhase) {
        isAppActive = (phase == .active)
        guard isAppActive else {
            stopLiveSync()
            return
        }
        if authStatus == .signedIn {
            Task { await loadBackendData() }
            startLiveSyncIfNeeded()
        }
    }

    private func processPendingJoinIfNeeded() async {
        guard authStatus == .signedIn,
              let code = pendingJoinCode,
              !code.isEmpty else { return }
        await joinGroup(code: code)
    }

    private func startLiveSyncIfNeeded() {
        guard liveSyncTask == nil, isAppActive, authStatus == .signedIn else { return }
        liveSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard let self else { return }
                if Task.isCancelled { return }
                if self.isAppActive && self.authStatus == .signedIn {
                    await self.loadBackendData()
                }
            }
        }
    }

    private func stopLiveSync() {
        liveSyncTask?.cancel()
        liveSyncTask = nil
    }

    func loadBackendData() async {
        guard authStatus == .signedIn, let profile = backendProfile else { return }
        isLoadingData = true
        defer { isLoadingData = false }
        do {
            let snapshot = try await FlakeBackend.shared.loadAllData(for: profile.id)
            applySnapshot(snapshot, userID: profile.id)
            await loadRoastReactions()
        } catch {
            print("❌ [Flake] loadBackendData failed:", error.localizedDescription)
            authErrorMessage = "couldn't sync: \(error.localizedDescription)"
        }
    }

    private func loadRoastReactions() async {
        guard authStatus == .signedIn, let profile = backendProfile, !groups.isEmpty else { return }
        do {
            let all = try await FlakeBackend.shared.loadRoastReactions(groupIDs: groups.map(\.id))
            var countsByGroup:  [UUID: [UUID: [String: Int]]]   = [:]
            var myByGroup:      [UUID: [UUID: Set<String>]]     = [:]
            for r in all {
                countsByGroup[r.groupID, default: [:]][r.targetUserID, default: [:]][r.emoji, default: 0] += 1
                if r.reactorID == profile.id {
                    if myByGroup[r.groupID] == nil         { myByGroup[r.groupID] = [:] }
                    if myByGroup[r.groupID]![r.targetUserID] == nil { myByGroup[r.groupID]![r.targetUserID] = [] }
                    myByGroup[r.groupID]![r.targetUserID]!.insert(r.emoji)
                }
            }
            roastReactionsByGroup   = countsByGroup
            myRoastReactionsByGroup = myByGroup
        } catch {
            print("❌ [Flake] loadRoastReactions failed:", error.localizedDescription)
        }
    }

    private func applySnapshot(_ snapshot: BackendSnapshot, userID: UUID) {
        let loaded = snapshot.toFlakeGroups(currentUserID: userID)

        groups = loaded
        if let first = loaded.first {
            // Only reset selection if the current group is no longer in the list
            if !loaded.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = first.id
            }
        }
        SharedGroupStore.save(loaded) // keep extension in sync

        // Compute per-member stats, ranks, badges, and derived group fields
        for i in groups.indices {
            let group = groups[i]
            let settledMoves = group.moves.filter { $0.isSettled }

            // ── Per-member show/flake counts ──────────────────────────────────
            struct MemberStats {
                var id: UUID; var name: String
                var score: Int; var showCount: Int; var flakeCount: Int
            }
            var stats: [MemberStats] = group.members.map { m in
                var shows = 0; var flakes = 0
                for move in settledMoves {
                    switch move.attendance[m.id] {
                    case .showed: shows += 1
                    case .missed:
                        if !isExcused(m.id, for: move) { flakes += 1 }
                    case nil: break
                    }
                }
                let score = group.moves.reduce(0) { $0 + pointDelta(for: m.id, in: $1) }
                return MemberStats(id: m.id, name: m.name,
                                   score: score, showCount: shows, flakeCount: flakes)
            }
            let sortedStats = stats.sorted { $0.score > $1.score }

            // ── Compute move-leader counts (for "calling shots" badge) ─────────
            var moveLeaderCount: [UUID: Int] = [:]
            for move in group.moves { moveLeaderCount[move.creatorID, default: 0] += 1 }
            let topLeaderCount = moveLeaderCount.values.max() ?? 0

            // ── Write computed stats + badges back to members ──────────────────
            for j in groups[i].members.indices {
                let memberID = groups[i].members[j].id
                guard let s = stats.first(where: { $0.id == memberID }) else { continue }
                let rank = (sortedStats.firstIndex(where: { $0.id == memberID }) ?? 0) + 1
                let total = s.showCount + s.flakeCount

                groups[i].members[j].showCount  = s.showCount
                groups[i].members[j].flakeCount = s.flakeCount
                groups[i].members[j].badges     = computeBadges(
                    rank: rank, memberCount: group.members.count,
                    showCount: s.showCount, flakeCount: s.flakeCount,
                    score: s.score, total: total,
                    moveLeaderCount: moveLeaderCount[memberID] ?? 0,
                    topLeaderCount: topLeaderCount,
                    topScore: sortedStats.first?.score ?? 0,
                    sortedStats: sortedStats.map { ($0.id, $0.flakeCount) }
                )
            }

            // ── Current user group-level fields ───────────────────────────────
            let myStats  = stats.first(where: { $0.id == userID })
            let myScore  = myStats?.score ?? 0
            let topScore = sortedStats.first?.score ?? 0
            let myRank   = (sortedStats.firstIndex(where: { $0.id == userID }) ?? 0) + 1

            groups[i].userScore     = myScore
            groups[i].userRank      = myRank
            groups[i].userScoreGoal = topScore > myScore ? topScore : myScore + 50
            groups[i].ranksSubtitle = ranksSubtitle(
                group: groups[i], sortedScores: sortedStats.map { ($0.id, $0.name, $0.score) },
                myRank: myRank, userID: userID
            )
        }

        // Also update currentUser's joinedAt from backendProfile (survives group reloads)
        if let profile = backendProfile {
            currentUser.joinedAt = profile.createdAt
        }

        // Rebuild excused votes across all members
        let allMembers = loaded.flatMap(\.members)
        excusedVotesByMove = snapshot.toExcusedVotes(members: allMembers)

        // Load attestation votes and apply derived attendance to unsettled moves
        var newAttestation: [UUID: [UUID: [UUID: AttendanceStatus]]] = [:]
        for (moveID, rows) in snapshot.attestationVotesByMove {
            var voterMap: [UUID: [UUID: AttendanceStatus]] = [:]
            for row in rows {
                if voterMap[row.voterID] == nil { voterMap[row.voterID] = [:] }
                voterMap[row.voterID]![row.subjectID] =
                    row.vote == "showed" ? .showed : .missed
            }
            newAttestation[moveID] = voterMap
        }
        rawAttestationVotes = newAttestation

        // Write derived attendance into any unsettled past moves
        for gi in groups.indices {
            for mi in groups[gi].moves.indices {
                let move = groups[gi].moves[mi]
                if move.date < Date() && move.attendance.isEmpty {
                    let derived = derivedAttendance(for: move.id)
                    if !derived.isEmpty {
                        groups[gi].moves[mi].attendance = derived
                    }
                }
            }
        }

        // Auto-resolve any votes that have passed their close time
        for (moveID, vote) in excusedVotesByMove where vote.outcome == .pending && vote.closesAt < Date() {
            let outcome: ExcusedVoteOutcome = vote.approvalCount > vote.denyCount ? .approved : .denied
            excusedVotesByMove[moveID]?.outcome = outcome
            // Push to backend (idempotent — multiple clients calling this is fine)
            let vid = vote.id
            let outcomeStr = outcome == .approved ? "approved" : "denied"
            Task {
                try? await FlakeBackend.shared.resolveExcusedVote(voteID: vid, outcome: outcomeStr)
            }
        }

        // Sync current user's RSVPs
        myRSVPByMove = [:]
        for group in loaded {
            for move in group.moves {
                if let status = move.rsvps[userID] {
                    myRSVPByMove[move.id] = status
                }
            }
        }
    }

    func signOut() async {
        do {
            try await FlakeBackend.shared.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
        backendProfile = nil
        authStatus = .signedOut
        groups = []
        selectedGroupID = UUID()
        excusedVotesByMove = [:]
        myRSVPByMove = [:]
        roastReactionsByGroup = [:]
        myRoastReactionsByGroup = [:]
        rawAttestationVotes = [:]
        pendingAppleSignInNonce = nil
        pendingJoinCode = nil
        stopLiveSync()
        currentUser = Member(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "you", handle: "@you", initials: "Y", avatarColorHex: "ff6b9d",
            score: 0, flakeCount: 0, showCount: 0, badges: []
        )
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

    enum AuthStatus {
        case restoringSession   // startup: checking for stored token
        case signedOut
        case signingIn
        case signedIn
        case sample
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
                   ], groupLeaderID: Member.sampleMembers[0].id,
                   season: 3, seasonWeeks: 12, seasonStartedAt: Date(),
                   userRank: 4, userScore: 196, userScoreGoal: 300,
                   ranksSubtitle: "five weeks left. nothing is decided. someone will be crowned. someone will be cooked.",
                   nextSummary: "thursday · luca's · 4 locked in · 2 days out."),
        FlakeGroup(id: UUID(), name: "house", members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)),
                   moves: [
                       Move.sampleMove(title: "sunday dinner.", subtitle: "your move.", location: "home", daysOut: 3, creatorID: Member.currentUser.id, members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)), rsvps: [.lockedIn, .lockedIn, .lockedIn, .lockedIn]),
                       Move.sampleMove(title: "friday movie.", subtitle: "couch quorum.", location: "living room", daysOut: 8, creatorID: Member.currentUser.id, members: [Member.currentUser] + Array(Member.sampleMembers.prefix(3)), rsvps: [.lockedIn, .sendingIt, .silent, .silent]),
                   ], groupLeaderID: Member.currentUser.id,
                   season: 2, seasonWeeks: 12, seasonStartedAt: Date(),
                   userRank: 1, userScore: 318, userScoreGoal: 335,
                   ranksSubtitle: "one week left. the household crown is yours to lose.",
                   nextSummary: "sunday dinner · your move · quorum hit."),
        FlakeGroup(id: UUID(), name: "college group chat", members: Member.sampleMembers,
                   moves: [
                       Move.sampleMove(title: "no move scheduled.", subtitle: "last hangout: 4 months ago.", location: "soon", daysOut: 14, creatorID: Member.sampleMembers[0].id, members: Member.sampleMembers, rsvps: [.lockedIn, .lockedIn, .sendingIt, .sendingIt, .silent, .silent, .silent, .silent]),
                   ], groupLeaderID: Member.sampleMembers[0].id,
                   season: 4, seasonWeeks: 12, seasonStartedAt: Date(),
                   userRank: 11, userScore: 8, userScoreGoal: 300,
                   ranksSubtitle: "you're the basement. nothing to defend, only to climb.",
                   nextSummary: "no move scheduled · they're tired of you."),
        FlakeGroup(id: UUID(), name: "soccer sundays", members: Array(Member.sampleMembers.prefix(6)),
                   moves: [
                       Move.sampleMove(title: "sunday kickoff.", subtitle: "field 3.", location: "field 3", daysOut: 3, creatorID: Member.sampleMembers[1].id, members: Array(Member.sampleMembers.prefix(6)), rsvps: [.lockedIn, .lockedIn, .lockedIn, .silent, .lockedIn, .lockedIn]),
                   ], groupLeaderID: Member.sampleMembers[1].id,
                   season: 1, seasonWeeks: 12, seasonStartedAt: Date(),
                   userRank: 3, userScore: 84, userScoreGoal: 200,
                   ranksSubtitle: "season is young. anyone can take it.",
                   nextSummary: "sunday 10am · field 3 · 5 locked in."),
    ]
}

// MARK: - Roast generation

extension AppState {
    /// Generates roasts from real member stats in the selected group.
    /// Intensity 0 = polite, 3 = unhinged.
    func generateRoasts(intensity: Int) -> [Roast] {
        guard let group = selectedGroup else { return [] }
        let members = activeLeaderboardMembers.filter { $0.id != currentUserID }
        guard !members.isEmpty else { return [] }
        let level = min(max(intensity, 0), 3)
        return members.map { member in
            roast(for: member, in: group, intensity: level)
        }
    }

    private func roast(for member: Member, in group: FlakeGroup, intensity _: Int) -> Roast {
        let name = member.name.lowercased()
        let total = member.flakeCount + member.showCount
        let flakeRate: Double = total > 0 ? Double(member.flakeCount) / Double(total) : 0
        let isFlaker = flakeRate >= 0.4
        let isRocker = member.showCount >= 3 && flakeRate < 0.2
        let isGhost  = total == 0
        let isMaybe  = flakeRate >= 0.2 && flakeRate < 0.4

        // Stable seed so the roast doesn't change on every re-render
        let seed = abs(member.id.hashValue) % 3

        let text: String
        switch (isGhost, isFlaker, isRocker, isMaybe) {
        case (true, _, _, _):
            text = ["\(name) has never attended a move. they are a *myth.* a *legend.* a name on a list that haunts us all.",
                    "\(name) is in this group the way *wifi* is in an elevator — listed, present, *completely non-functional.*",
                    "\(name) joined this group and immediately *transcended the concept of attendance.* spiritually unavailable."][seed]
        case (_, true, _, _):
            let n = member.flakeCount
            text = ["\(name) has flaked \(n) time\(n == 1 ? "" : "s"). flaking is no longer an event for \(name) — it's a *lifestyle brand.*",
                    "\(name)'s brain processes the word 'thursday' like a dog processes *algebra.* complete shutdown. fascinating.",
                    "\(name) locked in, ghosted at 11pm, and posted a story from a *different bar.* \(n) times. *iconic.*"][seed]
        case (_, _, true, _):
            text = ["\(name) hasn't been home on a move night since the *obama administration.* their plants are *dust.* they ARE the function.",
                    "\(name) is \(member.showCount) for \(total). scientists are *studying this.* no one shows up this much by accident.",
                    "\(name) has \(member.score) points and zero regrets. they are *built different* in a way that should concern a doctor."][seed]
        case (_, _, _, true):
            text = ["\(name) has said yes \(member.showCount) times and bailed \(member.flakeCount). *submit a verb that means something.*",
                    "\(name)'s RSVP is a coin flip with extra steps. \(member.showCount) shows, \(member.flakeCount) flakes. *wild.*",
                    "\(name) commits about half the time. statistically, so does a coin. *the coin doesn't have a phone.*"][seed]
        default:
            text = ["\(name) has achieved a level of consistency only seen in *cryptids* and extremely good Wi-Fi. \(member.score) pts.",
                    "\(name) shows up \(member.showCount) times and scores \(member.score) points. this is *not normal behavior.* we stan.",
                    "\(name) is \(member.showCount) for \(total). the *load-bearing member* of this group. do not lose \(name)."][seed]
        }

        // Reaction counts seeded from member stats so they're stable
        let fireCount  = max(1, (member.showCount * 2 + seed + 1) % 9 + 1)
        let skullCount = max(1, (member.flakeCount * 2 + seed + 2) % 7 + 1)

        // timeAgo from last settled move this member was recorded in
        let lastMove = group.moves
            .filter { $0.isSettled && $0.attendance[member.id] != nil }
            .sorted { $0.date > $1.date }
            .first
        let timeAgo: String
        if let last = lastMove {
            let hours = Int(-last.date.timeIntervalSinceNow / 3600)
            if hours < 24        { timeAgo = "\(max(1, hours))h ago" }
            else if hours < 168  { timeAgo = "\(hours / 24)d ago" }
            else                 { timeAgo = "\(hours / 168)w ago" }
        } else {
            timeAgo = "this season"
        }

        return Roast(
            id: member.id,   // stable ID — same member, same card
            targetName: "re: \(name)",
            text: text,
            timeAgo: timeAgo,
            reactions: [
                Roast.Reaction(emoji: "🔥", count: fireCount,  isHot: true),
                Roast.Reaction(emoji: "💀", count: skullCount, isHot: false),
            ]
        )
    }
}
