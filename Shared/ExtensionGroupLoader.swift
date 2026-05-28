import Foundation

#if canImport(Supabase)
import Supabase

/// Lightweight Supabase client for the iMessage extension.
/// Uses AppGroupAuthStorage so it reads the same session the main app stored.
/// The main app is the source of truth; this is only used to refresh when the
/// cache is stale or empty (e.g., first time opening iMessage before the main app).
actor ExtensionGroupLoader {
    static let shared = ExtensionGroupLoader()

    private let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: .init(auth: .init(storage: AppGroupAuthStorage()))
    )

    /// Returns groups for the current user.
    /// First tries the shared cache (instant), then refreshes from Supabase in background.
    /// Call `loadFresh()` if you need guaranteed-fresh data.
    func loadCached() -> [SharedGroupStore.Entry] {
        SharedGroupStore.load()
    }

    /// Fetches groups directly from Supabase and saves to the shared cache.
    /// Falls back to the cached list if there's no valid session or a network error.
    @discardableResult
    func loadFresh() async -> [SharedGroupStore.Entry] {
        guard let userID = try? await client.auth.session.user.id else {
            // No stored session in the extension — return cached entries
            return SharedGroupStore.load()
        }

        do {
            // My memberships
            let myMemberships: [BackendGroupMember] = try await client
                .from("group_members")
                .select()
                .eq("user_id", value: userID.uuidString)
                .execute()
                .value

            guard !myMemberships.isEmpty else {
                return SharedGroupStore.load()
            }

            // Groups I'm in
            let groupIDs = myMemberships.map(\.groupID.uuidString)
            let groups: [BackendGroup] = try await client
                .from("groups")
                .select()
                .in("id", values: groupIDs)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Member counts
            let allMemberships: [BackendGroupMember] = try await client
                .from("group_members")
                .select()
                .in("group_id", values: groupIDs)
                .execute()
                .value
            let countByGroup = Dictionary(grouping: allMemberships) { $0.groupID }
                .mapValues { $0.count }

            let entries = groups.compactMap { group -> SharedGroupStore.Entry? in
                guard let key = group.threadKey else { return nil }
                return SharedGroupStore.Entry(
                    id: group.id,
                    name: group.name,
                    threadKey: key,
                    memberCount: countByGroup[group.id] ?? 1
                )
            }

            if !entries.isEmpty {
                SharedGroupStore.saveEntries(entries)
                return entries
            }
        } catch {
            // Network or auth failure — use cache
        }

        return SharedGroupStore.load()
    }

    // MARK: - Current user

    func currentUserID() async -> UUID? {
        try? await client.auth.session.user.id
    }

    // MARK: - Move persistence (fire-and-forget from extension)

    /// Saves a move created in iMessage to Supabase so the main app can see it.
    /// The move ID is caller-generated so the URL card stays stable.
    func createMove(
        id: UUID,
        groupID: UUID,
        creatorID: UUID,
        title: String,
        location: String,
        date: Date
    ) async {
        let move = BackendMove(
            id: id,
            groupID: groupID,
            title: title,
            subtitle: "",
            locationName: location,
            locationLatitude: nil,
            locationLongitude: nil,
            startsAt: date,
            creatorID: creatorID
        )
        // Insert move row — ignore conflict if already exists (re-insert on retry)
        _ = try? await client
            .from("moves")
            .upsert(move, onConflict: "id")
            .execute()

        // Auto-RSVP the creator as locked in
        let rsvp = BackendRSVP(moveID: id, userID: creatorID, status: "locked_in")
        _ = try? await client
            .from("rsvps")
            .upsert(rsvp, onConflict: "move_id,user_id")
            .execute()
    }

    // MARK: - RSVP persistence (fire-and-forget from extension)

    /// Saves an RSVP submitted from iMessage to Supabase.
    func submitRSVP(moveID: UUID, userID: UUID, status: RSVPStatus) async {
        let rsvp = BackendRSVP(moveID: moveID, userID: userID, status: status.rawValue)
        _ = try? await client
            .from("rsvps")
            .upsert(rsvp, onConflict: "move_id,user_id")
            .execute()
    }

    // MARK: - Move fetching (for the iMessage panel — no card tap required)

    /// Fetches the most recent moves for a group so the extension can show RSVPs
    /// without requiring the user to tap a card first.
    func fetchMoves(groupID: UUID) async -> [Move] {
        guard let _ = try? await client.auth.session.user.id else { return [] }

        do {
            let backendMoves: [BackendMove] = try await client
                .from("moves")
                .select()
                .eq("group_id", value: groupID.uuidString)
                .order("starts_at", ascending: false)
                .limit(5)
                .execute()
                .value

            guard !backendMoves.isEmpty else { return [] }

            let moveIDs = backendMoves.map(\.id.uuidString)
            let rsvps: [BackendRSVP] = (try? await client
                .from("rsvps")
                .select()
                .in("move_id", values: moveIDs)
                .execute()
                .value) ?? []

            let rsvpsByMove = Dictionary(grouping: rsvps) { $0.moveID }

            return backendMoves.map { bm in
                let moveRSVPs = rsvpsByMove[bm.id] ?? []
                let rsvpDict = moveRSVPs.reduce(into: [UUID: RSVPStatus]()) { result, rsvp in
                    if let s = RSVPStatus(rawValue: rsvp.status) {
                        result[rsvp.userID] = s
                    }
                }
                return Move(
                    id: bm.id,
                    title: bm.title,
                    subtitle: bm.subtitle,
                    location: bm.locationName,
                    date: bm.startsAt,
                    creatorID: bm.creatorID ?? UUID(),
                    rsvps: rsvpDict,
                    groupID: bm.groupID
                )
            }
        } catch {
            return []
        }
    }
}
#endif
