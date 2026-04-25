import Foundation
import SwiftUI

/// Helper per la localizzazione delle stringhe
extension String {
    /// Restituisce la stringa localizzata
    var localized: String {
        let localizedValue = NSLocalizedString(self, comment: "")

        if Self.shouldUseItalianFallback(key: self, localizedValue: localizedValue) {
            return L10n.translations[self] ?? localizedValue
        }

        return localizedValue
    }

    /// Restituisce la stringa localizzata con parametri
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }

    private static func shouldUseItalianFallback(key: String, localizedValue: String) -> Bool {
        let isItalian = Locale.preferredLanguages.contains { language in
            language.hasPrefix("it")
        }

        guard isItalian else { return false }
        return localizedValue == key || localizedValue.contains("Ã")
    }
}

/// Enum con tutte le chiavi di localizzazione dell'app
enum L10n {
    // MARK: - Common
    static let confirm = "Confirm"
    static let cancel = "Cancel"
    static let ok = "OK"
    static let continue_ = "Continue"
    static let loading = "Loading..."
    static let error = "Error"
    static let success = "Success"

    // MARK: - Garage
    static let garage = "Garage"
    static let addVehicle = "Add Vehicle"
    static let noVehiclesFound = "No vehicles found, please add a new one"
    static let technicalSpecs = "Technical Specs"
    static let details = "Details"

    // MARK: - License Plate
    static let scanLicensePlate = "Scan License Plate"
    static let enterLicensePlate = "Enter License Plate"
    static let enterLicensePlateManually = "Enter License Plate Manually"
    static let checkDetails = "Check Details"
    static let confirmDetails = "Confirm Details"
    static let autoFillVehicleDetails = "Auto fill vehicle details"
    static let cantFindYourCar = "Can't find your car?"
    static let noDataAvailable = "No data available"

    // MARK: - Tire
    static let tireRegistration = "Tire Registration"
    static let tireSidewallScanning = "Tire Sidewall Scanning"
    static let addYourTires = "Supported Tyres"
    static let tireData = "Tire Data"
    static let scanning = "Scanning..."
    static let allDataCollected = "All data collected! Redirecting..."
    static let keepScanning = "Keep scanning to collect all tire information"
    static let getCloseTire = "Get close to tire sidewall"
    static let moveCameraSlowly = "Move camera slowly to scan text"
    static let followGuideLines = "Follow guide lines for coverage"

    // MARK: - Tire Details
    static let remainingLife = "Remaining Life"
    static let tireLifecycle = "Tire Lifecycle"
    static let compatibleDimensions = "Compatible Tire Dimensions"
    static let tireCondition = "Tire Condition"
    static let treadDepth = "Tread Depth"
    static let recommended = "Recommended"
    static let noAnalysisYet = "No analysis yet"
    static let runScanToSeeDetails = "Run a scan to see tread depth, remaining life, and condition."
    static let analysisUnavailable = "Analysis unavailable"
    static let unableToLoadAnalysis = "We couldn't load the analysis data. Please try again later."
    static let offlineTitle = "No internet connection"
    static let offlineMessage = "Some features may be unavailable."

    // MARK: - Seasons
    static let winter = "Winter"
    static let summer = "Summer"
    static let allSeason = "All Season"

    // MARK: - Premium
    static let premiumFeatures = "Premium Features"
    static let chooseYourPlan = "Choose Your Plan"
    static let loadingPlans = "Loading plans..."
    static let restorePurchases = "Restore Purchases"
    static let subscriptionAutoRenews = "Subscription auto-renews until cancelled"
    static let processing = "Processing..."
    static let mostPopular = "MOST POPULAR"
    static let tyreVibesPremium = "TyreVibes Premium"
    static let unlockFullPotential = "Unlock the full potential of your garage"
    static let welcomeToPremium = "Welcome to TyreVibes Premium! Enjoy unlimited access to all features."
    static let bySubscribing = "By subscribing, you agree to our"
    static let terms = "Terms"
    static let and = "and"
    static let privacyPolicy = "Privacy Policy"

    // MARK: - Developer Settings
    static let developerSettings = "Developer Settings"
    static let configureFeatureFlags = "Configure feature flags and debug options"
    static let featureFlags = "Feature Flags"
    static let actions = "Actions"
    static let resetToDefaults = "Reset to Defaults"
    static let resetAllFeatureFlags = "Reset all feature flags to default values"
    static let clearCache = "Clear Cache"
    static let clearAllCachedData = "Clear all cached data"

    // MARK: - Scanning
    static let searchingPlate = "Searching for plate..."
    static let frameThePlate = "Frame the plate in the box"
    static let ensureWellLit = "Make sure the plate is well lit and readable"

    // MARK: - Profile
    static let profile = "Profile"
    static let editProfile = "Edit Profile"
    static let communicationPreferences = "Communication Preferences"
    static let privacySettings = "Privacy Settings"
    static let recentActivity = "Recent Activity"
    static let logout = "Logout"
    static let saveChanges = "Save Changes"
    static let accountLogin = "Account Login"
    static let settingsChanged = "Settings Changed"
    static let passwordChanged = "Password Changed"
    static let loggedInFrom = "Logged in from"
    static let updatedPreferences = "Updated communication preferences"
    static let successfullyUpdatedPassword = "Successfully updated your password"
    static let hoursAgo = "hours ago"
    static let yesterday = "Yesterday"
    static let daysAgo = "days ago"
}

