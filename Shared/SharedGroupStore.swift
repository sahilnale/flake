import Foundation

/// Lightweight group list stored in App Group UserDefaults.
/// The main app writes this after loading; the iMessage extension reads it
/// so users can pick which group to invite friends to — no network calls needed.
struct SharedGroupStore {

    private static let key = "flake.shared.groups.v1"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConfig.suiteName) ?? .standard
    }

    // MARK: - Entry (what gets persisted)

    struct Entry: Codable, Identifiable {
        let id: UUID
        let name: String
        let threadKey: String
        let memberCount: Int
    }

    // MARK: - Write (called by main app after snapshot loads)

    static func save(_ groups: [FlakeGroup]) {
        let entries = groups.compactMap { g -> Entry? in
            guard let key = g.threadKey else { return nil }
            return Entry(id: g.id, name: g.name, threadKey: key, memberCount: g.members.count)
        }
        saveEntries(entries)
    }

    /// Write entries directly — used by the iMessage extension after a Supabase fetch.
    static func saveEntries(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Read (called by extension)

    static func load() -> [Entry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }
}
