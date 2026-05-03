import Foundation
import SwiftUI
import Supabase

struct UserProfile: Codable {
    var name: String
    var email: String
    var phone: String
    var profileImageUrl: String?
}

struct UserPreferences: Codable, Equatable {
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

// MARK: - Encodable Data Structures for Supabase

struct UpdateProfileData: Encodable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

struct UserPreferencesData: Encodable {
    let userId: String
    let emailNotifications: Bool
    let productUpdates: Bool
    let smsNotifications: Bool
    let securityAlerts: Bool
    let marketingEmails: Bool
    let profileVisible: Bool
    let dataCollection: Bool
    let activityHistory: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case emailNotifications = "email_notifications"
        case productUpdates = "product_updates"
        case smsNotifications = "sms_notifications"
        case securityAlerts = "security_alerts"
        case marketingEmails = "marketing_emails"
        case profileVisible = "profile_visible"
        case dataCollection = "data_collection"
        case activityHistory = "activity_history"
    }
}

struct ProfileImageUpdateData: Encodable {
    let profileImageUrl: String

    enum CodingKeys: String, CodingKey {
        case profileImageUrl = "profile_image_url"
    }
}

private struct CPanelProfileImageUpload: Encodable {
    let imageBase64: String
    let mimeType: String
    let fileName: String
    let fileSize: Int
}

private struct CPanelProfileImageResponse: Decodable {
    let userId: String?
    let fileName: String?
    let mimeType: String?
    let fileSize: Int?
    let imageBase64: String?
    let createdAt: Date?
    let updatedAt: Date?
}

private enum ProfileImageEndpoint {
    static func url(for path: String) -> URL? {
        guard let plistPath = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let baseURL = plist["BASE_URL"] as? String else {
            return nil
        }

        return URL(string: baseURL + path)
    }
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

    private let profileCacheKey = "cachedUserProfile"
    private let profileCacheTimestampKey = "cachedUserProfileTimestamp"
    private let cacheValidityDuration: TimeInterval = 3600 // 1 ora

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

        // Load cached profile immediately
        loadCachedProfile()

