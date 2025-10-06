import Foundation
import Combine

@MainActor
class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false

    private let authService = AuthService()
    // UserProfileService will be added later
    // private let userProfileService: UserProfileService

    private var cancellables = Set<AnyCancellable>()

    init() {
        // In a real scenario, we would check for an existing session here.
        // For now, we'll start with the user logged out.
        self.isLoggedIn = false
    }

    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: email, password: password)
        // On success, fetch profile and update session
        // await userProfileService.fetchAndCacheUserProfile()
        self.isLoggedIn = true
    }

    func signInWithApple() async throws {
        // Logic for Apple Sign-In will be moved here
    }

    func signInWithGoogle() async throws {
        // Logic for Google Sign-In will be moved here
    }

    func logout() {
        // Clear session data
        isLoggedIn = false
        // Clear user profile cache
        // userProfileService.clearCache()
        // Other cleanup
    }
}