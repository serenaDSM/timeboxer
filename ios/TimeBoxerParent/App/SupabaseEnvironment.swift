import Foundation
import Supabase

struct SupabaseSessionIdentity: Sendable {
    let accessToken: String
    let userID: UUID
}

actor SupabaseSessionStore {
    private var identity: SupabaseSessionIdentity?

    func set(accessToken: String, userID: UUID) {
        identity = SupabaseSessionIdentity(accessToken: accessToken, userID: userID)
    }

    func current() -> SupabaseSessionIdentity? {
        identity
    }

    func clear() {
        identity = nil
    }
}

enum SupabaseEnvironment {
    static let sessionStore = SupabaseSessionStore()

    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "TIMEBOXER_SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let publishableKey = Bundle.main.object(
                forInfoDictionaryKey: "TIMEBOXER_SUPABASE_PUBLISHABLE_KEY"
            ) as? String,
            publishableKey.hasPrefix("sb_publishable_")
        else {
            preconditionFailure("TimeBoxer Supabase configuration is missing")
        }

        return SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }()
}
