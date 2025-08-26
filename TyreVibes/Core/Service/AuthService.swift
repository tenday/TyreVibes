import Foundation
import Supabase
import GoogleSignIn
// Enum per errori personalizzati, per una gestione più chiara
enum AuthServiceError: Error {
    case signUpFailed(String)
    case profileCreationFailed(String)
    case noUserFound
    case invalidMail(String)
    case otpInvalid
    case otpExpired
}

import AuthenticationServices

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    var presentationAnchor: ASPresentationAnchor?

    var credential: ASAuthorizationAppleIDCredential {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: appleIDCredential)
        } else {
            continuation?.resume(throwing: AuthServiceError.signUpFailed("Credenziale Apple non valida"))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentationAnchor ?? ASPresentationAnchor()
    }
}

class AuthService {
    static var currentUserId: String? {
        get async {
            do {
                let session = try await SupabaseManager.client.auth.session
                return session.user.id.uuidString
            } catch {
                return nil
            }
        }
    }
    
    // Funzione per recuperare la lista dei paesi dal database
    func fetchCountries() async throws -> [Country] {
        let response: [Country] = try await SupabaseManager.client
            .from("countries")
            .select("*")
            .order("name", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func getCarData() async throws -> [Car] {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .order("name", ascending: true)
            .execute()
            .value
        return response
    }

    // Recupera un veicolo per ID
    func getVehicle(byId id: UUID) async throws -> Car? {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return response.first
    }

    // Recupera veicoli per brand
    func getVehicles(byBrand brand: String) async throws -> [Car] {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .eq("brand", value: brand)
            .execute()
            .value
        return response
    }

    // Ricerca veicoli per parola chiave nel nome (case-insensitive)
    func searchVehicles(keyword: String) async throws -> [Car] {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .ilike("name", pattern: "%\(keyword)%")
            .execute()
            .value
        return response
    }

    // Recupera veicoli per intervallo di anni
    func getVehiclesByYearRange(startYear: Int, endYear: Int) async throws -> [Car] {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .gte("year", value: startYear)
            .lte("year", value: endYear)
            .execute()
            .value
        return response
    }

    // Recupera tutti i veicoli ordinati per una colonna specifica
    func getAllVehiclesSorted(by column: String, ascending: Bool) async throws -> [Car] {
        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .order(column, ascending: ascending)
            .execute()
            .value
        return response
    }
    
    func getVehiclesForCurrentUser() async throws -> [Car] {
        let session = try await SupabaseManager.client.auth.session
        let userId = session.user.id

        let response: [Car] = try await SupabaseManager.client
            .from("vehicles")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return response
    }

    func deleteCar(withId carId: UUID) async throws {
        try await SupabaseManager.client
            .from("vehicles")
            .delete()
            .eq("id", value: carId.uuidString)
            .execute()
    }

    // Funzione unica per gestire l'intero processo di registrazione
    func createAccount(
        email: String,
        password: String,
        fullName: String,
        username: String,
        phoneNumber: String,
        selectedCountry: Country,
        agreedToTerms: Bool
    ) async throws {
        
        // --- PASSO 1: Registra l'utente con il servizio Auth di Supabase ---
                
            let authResponse: AuthResponse
                do {
                    authResponse = try await SupabaseManager.client.auth.signUp(
                        email: email,
                        password: password
                    )
                } catch {
                    throw AuthServiceError.signUpFailed(error.localizedDescription)
                }
                
                // --- PASSO 2: Prepara i dati per il profilo ---
                
                // FIX: Estraiamo l'ID utente direttamente da authResponse.user.id
                let userId = authResponse.user.id
                
                let newProfile = Users(
                    id: userId,
                    fullName: fullName,
                    username: username,
                    phoneNumber: phoneNumber,
                    countryDialCode: selectedCountry.dialCode,
                    agreedToTerms: agreedToTerms
            )
        
        // --- PASSO 3: Inserisci il nuovo profilo nella tabella 'profiles' ---
        do {
            try await SupabaseManager.client
                .from("users")
                .insert(newProfile)
                .execute()
        } catch {
            // Se la creazione del profilo fallisce, è buona norma tentare di eliminare l'utente appena creato
            // per non lasciare dati "orfani". (Logica opzionale ma raccomandata)
            try? await SupabaseManager.client.auth.admin.deleteUser(id: userId)
            throw AuthServiceError.profileCreationFailed(error.localizedDescription)
        }
    }
    
    func sendOtp(phoneNumber: String) async throws {
        try await SupabaseManager.client.auth.signInWithOTP(phone: phoneNumber)
    }
    
    func verifyOtp(otpCode: String, phoneNumber: String) async throws {
        _ = try await SupabaseManager.client.auth.verifyOTP(
            phone: phoneNumber,
            token: otpCode,
            type: .sms
        )
    }
    
    func signIn(email: String, password: String) async throws {
            try await SupabaseManager.client.auth.signIn(email: email, password: password)
        }
    
    @MainActor
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate

        delegate.presentationAnchor = presentationAnchor

        controller.performRequests()

        let credential = try await delegate.credential

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthServiceError.signUpFailed("Token Apple non valido")
        }

        try await SupabaseManager.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: tokenString, nonce: nil)
        )
    }

    @MainActor
    func signInWithGoogle() async throws {
        guard let topVC = UIApplication.shared.topViewController() else {
            throw AuthServiceError.signUpFailed("Could not find top view controller.")
        }

        // Carichiamo clientID da Api.plist
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientID = plist["GOOGLE_CLIENT_ID"] as? String else {
            throw AuthServiceError.signUpFailed("GOOGLE_CLIENT_ID not found in Api.plist. Please add it.")
        }

        // Configurazione globale (si fa una volta sola)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Nuovo metodo di login
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.signUpFailed("Google ID token not found.")
        }

        try await SupabaseManager.client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, nonce: nil)
        )
    }
}
