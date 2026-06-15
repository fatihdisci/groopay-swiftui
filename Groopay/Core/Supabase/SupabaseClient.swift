import Foundation
import Supabase

enum SupabaseService {
    static let shared: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_URL"
            ) as? String,
            let url = URL(string: urlString),
            url.scheme == "https",
            url.host?.isEmpty == false,
            let anonKey = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_ANON_KEY"
            ) as? String,
            !anonKey.isEmpty
        else {
            preconditionFailure(
                "Supabase configuration is missing or invalid. Check Config/Secrets.xcconfig."
            )
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()
}
