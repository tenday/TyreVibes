import Foundation
import Supabase

struct UserProfile: Codable, Equatable {
    let name: String
    let email: String
    let phone: String
    var profileImageUrl: String?
}

@MainActor
class UserProfileService {

    private let userDefaults = UserDefaults.standard
    private let profileCacheKey = "cachedUserProfile"
    private let profileCacheTimestampKey = "cachedUserProfileTimestamp"

    func fetchAndCacheUserProfile() async throws -> UserProfile {
        // Get current user session
        let session = try await SupabaseManager.client.auth.session
        let userId = session.user.id

        // Fetch user profile from Supabase
        let response: Users = try await SupabaseManager.client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        // Create profile object
        let profile = UserProfile(
            name: response.fullName,
            email: session.user.email ?? "",
            phone: "\(response.countryDialCode ?? "") \(response.phoneNumber ?? "")",
            profileImageUrl: nil // Handle image URL if available
        )

        // Cache profile
        cacheProfile(profile)

        return profile
    }

    func getCachedProfile() -> UserProfile? {
        guard let data = userDefaults.data(forKey: profileCacheKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func clearCache() {
        userDefaults.removeObject(forKey: profileCacheKey)
        userDefaults.removeObject(forKey: profileCacheTimestampKey)
    }

    private func cacheProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            userDefaults.set(encoded, forKey: profileCacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: profileCacheTimestampKey)
        }
    }
}

// This is a placeholder for the `Users` model that is likely defined elsewhere.
// I'll assume its structure based on the usage in LoginViewModel.
struct Users: Decodable {
    let fullName: String
    let countryDialCode: String?
    let phoneNumber: String?
}