import Foundation

#if canImport(Supabase)
import Supabase

/// Stores Supabase auth session in App Group UserDefaults so the
/// iMessage extension shares the same logged-in session as the main app.
struct AppGroupAuthStorage: AuthLocalStorage {
    private let defaults = UserDefaults(suiteName: AppGroupConfig.suiteName) ?? .standard

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}
#endif

enum AppGroupConfig {
    static let suiteName = "group.com.flake.app"
}
