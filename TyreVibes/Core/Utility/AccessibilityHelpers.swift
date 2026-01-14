import SwiftUI

// MARK: - Accessibility View Modifiers

/// Modificatore per nascondere elementi decorativi da VoiceOver
struct AccessibilityDecorativeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accessibilityHidden(true)
    }
}

/// Modificatore per pulsanti con icona
struct AccessibilityIconButtonModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

/// Modificatore per campi di testo
struct AccessibilityTextFieldModifier: ViewModifier {
    let label: String
    let hint: String

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }
}

/// Modificatore per toggle con stato
struct AccessibilityToggleModifier: ViewModifier {
    let label: String
    let hint: String
    let isOn: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityValue(isOn ? "Attivo" : "Disattivo")
    }
}

// MARK: - View Extensions

extension View {
    /// Nasconde l'elemento da VoiceOver (per elementi decorativi)
    func accessibilityDecorative() -> some View {
        modifier(AccessibilityDecorativeModifier())
    }

    /// Configura l'accessibilità per un pulsante con icona
    func accessibilityIconButton(label: String, hint: String? = nil) -> some View {
        modifier(AccessibilityIconButtonModifier(label: label, hint: hint))
    }

    /// Configura l'accessibilità per un campo di testo
    func accessibilityTextField(label: String, hint: String) -> some View {
        modifier(AccessibilityTextFieldModifier(label: label, hint: hint))
    }

    /// Configura l'accessibilità per un toggle
    func accessibilityToggle(label: String, hint: String, isOn: Bool) -> some View {
        modifier(AccessibilityToggleModifier(label: label, hint: hint, isOn: isOn))
    }
}

// MARK: - Reduce Motion Helper

/// Environment key per verificare se l'utente preferisce animazioni ridotte
struct ReduceMotionAnimationModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : animation, value: UUID())
    }
}

extension View {
    /// Applica l'animazione solo se l'utente non ha richiesto reduce motion
    func accessibilityAnimation(_ animation: Animation?) -> some View {
        modifier(ReduceMotionAnimationModifier(animation: animation))
    }
}

// MARK: - Accessibility Labels per elementi comuni

/// Struttura con label di accessibilità comuni in italiano
struct AccessibilityLabels {
    // Navigazione
    static let back = "Indietro"
    static let close = "Chiudi"
    static let menu = "Menu"
    static let settings = "Impostazioni"
    static let notifications = "Notifiche"
    static let profile = "Profilo"
    static let search = "Cerca"
    static let clearSearch = "Cancella ricerca"

    // Azioni
    static let add = "Aggiungi"
    static let delete = "Elimina"
    static let edit = "Modifica"
    static let share = "Condividi"
    static let save = "Salva"
    static let cancel = "Annulla"
    static let confirm = "Conferma"
    static let refresh = "Aggiorna"

    // Autenticazione
    static let email = "Email"
    static let password = "Password"
    static let showPassword = "Mostra password"
    static let hidePassword = "Nascondi password"
    static let login = "Accedi"
    static let logout = "Esci"
    static let register = "Registrati"
    static let forgotPassword = "Password dimenticata"

    // Veicoli
    static let garage = "Garage"
    static let addVehicle = "Aggiungi veicolo"
    static let vehicleDetails = "Dettagli veicolo"
    static let deleteVehicle = "Elimina veicolo"
    static let shareVehicle = "Condividi veicolo"

    // Analisi
    static let startAnalysis = "Avvia analisi"
    static let analysisResults = "Risultati analisi"
    static let tyreCondition = "Condizione pneumatico"
}

// MARK: - Hints comuni

struct AccessibilityHints {
    // Navigazione
    static let goBack = "Torna alla schermata precedente"
    static let openNotifications = "Apri il centro notifiche"
    static let openProfile = "Apri il tuo profilo utente"
    static let openSettings = "Apri le impostazioni"

    // Ricerca
    static let searchVehicles = "Inserisci marca, modello o targa per cercare"
    static let clearSearchText = "Rimuovi il testo di ricerca"

    // Autenticazione
    static let enterEmail = "Inserisci il tuo indirizzo email"
    static let enterPassword = "Inserisci la tua password"
    static let togglePasswordVisibility = "Attiva per mostrare o nascondere la password"

    // Veicoli
    static let addNewVehicle = "Aggiungi un nuovo veicolo al garage"
    static let viewVehicleDetails = "Visualizza i dettagli completi del veicolo"
    static let deleteVehicleFromGarage = "Elimina questo veicolo dal garage"
    static let shareVehicleInfo = "Condividi le informazioni del veicolo"
}
