import Foundation

struct ErrorMapper {
    static func mapErrorToAlert(_ error: Error, fallbackTitle: String) -> (title: String, message: String) {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .invalidMail(let reason):
                return ("Email non valida", reason)
            case .noUserFound:
                return ("Credenziali errate", "L'email o la password inserita non sono corrette. Riprova.")
            case .otpInvalid:
                return ("Codice OTP errato", "Il codice inserito non è corretto. Verifica e riprova.")
            case .otpExpired:
                return ("Codice OTP scaduto", "Il codice OTP è scaduto. Richiedine uno nuovo.")
            case .profileCreationFailed(let reason):
                return ("Errore creazione profilo", reason)
            case .signUpFailed(let reason):
                return ("Accesso fallito", reason.isEmpty ? "Si è verificato un errore durante l'accesso. Riprova." : reason)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return ("Errore di comunicazione", "Connessione assente o instabile. Verifica la rete e riprova.")
            default:
                break
            }
        }

        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain, nsErr.code == NSURLErrorTimedOut {
            return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
        }

        if error is DecodingError {
            return ("Errore dati", "Risposta non valida dal server. Riprova più tardi.")
        }

        let message = error.localizedDescription.isEmpty ? "Si è verificato un errore imprevisto. Riprova." : error.localizedDescription
        return (fallbackTitle, message)
    }
}

// Dummy AuthServiceError for compilation. Assume it's defined in AuthService.
enum AuthServiceError: Error {
    case invalidMail(reason: String)
    case noUserFound
    case otpInvalid
    case otpExpired
    case profileCreationFailed(reason: String)
    case signUpFailed(reason: String)
}