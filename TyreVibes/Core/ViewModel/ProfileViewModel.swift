import Foundation
import SwiftUI

struct UserProfile: Codable {
    var name: String
    var email: String
    var phone: String
    var profileImageUrl: String?
}

struct UserPreferences: Codable {
    var emailNotifications: Bool
    var productUpdates: Bool
    var smsNotifications: Bool
    var securityAlerts: Bool
    var marketingEmails: Bool
    var profileVisible: Bool
    var dataCollection: Bool
    var activityHistory: Bool
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: String
    let icon: String
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var preferences: UserPreferences
    @Published var recentActivities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var profileImage: UIImage?

    init() {
        // Default preferences
        self.preferences = UserPreferences(
            emailNotifications: true,
            productUpdates: true,
            smsNotifications: false,
            securityAlerts: true,
            marketingEmails: false,
            profileVisible: true,
            dataCollection: true,
            activityHistory: false
        )

        // Mock recent activities
        self.recentActivities = [
            ActivityItem(
                title: L10n.accountLogin.localized,
                subtitle: "\(L10n.loggedInFrom.localized) iOS",
                time: "2 \(L10n.hoursAgo.localized)",
                icon: "arrow.right.circle.fill"
            ),
            ActivityItem(
                title: L10n.settingsChanged.localized,
                subtitle: L10n.updatedPreferences.localized,
                time: L10n.yesterday.localized,
                icon: "gearshape.fill"
            ),
            ActivityItem(
                title: L10n.passwordChanged.localized,
                subtitle: L10n.successfullyUpdatedPassword.localized,
                time: "3 \(L10n.daysAgo.localized)",
                icon: "lock.fill"
            ),
            ActivityItem(
                title: L10n.accountLogin.localized,
                subtitle: "\(L10n.loggedInFrom.localized) iOS",
                time: "5 \(L10n.daysAgo.localized)",
                icon: "arrow.right.circle.fill"
            )
        ]
    }

    func loadUserProfile() {
        isLoading = true

        // Get user email from Keychain
        if let credentials = KeychainHelper.load() {
            // Create mock profile from stored credentials
            userProfile = UserProfile(
                name: extractNameFromEmail(credentials.email),
                email: credentials.email,
                phone: "+39 123 456 7890",
                profileImageUrl: nil
            )
        } else {
            // Fallback mock data
            userProfile = UserProfile(
                name: "Utente TyreVibes",
                email: "user@tyrevibes.com",
                phone: "+39 123 456 7890",
                profileImageUrl: nil
            )
        }

        isLoading = false
    }

    func updateProfile(name: String, email: String, phone: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Simulate API call
            try await Task.sleep(nanoseconds: 1_000_000_000)

            userProfile?.name = name
            userProfile?.email = email
            userProfile?.phone = phone

            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Failed to update profile"
            isLoading = false
        }
    }

    func savePreferences() async {
        isLoading = true

        do {
            // Simulate API call
            try await Task.sleep(nanoseconds: 500_000_000)

            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(preferences) {
                UserDefaults.standard.set(encoded, forKey: "userPreferences")
            }

            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Failed to save preferences"
            isLoading = false
        }
    }

    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        }
    }

    func uploadProfileImage(_ image: UIImage) async {
        isLoading = true

        do {
            // Simulate upload
            try await Task.sleep(nanoseconds: 1_000_000_000)

            profileImage = image
            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Failed to upload image"
            isLoading = false
        }
    }

    private func extractNameFromEmail(_ email: String) -> String {
        let username = email.components(separatedBy: "@").first ?? email
        return username.capitalized
    }
}
