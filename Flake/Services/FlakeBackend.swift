import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum FlakeBackendError: LocalizedError {
    case supabasePackageMissing
    case missingUser

    var errorDescription: String? {
        switch self {
        case .supabasePackageMissing:
            return "Supabase Swift package is not resolved yet."
        case .missingUser:
            return "Supabase did not return an authenticated user."
        }
    }
}

actor FlakeBackend {
    static let shared = FlakeBackend()

    #if canImport(Supabase)
    private let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
    #endif

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
        let profile = BackendProfile(
            id: userID,
            displayName: displayName.isEmpty ? "new flake" : displayName,
            initials: Self.initials(for: displayName),
            avatarColor: "ff6b9d"
        )
        try await client
            .from("profiles")
            .upsert(profile, onConflict: "id")
            .execute()
        return profile
        #else
        throw FlakeBackendError.supabasePackageMissing
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

    func loadGroups() async throws -> [BackendGroup] {
        #if canImport(Supabase)
        return try await client
            .from("groups")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
        #else
        return []
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
