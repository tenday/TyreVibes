import Foundation

/// Helper centralizzato per la gestione del token di autenticazione Supabase.
/// Elimina la duplicazione del metodo getAuthToken() presente in più ViewModel.
enum AuthTokenHelper {

    /// Recupera il JWT token dalla sessione Supabase corrente.
    /// - Returns: Il token di accesso se disponibile, `nil` altrimenti.
    static func getAuthToken() async -> String? {
        guard NetworkMonitor.shared.isReachable else {
            print("⚠️ [AuthTokenHelper] Network unavailable, skip token refresh.")
            return nil
        }
        do {
            let session = try await SupabaseManager.client.auth.session
            return session.accessToken
        } catch {
            if isNetworkError(error) {
                print("⚠️ [AuthTokenHelper] Network error while fetching token: \(error.localizedDescription)")
            } else {
                print("⚠️ [AuthTokenHelper] Failed to get auth token: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Aggiunge l'header di autorizzazione Bearer a una URLRequest.
    /// - Parameter request: La request da modificare (inout).
    /// - Returns: `true` se il token è stato aggiunto, `false` altrimenti.
    @discardableResult
    static func addAuthHeader(to request: inout URLRequest) async -> Bool {
        guard let token = await getAuthToken() else {
            return false
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return true
    }

    /// Verifica se l'utente ha una sessione attiva.
    /// - Returns: `true` se esiste una sessione valida.
    static func hasValidSession() async -> Bool {
        return await getAuthToken() != nil
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSURLErrorDomain
        }

        return false
    }
}
