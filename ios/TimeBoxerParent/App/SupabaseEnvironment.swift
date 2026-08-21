import Foundation
import Supabase

enum SupabaseEnvironment {
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
