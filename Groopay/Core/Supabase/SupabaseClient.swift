import Foundation
import Supabase

enum SupabaseService {
    static let shared: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_URL"
            ) as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_ANON_KEY"
            ) as? String,
            !anonKey.isEmpty
        else {
            preconditionFailure(
                "Supabase configuration is missing. Add Config/Secrets.xcconfig."
            )
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }()
}
