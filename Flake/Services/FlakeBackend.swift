import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum FlakeBackendError: LocalizedError {
    case supabasePackageMissing
    case missingUser
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .supabasePackageMissing: return "Supabase Swift package is not resolved yet."
        case .missingUser:           return "Supabase did not return an authenticated user."
        case .notAuthenticated:      return "No authenticated session found."
        }
    }
}

// MARK: - FlakeBackend

actor FlakeBackend {
    static let shared = FlakeBackend()

    #if canImport(Supabase)
    private let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: .init(auth: .init(storage: AppGroupAuthStorage()))
    )
    #endif

    // MARK: - Auth

    func signInWithApple(identityToken: String, nonce: String, displayName: String) async throws -> BackendProfile {
        #if canImport(Supabase)
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )
        let userID = session.user.id

        // Upsert handles both new users (insert) and returning users (no-op update).
        // Only set displayName/initials on first sign-in — existing rows keep their values.
        let newProfile = BackendProfile(
            id: userID,
            displayName: displayName.isEmpty ? "new flake" : displayName,
            initials: Self.initials(for: displayName),
            avatarColor: "ff6b9d"
        )
        try await client
            .from("profiles")
            .upsert(newProfile, onConflict: "id", ignoreDuplicates: true)
            .execute()

        // Now fetch back the canonical stored profile (may differ if user already existed)
        let stored: [BackendProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return stored.first ?? newProfile
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func currentUserID() async -> UUID? {
        #if canImport(Supabase)
        return try? await client.auth.session.user.id
        #else
        return nil
        #endif
    }

    func currentProfile() async throws -> BackendProfile? {
        #if canImport(Supabase)
        guard let user = try? await client.auth.session.user else { return nil }
        let response: [BackendProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value
        return response.first
        #else
        return nil
        #endif
    }

    func signOut() async throws {
        #if canImport(Supabase)
        try await client.auth.signOut()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Profile

    func loadProfile(userID: UUID) async throws -> BackendProfile? {
        #if canImport(Supabase)
        let response: [BackendProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return response.first
        #else
        return nil
        #endif
    }

    func updateProfile(_ profile: BackendProfile) async throws {
        #if canImport(Supabase)
        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id.uuidString)
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func loadProfiles(userIDs: [UUID]) async throws -> [BackendProfile] {
        #if canImport(Supabase)
        guard !userIDs.isEmpty else { return [] }
        let ids = userIDs.map(\.uuidString)
        let response: [BackendProfile] = try await client
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    // MARK: - Groups

    func loadGroups(for userID: UUID) async throws -> [BackendGroup] {
        #if canImport(Supabase)
        let memberships: [BackendGroupMember] = try await client
            .from("group_members")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        guard !memberships.isEmpty else { return [] }
        let groupIDs = memberships.map { $0.groupID.uuidString }
        let groups: [BackendGroup] = try await client
            .from("groups")
            .select()
            .in("id", values: groupIDs)
            .order("created_at", ascending: true)
            .execute()
            .value
        return groups
        #else
        return []
        #endif
    }

    func createGroup(name: String, createdBy _: UUID) async throws -> BackendGroup {
        #if canImport(Supabase)
        let sessionUID = try await currentSessionUserID()
        try await ensureProfileExists(userID: sessionUID)

        let groupID = UUID()
        let threadKey = String(groupID.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        var newGroup = BackendGroup(id: groupID, threadKey: threadKey, name: name,
                                   createdBy: sessionUID, createdAt: nil)
        newGroup = try await client
            .from("groups")
            .insert(newGroup)
            .select()
            .single()
            .execute()
            .value
        try await joinGroup(groupID: newGroup.id)
        return newGroup
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func updateGroupSeason(groupID: UUID, seasonNumber: Int, seasonWeeks: Int, seasonStartedAt: Date) async throws {
        #if canImport(Supabase)
        struct SeasonUpdate: Encodable {
            let seasonNumber: Int
            let seasonWeeks: Int
            let seasonStartedAt: Date
            enum CodingKeys: String, CodingKey {
                case seasonNumber    = "season_number"
                case seasonWeeks     = "season_weeks"
                case seasonStartedAt = "season_started_at"
            }
        }
        let payload = SeasonUpdate(seasonNumber: seasonNumber, seasonWeeks: seasonWeeks, seasonStartedAt: seasonStartedAt)
        try await client
            .from("groups")
            .update(payload)
            .eq("id", value: groupID.uuidString)
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func findGroup(threadKey: String) async throws -> BackendGroup? {
        // NOTE: This query reads groups the caller may not be a member of yet.
        // Requires the "anyone can find group by thread_key" RLS policy on public.groups.
        #if canImport(Supabase)
        let response: [BackendGroup] = try await client
            .from("groups")
            .select()
            .eq("thread_key", value: threadKey)
            .limit(1)
            .execute()
            .value
        return response.first
        #else
        return nil
        #endif
    }

    func joinGroup(groupID: UUID) async throws {
        #if canImport(Supabase)
        // Always derive the user ID from the live session. Also ensure a profile row
        // exists first because group_members.user_id has an FK to profiles(id).
        let sessionUID = try await currentSessionUserID()
        try await ensureProfileExists(userID: sessionUID)

        let member = BackendGroupMember(groupID: groupID, userID: sessionUID)
        do {
            try await client
                .from("group_members")
                .insert(member)
                .execute()
        } catch {
            // If the user is already in the group, treat as success.
            let message = error.localizedDescription.lowercased()
            if message.contains("duplicate key") || message.contains("already exists") {
                return
            }
            throw error
        }
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func loadGroupMembers(groupID: UUID) async throws -> [BackendProfile] {
        #if canImport(Supabase)
        let memberships: [BackendGroupMember] = try await client
            .from("group_members")
            .select()
            .eq("group_id", value: groupID.uuidString)
            .execute()
            .value
        guard !memberships.isEmpty else { return [] }
        return try await loadProfiles(userIDs: memberships.map(\.userID))
        #else
        return []
        #endif
    }

    // MARK: - Moves

    func loadMoves(for groupID: UUID) async throws -> [BackendMove] {
        #if canImport(Supabase)
        let response: [BackendMove] = try await client
            .from("moves")
            .select()
            .eq("group_id", value: groupID.uuidString)
            .order("starts_at", ascending: true)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    @discardableResult
    func createMove(groupID: UUID, title: String, subtitle: String,
                    location: String, date: Date, creatorID: UUID) async throws -> BackendMove {
        #if canImport(Supabase)
        let move = BackendMove(
            id: UUID(),
            groupID: groupID,
            title: title,
            subtitle: subtitle,
            locationName: location,
            locationLatitude: nil,
            locationLongitude: nil,
            startsAt: date,
            creatorID: creatorID
        )
        let created: BackendMove = try await client
            .from("moves")
            .insert(move)
            .select()
            .single()
            .execute()
            .value
        // Auto-RSVP creator as locked_in
        try await updateRSVP(moveID: created.id, userID: creatorID, status: .lockedIn)
        return created
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - RSVPs

    func loadRSVPs(for moveID: UUID) async throws -> [BackendRSVP] {
        #if canImport(Supabase)
        let response: [BackendRSVP] = try await client
            .from("rsvps")
            .select()
            .eq("move_id", value: moveID.uuidString)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    func loadAllRSVPs(for moveIDs: [UUID]) async throws -> [BackendRSVP] {
        #if canImport(Supabase)
        guard !moveIDs.isEmpty else { return [] }
        let ids = moveIDs.map(\.uuidString)
        let response: [BackendRSVP] = try await client
            .from("rsvps")
            .select()
            .in("move_id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    func updateRSVP(moveID: UUID, userID: UUID, status: RSVPStatus) async throws {
        #if canImport(Supabase)
        let rsvp = BackendRSVP(moveID: moveID, userID: userID, status: status.rawValue)
        try await client
            .from("rsvps")
            .upsert(rsvp, onConflict: "move_id,user_id")
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Attendance

    func loadAllAttendance(for moveIDs: [UUID]) async throws -> [BackendAttendance] {
        #if canImport(Supabase)
        guard !moveIDs.isEmpty else { return [] }
        let ids = moveIDs.map(\.uuidString)
        let response: [BackendAttendance] = try await client
            .from("attendance")
            .select()
            .in("move_id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    func recordAttendance(moveID: UUID, attendance: [UUID: AttendanceStatus]) async throws {
        #if canImport(Supabase)
        let rows = attendance.map { userID, status in
            BackendAttendance(moveID: moveID, userID: userID, status: status.rawValue)
        }
        guard !rows.isEmpty else { return }
        try await client
            .from("attendance")
            .upsert(rows, onConflict: "move_id,user_id")
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Excused Votes (excused_votes table = one row per request)

    func loadExcusedVotes(for moveIDs: [UUID]) async throws -> [BackendExcusedVote] {
        #if canImport(Supabase)
        guard !moveIDs.isEmpty else { return [] }
        let ids = moveIDs.map(\.uuidString)
        let response: [BackendExcusedVote] = try await client
            .from("excused_votes")
            .select()
            .in("move_id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    @discardableResult
    func submitExcusedRequest(moveID: UUID, userID: UUID, reason: String,
                              pointsAtRisk: Int) async throws -> BackendExcusedVote {
        #if canImport(Supabase)
        let request = BackendExcusedVote(
            id: UUID(),
            moveID: moveID,
            petitionerID: userID,
            reason: reason,
            status: "pending",
            pointsAtRisk: pointsAtRisk,
            closesAt: Date().addingTimeInterval(4 * 3600),
            createdAt: nil
        )
        let created: BackendExcusedVote = try await client
            .from("excused_votes")
            .upsert(request, onConflict: "move_id,petitioner_id")
            .select()
            .single()
            .execute()
            .value
        return created
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    func resolveExcusedVote(voteID: UUID, outcome: String) async throws {
        #if canImport(Supabase)
        struct StatusUpdate: Encodable { let status: String }
        try await client
            .from("excused_votes")
            .update(StatusUpdate(status: outcome))
            .eq("id", value: voteID.uuidString)
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Excused Ballots (excused_vote_ballots table = individual votes)

    func loadExcusedBallots(for voteIDs: [UUID]) async throws -> [BackendExcusedBallot] {
        #if canImport(Supabase)
        guard !voteIDs.isEmpty else { return [] }
        let ids = voteIDs.map(\.uuidString)
        let response: [BackendExcusedBallot] = try await client
            .from("excused_vote_ballots")
            .select()
            .in("vote_id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    func castBallot(voteID: UUID, voterID: UUID, choice: ExcusedVoteChoice) async throws {
        #if canImport(Supabase)
        let ballot = BackendExcusedBallot(
            voteID: voteID,
            voterID: voterID,
            choice: choice == .approve ? "approve" : "deny"
        )
        try await client
            .from("excused_vote_ballots")
            .upsert(ballot, onConflict: "vote_id,voter_id")
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Roast Reactions

    /// Returns all reactions for the given groups (any season).
    func loadRoastReactions(groupIDs: [UUID]) async throws -> [BackendRoastReaction] {
        #if canImport(Supabase)
        guard !groupIDs.isEmpty else { return [] }
        let ids = groupIDs.map(\.uuidString)
        let response: [BackendRoastReaction] = try await client
            .from("roast_reactions")
            .select()
            .in("group_id", values: ids)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    /// Adds a reaction. Ignores the unique-constraint error if already reacted.
    func addRoastReaction(groupID: UUID, targetUserID: UUID,
                          season: Int, emoji: String, reactorID: UUID) async throws {
        #if canImport(Supabase)
        let row = BackendRoastReaction(
            groupID: groupID, targetUserID: targetUserID,
            season: season, emoji: emoji, reactorID: reactorID
        )
        do {
            try await client.from("roast_reactions").insert(row).execute()
        } catch {
            // Duplicate — already reacted, treat as success
            let msg = error.localizedDescription.lowercased()
            if msg.contains("duplicate") || msg.contains("unique") { return }
            throw error
        }
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    /// Removes a single reaction row.
    func removeRoastReaction(groupID: UUID, targetUserID: UUID,
                             season: Int, emoji: String, reactorID: UUID) async throws {
        #if canImport(Supabase)
        try await client
            .from("roast_reactions")
            .delete()
            .eq("group_id",       value: groupID.uuidString)
            .eq("target_user_id", value: targetUserID.uuidString)
            .eq("season",         value: season)
            .eq("emoji",          value: emoji)
            .eq("reactor_id",     value: reactorID.uuidString)
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Full Snapshot

    /// Loads everything needed to populate AppState for the given user.
    func loadAllData(for userID: UUID) async throws -> BackendSnapshot {
        #if canImport(Supabase)
        let groups = try await loadGroups(for: userID)
        guard !groups.isEmpty else {
            return BackendSnapshot(groups: [], membersByGroup: [:], movesByGroup: [:],
                                   rsvpsByMove: [:], attendanceByMove: [:],
                                   excusedVotesByMove: [:], ballotsByVote: [:])
        }
        let groupIDs = groups.map(\.id)

        async let membersTask = loadMembersForGroups(groupIDs: groupIDs)
        async let movesTask   = loadMovesForGroups(groupIDs: groupIDs)
        let (membersByGroup, allMoves) = try await (membersTask, movesTask)

        let moveIDs = allMoves.map(\.id)

        async let rsvpsTask    = loadAllRSVPs(for: moveIDs)
        async let attendTask   = loadAllAttendance(for: moveIDs)
        async let excVotesTask = loadExcusedVotes(for: moveIDs)
        let (allRSVPs, allAttendance, allExcVotes) = try await (rsvpsTask, attendTask, excVotesTask)

        let voteIDs = allExcVotes.map(\.id)
        let allBallots = try await loadExcusedBallots(for: voteIDs)

        let movesByGroup: [UUID: [BackendMove]] = Dictionary(grouping: allMoves) { $0.groupID }
        let rsvpsByMove: [UUID: [BackendRSVP]] = Dictionary(grouping: allRSVPs) { $0.moveID }
        let attendanceByMove: [UUID: [BackendAttendance]] = Dictionary(grouping: allAttendance) { $0.moveID }
        // Only one excused vote per move (latest petitioner wins for display)
        let excusedVotesByMove: [UUID: BackendExcusedVote] = Dictionary(
            allExcVotes.map { ($0.moveID, $0) }, uniquingKeysWith: { _, new in new }
        )
        let ballotsByVote: [UUID: [BackendExcusedBallot]] = Dictionary(grouping: allBallots) { $0.voteID }

        return BackendSnapshot(
            groups: groups,
            membersByGroup: membersByGroup,
            movesByGroup: movesByGroup,
            rsvpsByMove: rsvpsByMove,
            attendanceByMove: attendanceByMove,
            excusedVotesByMove: excusedVotesByMove,
            ballotsByVote: ballotsByVote
        )
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    // MARK: - Private Helpers

    private func loadMembersForGroups(groupIDs: [UUID]) async throws -> [UUID: [BackendProfile]] {
        #if canImport(Supabase)
        let ids = groupIDs.map(\.uuidString)
        let memberships: [BackendGroupMember] = try await client
            .from("group_members")
            .select()
            .in("group_id", values: ids)
            .execute()
            .value

        let allUserIDs = Array(Set(memberships.map(\.userID)))
        let profiles = try await loadProfiles(userIDs: allUserIDs)
        let profileByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        var result: [UUID: [BackendProfile]] = [:]
        for membership in memberships {
            if let profile = profileByID[membership.userID] {
                result[membership.groupID, default: []].append(profile)
            }
        }
        return result
        #else
        return [:]
        #endif
    }

    private func loadMovesForGroups(groupIDs: [UUID]) async throws -> [BackendMove] {
        #if canImport(Supabase)
        guard !groupIDs.isEmpty else { return [] }
        let ids = groupIDs.map(\.uuidString)
        let response: [BackendMove] = try await client
            .from("moves")
            .select()
            .in("group_id", values: ids)
            .order("starts_at", ascending: true)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }

    private func currentSessionUserID() async throws -> UUID {
        #if canImport(Supabase)
        guard let sessionUID = try? await client.auth.session.user.id else {
            throw FlakeBackendError.notAuthenticated
        }
        return sessionUID
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    private func ensureProfileExists(userID: UUID) async throws {
        #if canImport(Supabase)
        let placeholder = BackendProfile(
            id: userID,
            displayName: "flaker",
            initials: "F",
            avatarColor: "ff6b9d"
        )
        try await client
            .from("profiles")
            .upsert(placeholder, onConflict: "id", ignoreDuplicates: true)
            .execute()
        #else
        throw FlakeBackendError.supabasePackageMissing
        #endif
    }

    private static func initials(for name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map { String($0) }
            .joined()
            .uppercased()
        return letters.isEmpty ? "F" : letters
    }
}

// MARK: - Snapshot → Domain Models

extension BackendSnapshot {

    func toFlakeGroups(currentUserID: UUID) -> [FlakeGroup] {
        groups.map { group in
            let backendMembers = membersByGroup[group.id] ?? []
            let members = backendMembers.map { $0.toMember() }

            let backendMoves = movesByGroup[group.id] ?? []
            let moves: [Move] = backendMoves.map { bMove in
                let rsvps      = rsvpsByMove[bMove.id] ?? []
                let attendance = attendanceByMove[bMove.id] ?? []
                return bMove.toMove(rsvps: rsvps, attendance: attendance)
            }

            return FlakeGroup(
                id: group.id,
                name: group.name,
                members: members,
                moves: moves,
                groupLeaderID: group.createdBy,
                season: group.seasonNumber ?? 1,
                seasonWeeks: group.seasonWeeks ?? 12,
                seasonStartedAt: group.seasonStartedAt,
                userRank: 1,
                userScore: 0,
                userScoreGoal: 300,
                ranksSubtitle: "",
                nextSummary: moves.filter { $0.date >= Date() }.sorted { $0.date < $1.date }.first?.title
                             ?? moves.sorted { $0.date > $1.date }.first?.title
                             ?? "no upcoming moves.",
                threadKey: group.threadKey
            )
        }
    }

    func toExcusedVotes(members: [Member]) -> [UUID: ExcusedVote] {
        var result: [UUID: ExcusedVote] = [:]
        // A member can appear in multiple groups in the flattened input; keep one copy per ID.
        let memberByID = Dictionary(
            members.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )

        for (moveID, excVote) in excusedVotesByMove {
            guard let petitioner = memberByID[excVote.petitionerID] else { continue }

            let ballots   = ballotsByVote[excVote.id] ?? []
            let approvers = ballots.filter { $0.choice == "approve" }.compactMap { memberByID[$0.voterID] }
            let deniers   = ballots.filter { $0.choice == "deny"    }.compactMap { memberByID[$0.voterID] }

            let outcome: ExcusedVoteOutcome = {
                switch excVote.status {
                case "approved": return .approved
                case "denied":   return .denied
                default:         return .pending
                }
            }()

            // Reconstruct the move from snapshot
            let bMoveOpt = movesByGroup.values.flatMap { $0 }.first { $0.id == moveID }
            let rsvps    = rsvpsByMove[moveID] ?? []
            let attend   = attendanceByMove[moveID] ?? []
            let move     = bMoveOpt?.toMove(rsvps: rsvps, attendance: attend)
                         ?? Move(id: moveID, title: "", subtitle: "", location: "", date: Date(),
                                 creatorID: UUID(), rsvps: [:], groupID: UUID())

            result[moveID] = ExcusedVote(
                id: excVote.id,
                petitioner: petitioner,
                move: move,
                excuse: excVote.reason,
                approvers: approvers,
                deniers: deniers,
                closesAt: excVote.closesAt,
                pointsAtRisk: excVote.pointsAtRisk,
                outcome: outcome
            )
        }
        return result
    }
}

// MARK: - DTO → Domain conversions

extension BackendProfile {
    func toMember() -> Member {
        Member(
            id: id,
            name: displayName,
            handle: "@\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))",
            initials: initials,
            avatarColorHex: avatarColor,
            score: 0,
            flakeCount: 0,
            showCount: 0,
            badges: [],
            joinedAt: createdAt
        )
    }
}

extension BackendMove {
    func toMove(rsvps backendRSVPs: [BackendRSVP], attendance backendAttend: [BackendAttendance]) -> Move {
        let rsvpDict = Dictionary(uniqueKeysWithValues: backendRSVPs.compactMap { rsvp -> (UUID, RSVPStatus)? in
            guard let status = RSVPStatus(rawValue: rsvp.status) else { return nil }
            return (rsvp.userID, status)
        })
        let attendDict = Dictionary(uniqueKeysWithValues: backendAttend.compactMap { a -> (UUID, AttendanceStatus)? in
            guard let status = AttendanceStatus(rawValue: a.status) else { return nil }
            return (a.userID, status)
        })
        return Move(
            id: id,
            title: title,
            subtitle: subtitle,
            location: locationName,
            date: startsAt,
            creatorID: creatorID ?? UUID(),
            rsvps: rsvpDict,
            groupID: groupID,
            attendance: attendDict
        )
    }
}
