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
}
#endif