        // Carica le attività recenti
        loadRecentActivities()
    }

    func loadUserProfile(forceRefresh: Bool = false) {
        // Check if cache is valid
        if !forceRefresh, isCacheValid(), userProfile != nil {
            if profileImage == nil {
                loadProfileImageFromCPanel()
            }
            return // Use cached data
        }

        isLoading = true

        Task {
            do {
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

                // Update profile with data from database
                let profile = UserProfile(
                    name: response.fullName,
                    email: session.user.email ?? "",
                    phone: "\(response.countryDialCode ?? "") \(response.phoneNumber ?? "")",
                    profileImageUrl: nil
                )

                await MainActor.run {
                    userProfile = profile
                    cacheProfile(profile)
                    loadProfileImageFromCPanel()

                    isLoading = false
                }
            } catch {
                // Fallback to email from Keychain if Supabase fails
                await MainActor.run {
                    if let credentials = KeychainHelper.load() {
                        userProfile = UserProfile(
                            name: extractNameFromEmail(credentials.email),
                            email: credentials.email,
                            phone: "",
                            profileImageUrl: nil
                        )
                    }
                    loadProfileImageFromCPanel()
                    isLoading = false
                }
            }
        }
    }

    private func loadCachedProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        userProfile = profile
    }

    private func cacheProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: profileCacheTimestampKey)
        }
    }

    private func isCacheValid() -> Bool {
        let timestamp = UserDefaults.standard.double(forKey: profileCacheTimestampKey)
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge < cacheValidityDuration
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: profileCacheKey)
        UserDefaults.standard.removeObject(forKey: profileCacheTimestampKey)
    }

    func updateProfile(name: String, email: String, phone: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Get current user session
            let session = try await SupabaseManager.client.auth.session
            let userId = session.user.id

            // Prepara i dati per l'aggiornamento
            // Nota: l'email viene gestita da Supabase Auth, quindi aggiorniamo solo full_name e phone_number
            let updateData = UpdateProfileData(fullName: name)

            // Aggiorna il profilo su Supabase
            try await SupabaseManager.client
                .from("users")
                .update(updateData)
                .eq("id", value: userId)
                .execute()

            // Aggiorna il profilo locale
            userProfile?.name = name
            userProfile?.email = email
            userProfile?.phone = phone

            // Aggiorna cache
            if let profile = userProfile {
                cacheProfile(profile)
            }

            // Registra l'attività
            await logActivity(
                type: "profile_updated",
                title: "Profilo aggiornato",
                subtitle: "Hai modificato le informazioni del tuo profilo",
                icon: "person.fill"
            )

            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Errore durante l'aggiornamento del profilo: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func savePreferences() async {
        isLoading = true

        do {
            // Get current user session
            let session = try await SupabaseManager.client.auth.session
            let userId = session.user.id

            // Prepara i dati per il salvataggio
            let preferencesData = UserPreferencesData(
                userId: userId.uuidString,
                emailNotifications: preferences.emailNotifications,
                productUpdates: preferences.productUpdates,
                smsNotifications: preferences.smsNotifications,
                securityAlerts: preferences.securityAlerts,
                marketingEmails: preferences.marketingEmails,
                profileVisible: preferences.profileVisible,
                dataCollection: preferences.dataCollection,
                activityHistory: preferences.activityHistory
            )

            // Usa upsert per inserire o aggiornare
            try await SupabaseManager.client
                .from("user_preferences")
                .upsert(preferencesData)
                .execute()

            // Save to UserDefaults come backup locale
            if let encoded = try? JSONEncoder().encode(preferences) {
                UserDefaults.standard.set(encoded, forKey: "userPreferences")
            }

            // Registra l'attività
            await logActivity(
                type: "settings_changed",
                title: "Impostazioni modificate",
                subtitle: "Hai aggiornato le tue preferenze",
                icon: "gearshape.fill"
            )

            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Errore durante il salvataggio delle preferenze: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func loadPreferences() {
        // Prima carica da cache locale per una risposta immediata
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        }

        // Poi carica da Supabase in background
        Task {
            do {
                let session = try await SupabaseManager.client.auth.session
                let userId = session.user.id

                // Carica le preferenze da Supabase
                let response: UserPreferencesModel = try await SupabaseManager.client
                    .from("user_preferences")
                    .select("*")
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value

                // Aggiorna le preferenze locali
                await MainActor.run {
                    preferences = UserPreferences(
                        emailNotifications: response.emailNotifications,
                        productUpdates: response.productUpdates,
                        smsNotifications: response.smsNotifications,
                        securityAlerts: response.securityAlerts,
                        marketingEmails: response.marketingEmails,
                        profileVisible: response.profileVisible,
                        dataCollection: response.dataCollection,
                        activityHistory: response.activityHistory
                    )

                    // Aggiorna cache locale
                    if let encoded = try? JSONEncoder().encode(preferences) {
                        UserDefaults.standard.set(encoded, forKey: "userPreferences")
                    }
                }
            } catch {
                // Se non ci sono preferenze su Supabase, usa i valori di default
                print("Nessuna preferenza trovata su Supabase, uso valori di default: \(error.localizedDescription)")
            }
        }
    }

    func uploadProfileImage(_ image: UIImage) async {
        isLoading = true

        do {
            guard let resizedImage = resizeProfileImage(image, maxDimension: 512),
                  let imageData = resizedImage.jpegData(compressionQuality: 0.82) else {
                throw NSError(domain: "ProfileViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossibile convertire l'immagine"])
            }

            let upload = CPanelProfileImageUpload(
                imageBase64: imageData.base64EncodedString(),
                mimeType: "image/jpeg",
                fileName: "profile.jpg",
                fileSize: imageData.count
            )
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let bodyData = try encoder.encode(upload)

            let _: CPanelProfileImageResponse = try await NetworkManager.shared.request(
                endpoint: "/v1/profile_image",
                method: .put,
                body: bodyData
            )

            // Aggiorna l'immagine locale e il profilo
            profileImage = resizedImage
            userProfile?.profileImageUrl = nil

            // Aggiorna cache
            if let profile = userProfile {
                cacheProfile(profile)
            }

            // Registra l'attività
            await logActivity(
                type: "profile_image_updated",
                title: "Immagine profilo aggiornata",
                subtitle: "Hai cambiato la tua foto profilo",
                icon: "camera.fill"
            )

            showSuccessMessage = true
            isLoading = false
        } catch {
            errorMessage = "Errore durante il caricamento dell'immagine: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func extractNameFromEmail(_ email: String) -> String {
        let username = email.components(separatedBy: "@").first ?? email
        return username.capitalized
    }

    private func resizeProfileImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        if ratio >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    private func loadProfileImageFromCPanel() {
        Task {
            do {
                guard let url = ProfileImageEndpoint.url(for: "/v1/profile_image/content") else {
                    return
                }

                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = NetworkTimeout.quickLookup
                config.timeoutIntervalForResource = NetworkTimeout.externalAPI
                let session = URLSession(configuration: config)

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                guard await AuthTokenHelper.addAuthHeader(to: &request) else {
                    return
                }

                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 404 {
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    return
                }

                await MainActor.run {
                    self.profileImage = image
                }
            } catch {
                print("Errore caricamento immagine profilo: \(error.localizedDescription)")
            }
        }
    }
    // MARK: - Attività Utente

    func loadRecentActivities() {
        Task {
            do {
                let session = try await SupabaseManager.client.auth.session
                let userId = session.user.id

                // Carica le ultime 10 attività dell'utente da Supabase
                let activities: [UserActivityModel] = try await SupabaseManager.client
                    .from("user_activities")
                    .select("*")
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value

                // Converti in ActivityItem per la UI
                await MainActor.run {
                    self.recentActivities = activities.map { activity in
                        ActivityItem(
                            title: activity.title,
                            subtitle: activity.subtitle ?? "",
                            time: formatActivityTime(activity.createdAt ?? Date()),
                            icon: activity.icon ?? "circle.fill"
                        )
                    }
                }
            } catch {
                print("Errore caricamento attività: \(error.localizedDescription)")
                // Se non ci sono attività su Supabase, lascia la lista vuota
                await MainActor.run {
                    self.recentActivities = []
                }
            }
        }
    }

    private func logActivity(type: String, title: String, subtitle: String, icon: String) async {
        do {
            let session = try await SupabaseManager.client.auth.session
            let userId = session.user.id

            let activityData = UserActivityData(
                userId: userId.uuidString,
                activityType: type,
                title: title,
                subtitle: subtitle,
                icon: icon
            )

            try await SupabaseManager.client
                .from("user_activities")
                .insert(activityData)
                .execute()

            // Ricarica le attività per mostrare la nuova
            loadRecentActivities()
        } catch {
            print("Errore durante la registrazione dell'attività: \(error.localizedDescription)")
        }
    }

    private func formatActivityTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let minutes = components.minute, minutes < 60 {
            if minutes == 0 {
                return "Adesso"
            } else if minutes == 1 {
                return "1 minuto fa"
            } else {
                return "\(minutes) minuti fa"
            }
        } else if let hours = components.hour, hours < 24 {
            if hours == 1 {
                return "1 ora fa"
            } else {
                return "\(hours) ore fa"
            }
        } else if let days = components.day {
            if days == 1 {
                return "Ieri"
            } else if days < 7 {
                return "\(days) giorni fa"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "1 settimana fa" : "\(weeks) settimane fa"
            } else {
                let months = days / 30
                return months == 1 ? "1 mese fa" : "\(months) mesi fa"
            }
        }

        return "Molto tempo fa"
    }
}
