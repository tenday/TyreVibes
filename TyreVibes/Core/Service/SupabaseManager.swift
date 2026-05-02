import Foundation
import Supabase

class SupabaseManager {

    static let client: SupabaseClient = {
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlString = plist["SUPABASE_URL"] as? String,
              let key = plist["SUPABASE_KEY"] as? String else {
            fatalError("Supabase.plist non trovato o le chiavi SUPABASE_URL/SUPABASE_KEY non sono configurate correttamente.")
        }

        guard let url = URL(string: urlString) else {
            fatalError("L'URL di Supabase non è valido: \(urlString)")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()

}
