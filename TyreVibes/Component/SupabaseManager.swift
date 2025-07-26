import Foundation
import Supabase

class SupabaseManager {
    
    static let client = SupabaseClient(
      supabaseURL: URL(string: "https://jbcbrnegmqraivdfmlsn.supabase.co")!,
      supabaseKey: "sb_publishable_j45ieNq6Q9Tyz0qyib5PPA_pEuCNzDc"
    )
    
}