/// Mappatura chiavi localizzazione in italiano
extension L10n {
    static let translations: [String: String] = [
        // Common
        "Confirm": "Conferma",
        "Cancel": "Annulla",
        "OK": "OK",
        "Continue": "Continua",
        "Loading...": "Caricamento...",
        "Error": "Errore",
        "Success": "Successo",

        // Garage
        "Garage": "Garage",
        "Add Vehicle": "Aggiungi Veicolo",
        "No vehicles found, please add a new one": "Nessun veicolo trovato, aggiungine uno nuovo",
        "Technical Specs": "Specifiche Tecniche",
        "Details": "Dettagli",

        // License Plate
        "Scan License Plate": "Scansiona Targa",
        "Enter License Plate": "Inserisci Targa",
        "Enter License Plate Manually": "Inserisci Targa Manualmente",
        "Check Details": "Verifica Dettagli",
        "Confirm Details": "Conferma Dettagli",
        "Auto fill vehicle details": "Compila automaticamente i dettagli del veicolo",
        "Can't find your car?": "Non trovi la tua auto?",
        "No data available": "Nessun dato disponibile",

        // Tire
        "Tire Registration": "Registrazione Pneumatici",
        "Tire Sidewall Scanning": "Scansione Spalla Pneumatico",
        "Supported Tyres": "Pneumatici Supportati",
        "Tire Data": "Dati Pneumatico",
        "Scanning...": "Scansione in corso...",
        "All data collected! Redirecting...": "Tutti i dati raccolti! Reindirizzamento...",
        "Keep scanning to collect all tire information": "Continua a scansionare per raccogliere tutte le informazioni",
        "Get close to tire sidewall": "Avvicinati alla spalla del pneumatico",
        "Move camera slowly to scan text": "Muovi la fotocamera lentamente per scansionare il testo",
        "Follow guide lines for coverage": "Segui le linee guida per la copertura",

        // Tire Details
        "Remaining Life": "Vita Residua",
        "Tire Lifecycle": "Ciclo di Vita Pneumatico",
        "Compatible Tire Dimensions": "Dimensioni Pneumatici Compatibili",
        "Tire Condition": "Condizione Pneumatico",
        "Tire Analysis": "Analisi del pneumatico",
        "Tread Depth": "Profondità Battistrada",
        "Recommended": "Consigliato",
        "No analysis yet": "Nessuna analisi disponibile",
        "Run a scan to see tread depth, remaining life, and condition.": "Esegui una scansione per vedere profondità battistrada, vita residua e condizione.",
        "Analysis unavailable": "Analisi non disponibile",
        "We couldn't load the analysis data. Please try again later.": "Non siamo riusciti a caricare i dati dell'analisi. Riprova più tardi.",
        "No internet connection": "Connessione assente",
        "Some features may be unavailable.": "Alcune funzionalità potrebbero non essere disponibili.",

        // Seasons
        "Winter": "Inverno",
        "Summer": "Estate",
        "All Season": "Quattro Stagioni",

        // Premium
        "Premium Features": "Funzionalità Premium",
        "Choose Your Plan": "Scegli il Tuo Piano",
        "Loading plans...": "Caricamento piani...",
        "Restore Purchases": "Ripristina Acquisti",
        "Subscription auto-renews until cancelled": "L'abbonamento si rinnova automaticamente fino alla cancellazione",
        "Processing...": "Elaborazione...",
        "MOST POPULAR": "PIÙ POPOLARE",
        "TyreVibes Premium": "TyreVibes Premium",
        "Unlock the full potential of your garage": "Sblocca tutto il potenziale del tuo garage",
        "Welcome to TyreVibes Premium! Enjoy unlimited access to all features.": "Benvenuto in TyreVibes Premium! Goditi l'accesso illimitato a tutte le funzionalità.",
        "By subscribing, you agree to our": "Iscrivendoti, accetti i nostri",
        "Terms": "Termini",
        "and": "e",
        "Privacy Policy": "Informativa sulla Privacy",

        // Developer Settings
        "Developer Settings": "Impostazioni Sviluppatore",
        "Configure feature flags and debug options": "Configura feature flags e opzioni di debug",
        "Feature Flags": "Feature Flags",
        "Actions": "Azioni",
        "Reset to Defaults": "Ripristina Predefiniti",
        "Reset all feature flags to default values": "Ripristina tutte le feature flags ai valori predefiniti",
        "Clear Cache": "Cancella Cache",
        "Clear all cached data": "Cancella tutti i dati in cache",

        // Scanning
        "Searching for plate...": "Ricerca targa in corso...",
        "Frame the plate in the box": "Inquadra la targa nel riquadro",
        "Make sure the plate is well lit and readable": "Assicurati che la targa sia ben illuminata e leggibile",

        // Profile
        "Profile": "Profilo",
        "Edit Profile": "Modifica Profilo",
        "Communication Preferences": "Preferenze di Comunicazione",
        "Privacy Settings": "Impostazioni Privacy",
        "Recent Activity": "Attività Recente",
        "Logout": "Esci",
        "Save Changes": "Salva Modifiche",
        "Account Login": "Accesso Account",
        "Settings Changed": "Impostazioni Modificate",
        "Password Changed": "Password Modificata",
        "Logged in from": "Accesso da",
        "Updated communication preferences": "Preferenze di comunicazione aggiornate",
        "Successfully updated your password": "Password aggiornata con successo",
        "hours ago": "ore fa",
        "Yesterday": "Ieri",
        "days ago": "giorni fa"
    ]
}
