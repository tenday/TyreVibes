import Foundation
import Supabase

// Enum per errori personalizzati, per una gestione più chiara
enum AuthServiceError: Error {
    case signUpFailed(String)
    case profileCreationFailed(String)
    case noUserFound
}

class AuthService {
    
    // Funzione per recuperare la lista dei paesi dal database
    func fetchCountries() async throws -> [Country] {
        let response: [Country] = try await SupabaseManager.client
            // FIX: Rimosso .database
            .from("countries")
            .select("*")
            .order("name", ascending: true)
            .execute()
            .value
        
        return response
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
    
    func signIn(email: String, password: String) async throws {
            try await SupabaseManager.client.auth.signIn(email: email, password: password)
        }
}
