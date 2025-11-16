# 🚗 TyreVibes - Guida per Assistenti AI

> **IMPORTANTE**: Parla sempre in italiano quando interagisci con questo progetto.

---

## 📋 Indice

1. [Panoramica Progetto](#panoramica-progetto)
2. [Tecnologie e Framework](#tecnologie-e-framework)
3. [Architettura](#architettura)
4. [Struttura Directory](#struttura-directory)
5. [Autenticazione e API](#autenticazione-e-api)
6. [Pattern di Sviluppo](#pattern-di-sviluppo)
7. [Gestione Stato](#gestione-stato)
8. [UI/UX e Styling](#uiux-e-styling)
9. [Testing](#testing)
10. [Configurazione](#configurazione)
11. [Deployment](#deployment)
12. [Convenzioni di Codice](#convenzioni-di-codice)
13. [Troubleshooting](#troubleshooting)

---

## 🎯 Panoramica Progetto

**TyreVibes** è un'applicazione iOS nativa per la gestione e il monitoraggio degli pneumatici dei veicoli, con funzionalità di analisi AI e integrazione con servizi ACI.

### Funzionalità Principali

- 🚗 **Gestione Garage**: Gestione veicoli e pneumatici
- 📸 **Scansione Targhe**: Riconoscimento automatico targhe con CoreML
- 🔍 **Analisi Battistrada**: AI-powered analysis della superficie pneumatici
- 🔔 **Notifiche Intelligenti**: Alert per scadenze e manutenzioni
- 🗺️ **Mappa Gommisti**: Localizzazione gommisti nelle vicinanze
- 📊 **Report PDF**: Generazione report dettagliati
- 🔐 **Auth Multi-Provider**: Email, Google, Apple, SPID (ACI)
- 💳 **Sistema Premium**: Subscription-based features

### Informazioni Base

- **Linguaggio**: Swift (iOS), TypeScript (Edge Functions)
- **Framework UI**: SwiftUI (100%)
- **Architettura**: MVVM
- **Backend**: Supabase (Database, Auth, Storage, Edge Functions)
- **Deployment**: iOS 16.0+
- **Bundle ID**: `it.tyrevibes.app`

---

## 🛠 Tecnologie e Framework

### Core Technologies

#### **Swift & SwiftUI**
- **SwiftUI**: Framework dichiarativo per l'intera UI
- **Combine**: Reactive programming per gestione stato e eventi
- **async/await**: Pattern asincrono moderno per tutte le operazioni

#### **Backend - Supabase**
- **URL**: `https://jbcbrnegmqraivdfmlsn.supabase.co`
- **Supabase iOS SDK**: Client per Auth, Database, Storage
- **Edge Functions**: Serverless functions in TypeScript/Deno
- **PostgreSQL**: Database principale
- **Row Level Security (RLS)**: Sicurezza a livello di riga

#### **Autenticazione**
```swift
// Providers supportati:
- Email/Password (Supabase Auth)
- Google Sign-In (GoogleSignIn SDK)
- Apple Sign-In (AuthenticationServices)
- SPID ACI (WebView custom)
- OTP SMS (Supabase Phone Auth)
```

**⚠️ CRITICO**: Tutte le chiamate API utilizzano **JWT Supabase** come Bearer token.

#### **AI & Machine Learning**
- **Vision Framework**: Analisi immagini pneumatici
- **CoreML**: Modello `LicensePlateDetector.mlpackage`
- **CoreImage + Accelerate**: Elaborazione immagini avanzata

#### **Altre Librerie Apple**
- **MapKit**: Mappe e geolocalizzazione
- **PDFKit**: Generazione report PDF
- **BackgroundTasks**: Task in background
- **UserNotifications**: Notifiche locali e push
- **StoreKit**: In-app purchases (Premium)

---

## 🏗 Architettura

### Pattern MVVM

```
┌─────────────┐
│    View     │ ← SwiftUI Views (dichiarative)
└──────┬──────┘
       │ binding (@Published, @State)
       ▼
┌─────────────┐
│  ViewModel  │ ← @MainActor ObservableObject
└──────┬──────┘
       │ async/await
       ▼
┌─────────────┐
│   Service   │ ← Business logic layer
└──────┬──────┘
       │ HTTP + JWT
       ▼
┌─────────────┐
│ Supabase API│ ← Backend (Database, Auth, Storage)
└─────────────┘
```

### Separation of Concerns

#### **Views** (`/Features/`)
- Solo UI dichiarativa SwiftUI
- No business logic
- Binding a ViewModel tramite `@StateObject` o `@ObservedObject`

#### **ViewModels** (`/Core/ViewModel/`)
- `@MainActor class ... : ObservableObject`
- `@Published` properties per UI binding
- Chiamate async ai Services
- Gestione stato locale

#### **Models** (`/Core/Model/`, `/Models/`)
- Structs `Codable` per serializzazione JSON
- Snake_case → camelCase automatico nel NetworkManager
- Immutabili quando possibile

#### **Services** (`/Core/Service/`, `/Services/`)
- Singleton pattern (`static let shared`)
- Business logic e chiamate API
- Gestione cache e persistenza

---

## 📁 Struttura Directory

```
TyreVibes/
├── TyreVibes/                          # Codice sorgente principale
│   ├── Core/                          # Componenti riutilizzabili (72 file)
│   │   ├── Component/                 # UI Components custom (15)
│   │   │   ├── LicensePlateComponent.swift
│   │   │   ├── CustomButtons.swift
│   │   │   └── ...
│   │   │
│   │   ├── Extensions/                # Swift Extensions
│   │   │   ├── String+Extensions.swift
│   │   │   ├── Date+Extensions.swift
│   │   │   └── ...
│   │   │
│   │   ├── Fonts/                     # Font custom (Sora family)
│   │   │   ├── Sora-Bold.ttf
│   │   │   ├── Sora-Regular.ttf
│   │   │   └── ... (8 pesi totali)
│   │   │
│   │   ├── Helper/                    # Utility helpers (13)
│   │   │   ├── ValidationHelper.swift
│   │   │   ├── DateHelper.swift
│   │   │   └── ...
│   │   │
│   │   ├── Localization/              # Sistema multilingua
│   │   │   └── LanguageManager.swift
│   │   │
│   │   ├── Model/                     # Modelli Core (11)
│   │   │   ├── Vehicle.swift
│   │   │   ├── Tyre.swift
│   │   │   ├── User.swift
│   │   │   └── ...
│   │   │
│   │   ├── Service/                   # Servizi Core (11)
│   │   │   ├── NetworkManager.swift   # ⭐ Manager HTTP centralizzato
│   │   │   ├── AuthService.swift      # ⭐ Servizio autenticazione
│   │   │   ├── SupabaseManager.swift  # ⭐ Client Supabase
│   │   │   ├── VehicleService.swift
│   │   │   ├── TyreService.swift
│   │   │   └── ...
│   │   │
│   │   ├── Utility/                   # Utilities (15)
│   │   │   ├── AppLogger.swift        # Sistema logging
│   │   │   ├── ErrorHandler.swift     # Gestione errori
│   │   │   ├── FontExtension.swift    # Font custom
│   │   │   ├── ColorExtension.swift   # Colori custom
│   │   │   └── ...
│   │   │
│   │   └── ViewModel/                 # ViewModels Core (12)
│   │       ├── GarageViewModel.swift
│   │       ├── TyreViewModel.swift
│   │       └── ...
│   │
│   ├── Features/                      # Features modulari (48 file)
│   │   ├── Authentication/            # Login/Signup/Reset Password
│   │   │   ├── LoginScreen.swift
│   │   │   ├── SignUpScreen.swift
│   │   │   └── ResetPasswordScreen.swift
│   │   │
│   │   ├── Auth/                      # SPID Auth (ACI)
│   │   │   ├── README_SPID_AUTH.md
│   │   │   └── SPIDAuthWebView.swift
│   │   │
│   │   ├── Garage/                    # Gestione veicoli (6 schermate)
│   │   │   ├── GarageScreen.swift
│   │   │   ├── VehicleDetailScreen.swift
│   │   │   ├── AddVehicleScreen.swift
│   │   │   └── ...
│   │   │
│   │   ├── LicensePlate/              # Scansione targhe (4 schermate)
│   │   │   ├── LicensePlateScanner.swift
│   │   │   └── ...
│   │   │
│   │   ├── TreadAnalysis/             # Analisi battistrada AI
│   │   ├── SurfaceAnalysis/           # Analisi superficie
│   │   ├── Reports/                   # Report e PDF
│   │   ├── Map/                       # Mappa gommisti
│   │   ├── Profile/                   # Profilo utente
│   │   ├── Settings/                  # Impostazioni
│   │   ├── Notifications/             # Centro notifiche
│   │   ├── Subscription/              # Premium subscription
│   │   ├── Shop/                      # Shop pneumatici
│   │   ├── OnBoarding/                # Onboarding (3 schermate)
│   │   ├── BugReport/                 # Segnalazione bug
│   │   └── Address/                   # Ricerca indirizzi
│   │
│   ├── Models/                        # Modelli aggiuntivi (3)
│   ├── Services/                      # Servizi aggiuntivi (12)
│   │   ├── NotificationAPIService.swift
│   │   ├── ACISPIDAuthService.swift   # 26KB - Auth SPID
│   │   └── ...
│   │
│   ├── Stores/                        # State management
│   │   └── NotificationStore.swift
│   │
│   ├── Assets.xcassets/               # Asset e colori
│   │   ├── AppIcon.appiconset/
│   │   ├── Color.colorset/            # Colori custom
│   │   └── Images/
│   │
│   ├── Localizable.xcstrings           # 🌍 Localizzazione (111KB)
│   ├── LicensePlateDetector.mlpackage  # 🤖 Modello CoreML
│   ├── Api.plist                       # ⚙️ Config API endpoints
│   ├── Info.plist                      # ⚙️ Config app
│   ├── Info-BackgroundModes.plist      # ⚙️ Background tasks
│   └── TyreVibesApp.swift              # 🚀 Entry point app
│
├── supabase/                           # Backend Supabase
│   ├── functions/                     # Edge Functions (7)
│   │   ├── update-insurance-expiry/
│   │   ├── update-bollo-status/
│   │   ├── update-revision-status/
│   │   ├── run-all-jobs/              # Orchestrator
│   │   ├── send-daily-notifications/
│   │   ├── send-weekly-summary/
│   │   └── send-push-notifications/
│   │
│   ├── migrations/                    # Migrazioni DB
│   ├── setup-database-ready.sql       # Setup completo DB
│   ├── config.toml                    # Config Supabase
│   ├── deploy.sh                      # Script deploy
│   └── README.md                      # Doc Supabase
│
├── TyreVibesTests/                    # Test unitari
│   └── AuthServiceTests.swift         # (coverage molto basso)
│
├── TyreVibes.xcodeproj/               # Progetto Xcode
├── GoogleService-Info.plist            # Config Firebase/Google
├── DEPLOYMENT_GUIDE.md                 # 📖 Guida deployment (367 righe)
├── BACKGROUND_JOBS.md                  # 📖 Doc background jobs
├── NOTIFICHE_GIORNALIERE.md            # 📖 Sistema notifiche
└── CLAUDE.md                           # 📖 Questo file
```

### Convenzioni Naming

| Tipo | Convenzione | Esempio |
|------|-------------|---------|
| **File Swift** | PascalCase | `LoginScreen.swift`, `AuthService.swift` |
| **Cartelle** | PascalCase (features), lowercase (config) | `Authentication/`, `supabase/` |
| **Classi/Structs** | PascalCase | `class AuthService`, `struct Vehicle` |
| **Variabili/Proprietà** | camelCase | `var isLoading`, `let userId` |
| **Funzioni** | camelCase | `func fetchVehicles()` |
| **Costanti** | camelCase | `let baseURL` |
| **Enum cases** | camelCase | `case invalidURL`, `case notFound` |

---

## 🔐 Autenticazione e API

### Sistema di Autenticazione

#### File Chiave: `AuthService.swift`

Location: `/TyreVibes/Core/Service/AuthService.swift` (296 righe)

#### Provider Supportati

```swift
// 1. Email/Password
func signIn(email: String, password: String) async throws {
    try await SupabaseManager.client.auth.signIn(
        email: email,
        password: password
    )
}

// 2. Google Sign-In
func signInWithGoogle(forceAccountSelection: Bool = false) async throws {
    let result = try await GIDSignIn.sharedInstance.signIn(
        withPresenting: rootViewController
    )
    // Exchange Google token con Supabase
}

// 3. Apple Sign-In
func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    // Native Apple auth flow
}

// 4. OTP SMS
func sendOtp(phoneNumber: String) async throws
func verifyOtp(otpCode: String, phoneNumber: String) async throws

// 5. SPID ACI
// File: /TyreVibes/Services/ACISPIDAuthService.swift (26KB)
// WebView-based auth flow
```

#### Gestione Sessione

```swift
// Recupero User ID corrente
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
```

#### Activity Logging Automatico

L'`AuthService` traccia automaticamente:
- ✅ Login (con provider specificato)
- ✅ Cambio password

Inserimenti nella tabella `user_activities`:

```swift
let activityData: [String: Any] = [
    "user_id": userId.uuidString,
    "activity_type": "login",
    "title": "Accesso all'account",
    "subtitle": "Accesso effettuato da iOS con \(provider)",
    "icon": "arrow.right.circle.fill",
    "created_at": ISO8601DateFormatter().string(from: Date())
]
```

### Sistema API con JWT

#### ⭐ File Chiave: `NetworkManager.swift`

Location: `/TyreVibes/Core/Service/NetworkManager.swift` (356 righe)

#### Caratteristiche NetworkManager

```swift
class NetworkManager {
    static let shared = NetworkManager()  // Singleton

    private let session: URLSession
    private let baseURL: String           // Da Api.plist
    private let timeout: TimeInterval = 30.0

    // ⚠️ CRITICO: Aggiunge automaticamente JWT a OGNI request
    private func getAuthToken() async -> String? {
        do {
            let session = try await SupabaseManager.client.auth.session
            return session.accessToken  // JWT Token
        } catch {
            return nil
        }
    }
}
```

#### Pattern di Utilizzo API

```swift
// GET Request
func get<T: Decodable>(
    endpoint: String,
    queryParams: [String: String]? = nil
) async throws -> T {
    // Aggiunge automaticamente:
    // - Bearer token JWT
    // - Headers Content-Type/Accept
    // - Base URL da Api.plist
    // - Decoding automatico snake_case → camelCase
}

// POST Request
func post<T: Decodable, U: Encodable>(
    endpoint: String,
    body: U
) async throws -> T

// DELETE Request
func delete<T: Decodable>(endpoint: String) async throws -> T

// PUT/PATCH Request
func put<T: Decodable, U: Encodable>(
    endpoint: String,
    body: U
) async throws -> T
```

#### Esempio Reale

```swift
// In VehicleService.swift
func fetchVehicles(for userId: UUID) async throws -> [VehicleResponse] {
    let endpoint = "/v1/vehicles/\(userId.uuidString)"

    // NetworkManager aggiunge automaticamente:
    // - Authorization: Bearer <JWT_TOKEN>
    // - Content-Type: application/json
    // - Accept: application/json
    let vehicles: [VehicleResponse] = try await NetworkManager.shared.get(
        endpoint: endpoint
    )

    return vehicles
}
```

#### Header Automatici

Ogni chiamata include automaticamente:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
Accept: application/json
```

#### Gestione Errori

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized        // 401 - Token scaduto/invalido
    case forbidden          // 403
    case notFound           // 404
    case serverError        // 500
    case timeout

    var errorDescription: String? {
        // Messaggi localizzati in italiano
    }
}
```

#### Logging (solo DEBUG)

```swift
#if DEBUG
print("🌐 [NetworkManager] Request: POST /v1/vehicles")
print("📋 [NetworkManager] Headers: [Authorization: Bearer ...]")
print("📦 [NetworkManager] Body: {\"brand\": \"Tesla\", ...}")
print("✅ [NetworkManager] Response: 200 OK")
print("📥 [NetworkManager] Data: {\"id\": \"123\", ...}")
#endif
```

### Servizi API Specializzati

#### VehicleService
Location: `/TyreVibes/Core/Service/VehicleService.swift`

```swift
class VehicleService {
    static let shared = VehicleService()

    func fetchVehicles(for userId: UUID) async throws -> [VehicleResponse]
    func deleteVehicle(vehicleId: UUID, userId: UUID) async throws
    func associateVehicleToUser(...) async throws -> ResponseBody

    // Cache locale con UserDefaults
    private func cacheVehicles(_ vehicles: [VehicleResponse])
    private func getCachedVehicles() -> [VehicleResponse]?
}
```

#### TyreService
Location: `/TyreVibes/Core/Service/TyreService.swift`

Gestione CRUD pneumatici.

#### PlateAPIService
Location: `/TyreVibes/Core/Service/PlateAPIService.swift` (17KB)

API per scansione targhe e integrazione ACI.

#### NotificationAPIService
Location: `/TyreVibes/Services/NotificationAPIService.swift`

Gestione notifiche push e sincronizzazione.

---

## 🔧 Pattern di Sviluppo

### Async/Await Pattern

**⚠️ SEMPRE usare async/await**, mai callback o completion handlers.

```swift
// ✅ CORRETTO
func fetchCars() async {
    isLoading = true
    do {
        vehicles = try await vehicleService.fetchVehicles(for: userId)
        isLoading = false
    } catch {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

// ❌ SBAGLIATO - Non usare completion handlers
func fetchCars(completion: @escaping ([Vehicle]) -> Void) {
    // NO! Obsoleto
}
```

#### Chiamate da SwiftUI View

```swift
struct GarageScreen: View {
    @StateObject private var viewModel = GarageViewModel()

    var body: some View {
        List(viewModel.vehicles) { vehicle in
            VehicleRow(vehicle: vehicle)
        }
        .task {  // ✅ Esegue async code all'apparizione
            await viewModel.fetchCars()
        }
        .refreshable {  // ✅ Pull-to-refresh
            await viewModel.fetchCars()
        }
    }
}
```

### Error Handling Pattern

#### Custom Error Enums

```swift
// Definisci errori specifici per dominio
enum AuthServiceError: Error {
    case signUpFailed(String)
    case profileCreationFailed(String)
    case noUserFound
    case invalidMail(String)
    case otpInvalid
    case otpExpired
}

// Aggiungi LocalizedError per messaggi utente
extension AuthServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return "Registrazione fallita: \(message)"
        case .noUserFound:
            return "Utente non trovato"
        // ...
        }
    }
}
```

#### Gestione negli ViewModel

```swift
@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    func signIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService().signIn(
                email: email,
                password: password
            )
            // Successo - NavigationStack gestisce la transizione
        } catch let error as AuthServiceError {
            // Gestione errori specifici del dominio
            errorMessage = error.localizedDescription
        } catch {
            // Gestione errori generici
            errorMessage = "Errore imprevisto: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

#### Mostrare Errori nella UI

```swift
.alert("Errore", isPresented: $showError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(viewModel.errorMessage ?? "Errore sconosciuto")
}
.onChange(of: viewModel.errorMessage) { _, newValue in
    showError = newValue != nil
}
```

### Validation Pattern

```swift
// Validation nel ViewModel
class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }

    var passwordsMatch: Bool {
        password == confirmPassword
    }
}

// Uso nella View
Button("Registrati") {
    Task { await viewModel.signUp() }
}
.disabled(!viewModel.isFormValid)
```

---

## 📊 Gestione Stato

### ObservableObject + @Published

Pattern principale per ViewModels:

```swift
@MainActor  // ⚠️ IMPORTANTE: UI updates solo su Main thread
class GarageViewModel: ObservableObject {
    @Published var vehicles: [VehicleResponse] = []
    @Published var isLoading = true
    @Published var selectedVehicle: VehicleResponse?
    @Published var errorMessage: String?

    private let vehicleService = VehicleService.shared

    func fetchVehicles() async {
        isLoading = true
        do {
            if let userId = await AuthService.currentUserId {
                vehicles = try await vehicleService.fetchVehicles(
                    for: UUID(uuidString: userId)!
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

### AppStorage per Persistenza

```swift
// Per flag semplici
@AppStorage("isLoggedIn") var isLoggedIn: Bool = false
@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

// Per preferenze utente
@AppStorage("selectedLanguage") var selectedLanguage = "it"
@AppStorage("notificationsEnabled") var notificationsEnabled = true
```

### UserDefaults per Cache

```swift
// Cache complessa (es. lista veicoli)
func cacheVehicles(_ vehicles: [VehicleResponse]) {
    if let encoded = try? JSONEncoder().encode(vehicles) {
        UserDefaults.standard.set(encoded, forKey: "cachedVehicles")
    }
}

func getCachedVehicles() -> [VehicleResponse]? {
    guard let data = UserDefaults.standard.data(forKey: "cachedVehicles"),
          let vehicles = try? JSONDecoder().decode([VehicleResponse].self, from: data)
    else { return nil }
    return vehicles
}
```

### EnvironmentObject per Stato Globale

```swift
// In TyreVibesApp.swift
@main
struct TyreVibesApp: App {
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
        }
    }
}

// Nelle Views
struct SettingsScreen: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        // Usa languageManager
    }
}
```

### Combine Publishers

```swift
// Per eventi sistema
.onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
    isLoggedIn = false
    // Reset stato
}

// Custom notifications
extension Notification.Name {
    static let didRequestLogout = Notification.Name("didRequestLogout")
    static let didUpdateVehicle = Notification.Name("didUpdateVehicle")
}
```

### Stores (quando necessario)

Location: `/TyreVibes/Stores/NotificationStore.swift`

```swift
class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published var notifications: [NotificationModel] = []
    @Published var unreadCount: Int = 0

    func fetchNotifications() async { ... }
    func markAsRead(_ id: UUID) async { ... }
}
```

---

## 🎨 UI/UX e Styling

### Design System

#### Font Custom - Sora Family

Extension: `/TyreVibes/Core/Utility/FontExtension.swift`

```swift
// Uso
Text("Benvenuto")
    .font(.customFont(size: 36, weight: .bold))

Text("Descrizione")
    .font(.customFont(size: 16, weight: .regular))

// Pesi disponibili:
.thin, .extraLight, .light, .regular, .medium, .semiBold, .bold, .extraBold
```

Font files in `/TyreVibes/Core/Fonts/`:
- Sora-Thin.ttf
- Sora-ExtraLight.ttf
- Sora-Light.ttf
- Sora-Regular.ttf
- Sora-Medium.ttf
- Sora-SemiBold.ttf
- Sora-Bold.ttf
- Sora-ExtraBold.ttf

#### Colori Custom

Extension: `/TyreVibes/Core/Utility/ColorExtension.swift`

Definiti in: `/TyreVibes/Assets.xcassets/Color.colorset/`

```swift
// Uso
Rectangle()
    .fill(Color.customBackgroundColor)

Text("Testo")
    .foregroundColor(.customSandyBrown)

// Colori disponibili (esempi):
Color.customBackgroundColor
Color.customFieldColor
Color.customSandyBrown
Color.customTextColor
// ... (definiti in Assets)
```

#### Responsive Design

```swift
GeometryReader { geometry in
    let screenWidth = geometry.size.width
    let screenHeight = geometry.size.height

    VStack {
        // Button height: 7.5% altezza schermo
        Button("Continua") { }
            .frame(height: screenHeight * 0.075)

        // Immagine: 40% larghezza schermo
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: screenWidth * 0.4)
    }
}
```

#### Spacing & Layout Conventions

```swift
// Standard spacing
.padding(.horizontal, 20)  // Padding laterale standard
.padding(.vertical, 16)    // Padding verticale

// Spacing tra elementi
VStack(spacing: 24) {      // Spacing standard tra sezioni
    // Contenuto
}

// Corner radius
.cornerRadius(18)          // Radius standard per card/button

// Shadow
.shadow(
    color: .black.opacity(0.1),
    radius: 8,
    x: 0,
    y: 4
)
```

#### Componenti Riutilizzabili

Location: `/TyreVibes/Core/Component/`

```swift
// License Plate Component
LicensePlateComponent(plateNumber: "AB123CD")

// Custom Button
CustomPrimaryButton(title: "Continua") {
    // Action
}

// Loading Spinner
if viewModel.isLoading {
    ProgressView()
        .progressViewStyle(CircularProgressViewStyle())
}
```

### Navigation Pattern

#### NavigationStack (iOS 16+)

```swift
NavigationStack {
    List(vehicles) { vehicle in
        NavigationLink(value: vehicle) {
            VehicleRow(vehicle: vehicle)
        }
    }
    .navigationDestination(for: Vehicle.self) { vehicle in
        VehicleDetailScreen(vehicle: vehicle)
    }
    .navigationTitle("Garage")
}
```

#### Sheet/FullScreenCover

```swift
.sheet(isPresented: $showAddVehicle) {
    AddVehicleScreen()
}

.fullScreenCover(isPresented: $showOnboarding) {
    OnboardingScreen()
}
```

#### Dismiss

```swift
@Environment(\.dismiss) private var dismiss

Button("Chiudi") {
    dismiss()
}
```

#### Deep Linking

```swift
.onOpenURL { url in
    // it.tyrevibes.app://reset-password?token=...
    if url.scheme == "it.tyrevibes.app" {
        if url.host == "reset-password" {
            showResetPasswordScreen = true
        }
    }
}
```

### Localizzazione

File: `/TyreVibes/Localizable.xcstrings` (111KB)

```swift
// Uso
Text("welcome_message")  // Automaticamente localizzato

// Oppure con String extension
let message = "welcome_message".localized()

// Con parametri
String(format: "vehicles_count".localized(), vehicleCount)
```

Lingue supportate:
- 🇮🇹 Italiano (default)
- 🇬🇧 Inglese

---

## 🧪 Testing

### Framework

**XCTest** (native Apple framework)

Location: `/TyreVibesTests/`

### Coverage Attuale

⚠️ **Molto basso** - Solo 1 file di test:
- `AuthServiceTests.swift` (818 bytes)

### Struttura Test

```swift
import XCTest
@testable import TyreVibes

final class AuthServiceTests: XCTestCase {
    var authService: AuthService!

    override func setUp() {
        super.setUp()
        authService = AuthService()
    }

    override func tearDown() {
        authService = nil
        super.tearDown()
    }

    func testSignInWithValidCredentials() async throws {
        // Test implementation
    }

    func testSignInWithInvalidCredentials() async throws {
        // Test implementation
    }
}
```

### Best Practices per Nuovi Test

```swift
// Test async functions
func testFetchVehicles() async throws {
    let vehicles = try await vehicleService.fetchVehicles(for: testUserId)
    XCTAssertFalse(vehicles.isEmpty)
    XCTAssertEqual(vehicles.count, 3)
}

// Test error handling
func testInvalidLogin() async {
    do {
        try await authService.signIn(email: "", password: "")
        XCTFail("Should have thrown an error")
    } catch {
        XCTAssertTrue(error is AuthServiceError)
    }
}

// Mock services
class MockNetworkManager: NetworkManager {
    var shouldFail = false

    override func get<T: Decodable>(endpoint: String) async throws -> T {
        if shouldFail {
            throw NetworkError.serverError
        }
        // Return mock data
    }
}
```

### Running Tests

```bash
# Xcode UI
CMD + U

# CLI
xcodebuild test \
    -project TyreVibes.xcodeproj \
    -scheme TyreVibes \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

### ⚠️ TODO: Migliorare Coverage

Aree che necessitano testing:
- [ ] NetworkManager (mock delle API)
- [ ] VehicleService
- [ ] TyreService
- [ ] AuthService (più scenari)
- [ ] ViewModels (business logic)
- [ ] Validation helpers
- [ ] Date/String extensions

---

## ⚙️ Configurazione

### File di Configurazione Principali

#### 1. `Api.plist`

Location: `/TyreVibes/Api.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <!-- Backend principale -->
    <key>BASE_URL</key>
    <string>https://www.tyrevibes.com/api</string>

    <!-- Supabase -->
    <key>SUPABASE_URL</key>
    <string>https://jbcbrnegmqraivdfmlsn.supabase.co</string>

    <key>SUPABASE_KEY</key>
    <string>sb_publishable_j45ieNq6Q9Tyz0qyib5PPA_pEuCNzDc</string>

    <!-- Endpoint specifici -->
    <key>CheckPlateBaseURL</key>
    <string>https://www.tyrevibes.com/api/v1/check_plate</string>

    <key>SavePlateURL</key>
    <string>https://www.tyrevibes.com/api/v1/save_plate</string>

    <key>ManualPlateURL</key>
    <string>https://www.tyrevibes.com/api/v1/manual_plate</string>

    <key>GetAllCars</key>
    <string>https://www.tyrevibes.com/api/vehicles/:userId</string>

    <key>IMAGE_GENERATOR_URL</key>
    <string>img</string>
</dict>
</plist>
```

**Lettura in codice**:

```swift
if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
   let plist = NSDictionary(contentsOfFile: path),
   let baseURL = plist["BASE_URL"] as? String {
    // Usa baseURL
}
```

#### 2. `Info.plist`

Location: `/TyreVibes/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <!-- URL Schemes per OAuth -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- Google Sign-In -->
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.628808645845-etj5cdmni8703nd5jie361luir9mmmme</string>
            </array>
        </dict>

        <!-- Custom URL scheme -->
        <dict>
            <key>CFBundleURLName</key>
            <string>it.tyrevibes.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>it.tyrevibes.app</string>
            </array>
        </dict>
    </array>

    <!-- App Transport Security (localhost per debug) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>localhost</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
            </dict>
        </dict>
    </dict>

    <!-- Font Custom -->
    <key>UIAppFonts</key>
    <array>
        <string>Sora-Bold.ttf</string>
        <string>Sora-ExtraBold.ttf</string>
        <string>Sora-ExtraLight.ttf</string>
        <string>Sora-Light.ttf</string>
        <string>Sora-Medium.ttf</string>
        <string>Sora-Regular.ttf</string>
        <string>Sora-SemiBold.ttf</string>
        <string>Sora-Thin.ttf</string>
    </array>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

#### 3. `Info-BackgroundModes.plist`

Location: `/TyreVibes/Info-BackgroundModes.plist`

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.tyrevibes.backgroundrefresh</string>
</array>
```

#### 4. `GoogleService-Info.plist`

Location: `/TyreVibes/GoogleService-Info.plist` (1.1KB)

Configurazione Firebase/Google Sign-In. Non committare se contiene chiavi sensibili.

#### 5. Supabase Config

Location: `/supabase/config.toml`

```toml
[api]
enabled = true
port = 54321

[db]
port = 54322

[functions]
enabled = true
```

### Variabili d'Ambiente

**⚠️ Nota**: Il progetto **non usa** `.env` files. Tutte le configurazioni sono nei file `.plist`.

Per aggiungere env vars:
1. Xcode → Target → Build Settings → User-Defined
2. Oppure usare Xcode Schemes → Environment Variables

### Secrets Management

**⚠️ ATTENZIONE SICUREZZA**:

Attualmente le chiavi API sono hardcoded in `Api.plist`. Considerare:

1. **Keychain** per token sensibili:
```swift
import Security

func saveToKeychain(key: String, value: String) {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    SecItemAdd(query as CFDictionary, nil)
}
```

2. **Environment Variables** in Xcode Schemes (per sviluppo)

3. **Remote Config** (Firebase Remote Config) per production

---

## 🚀 Deployment

### Guida Completa

File: `/DEPLOYMENT_GUIDE.md` (367 righe)

Contiene istruzioni dettagliate per:
1. Setup Database (SQL scripts)
2. Deploy Edge Functions
3. Test funzioni
4. Configurazione iOS app
5. Background tasks setup

### Quick Deployment Steps

#### 1. Database Setup

```bash
# Accedi a Supabase Dashboard
# https://supabase.com/dashboard/project/jbcbrnegmqraivdfmlsn

# Esegui SQL script
# Copia il contenuto di /supabase/setup-database-ready.sql
# Incollalo nell'SQL Editor e Run
```

#### 2. Edge Functions Deploy

```bash
# Da /supabase/ directory
chmod +x deploy.sh
./deploy.sh

# Oppure manualmente via Dashboard:
# Edge Functions → Create function → Deploy
```

Funzioni da deployare:
1. `update-insurance-expiry`
2. `update-bollo-status`
3. `update-revision-status`
4. `run-all-jobs` (orchestrator)
5. `send-daily-notifications`
6. `send-weekly-summary`
7. `send-push-notifications`

#### 3. Cron Jobs

Configurato nel setup SQL:

```sql
-- Runs daily at 07:00
SELECT cron.schedule(
    'run-all-background-jobs',
    '0 7 * * *',
    'SELECT extensions.http_post(...)'
);
```

Verifica:

```sql
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname = 'run-all-background-jobs';
```

#### 4. iOS App Build

```bash
# Apri Xcode
open TyreVibes.xcodeproj

# Seleziona target → Generic iOS Device
# Product → Archive
# Distribute App → App Store Connect
```

### Background Tasks

File: `/TyreVibes/Core/Service/BackgroundTaskManager.swift` (se esiste)

Inizializzazione in `TyreVibesApp.swift`:

```swift
@main
struct TyreVibesApp: App {
    init() {
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    BackgroundTaskManager.shared.scheduleBackgroundRefresh()
                }
        }
    }
}
```

Identifier: `com.tyrevibes.backgroundrefresh`

### Testing Deployment

```sql
-- Test singola funzione
SELECT extensions.http_post(
    url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry',
    headers := '{"Authorization": "Bearer sb_publishable_..."}'::jsonb,
    body := '{}'::jsonb
);

-- Verifica logs
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC LIMIT 10;
```

---

## 📝 Convenzioni di Codice

### Swift Style Guide

#### Naming

```swift
// ✅ CORRETTO
class VehicleService { }
struct VehicleResponse: Codable { }
enum NetworkError: Error { }
var isLoading: Bool
func fetchVehicles() async throws
let baseURL = "https://..."

// ❌ SBAGLIATO
class vehicleservice { }  // PascalCase!
var IsLoading: Bool        // camelCase!
func FetchVehicles() { }   // camelCase!
```

#### Code Organization

```swift
// MARK: per organizzare classi/file
class AuthService {
    // MARK: - Properties
    private let client: SupabaseClient
    static let shared = AuthService()

    // MARK: - Initialization
    private init() { }

    // MARK: - Public Methods
    func signIn(email: String, password: String) async throws { }

    // MARK: - Private Methods
    private func validateEmail(_ email: String) -> Bool { }
}
```

#### Formatting

```swift
// Indentazione: 4 spazi (no tabs)

// Braces: same line
if condition {
    // code
} else {
    // code
}

// Trailing commas in multi-line arrays/dicts
let array = [
    "item1",
    "item2",
    "item3",  // ✅ Trailing comma
]

// Max line length: ~120 caratteri (soft limit)

// Spacing
func myFunction(param1: String, param2: Int) -> Bool {  // ✅
func myFunction( param1:String,param2:Int )->Bool {     // ❌
```

#### Access Control

```swift
// Sempre specificare access level
public class PublicService { }      // Usato da altri moduli
internal class InternalService { }  // Default (stesso modulo)
private class PrivateService { }    // Solo stesso file
fileprivate var filePrivateVar      // Solo stesso file

// Properties: private(set) per read-only
class ViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []

    func updateVehicles() {
        vehicles = [...]  // ✅ Scrivibile internamente
    }
}
```

#### Comments & Documentation

```swift
// Commenti singola linea per spiegazioni brevi
// Questo metodo fa X

/*
 Commenti multilinea per spiegazioni lunghe o blocchi di codice
 commentati temporaneamente
 */

/// Documentazione con triple slash per funzioni pubbliche
/// Fetches all vehicles for a given user
/// - Parameter userId: The UUID of the user
/// - Returns: An array of VehicleResponse objects
/// - Throws: NetworkError if the request fails
func fetchVehicles(for userId: UUID) async throws -> [VehicleResponse] {
    // Implementation
}
```

#### Unwrapping Optionals

```swift
// ✅ Guard let per early return
func process(vehicle: Vehicle?) {
    guard let vehicle = vehicle else { return }
    // Usa vehicle
}

// ✅ If let per scope limitato
if let userId = userId {
    print(userId)
}

// ✅ Nil coalescing
let name = user.name ?? "Guest"

// ❌ Force unwrap (evitare se possibile)
let user = users.first!  // Crash se array vuoto!
```

### Git Workflow

#### Branch Naming

```bash
# Feature
feature/add-tyre-analysis
feature/improve-login-ux

# Bug fix
bugfix/fix-crash-on-logout
bugfix/vehicle-list-not-updating

# Hotfix
hotfix/critical-auth-issue
```

#### Commit Messages

```bash
# Format: <type>: <descrizione>

# Types:
feat: Nuova funzionalità
fix: Bug fix
refactor: Refactoring senza cambio funzionalità
style: Modifiche stilistiche (formatting, missing semicolons)
docs: Solo documentazione
test: Aggiunta/modifica test
chore: Manutenzione (build scripts, etc)

# Esempi:
git commit -m "feat: Aggiungi scansione targhe con CoreML"
git commit -m "fix: Risolvi crash al logout"
git commit -m "refactor: Estrai logica auth in servizio separato"
git commit -m "docs: Aggiorna README con nuove API"
```

### SwiftUI Best Practices

#### View Decomposition

```swift
// ❌ View monolitica
struct GarageScreen: View {
    var body: some View {
        VStack {
            // 200 righe di codice...
        }
    }
}

// ✅ View decomposte
struct GarageScreen: View {
    var body: some View {
        VStack {
            HeaderView()
            VehicleListView(vehicles: viewModel.vehicles)
            FooterView()
        }
    }
}

struct VehicleListView: View {
    let vehicles: [Vehicle]
    var body: some View { }
}
```

#### State Management

```swift
// ✅ @State per stato locale della view
struct CounterView: View {
    @State private var count = 0
    var body: some View {
        Button("+1") { count += 1 }
    }
}

// ✅ @StateObject per ViewModels (ownership)
struct GarageScreen: View {
    @StateObject private var viewModel = GarageViewModel()
}

// ✅ @ObservedObject per ViewModels passati (no ownership)
struct VehicleRow: View {
    @ObservedObject var vehicle: Vehicle
}

// ✅ @EnvironmentObject per dipendenze globali
struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
}
```

#### Performance

```swift
// ✅ Lazy loading per liste
LazyVStack {
    ForEach(vehicles) { vehicle in
        VehicleRow(vehicle: vehicle)
    }
}

// ✅ Task per operazioni async
.task {
    await viewModel.fetchData()
}

// ✅ Identificatori stabili per ForEach
ForEach(vehicles, id: \.id) { vehicle in  // ✅
ForEach(vehicles) { vehicle in            // ✅ se Identifiable
ForEach(0..<vehicles.count) { index in    // ❌ Evitare
```

---

## 🐛 Troubleshooting

### Problemi Comuni

#### 1. "Token expired" / 401 Unauthorized

**Causa**: JWT Supabase scaduto

**Soluzione**:
```swift
// Supabase gestisce automaticamente il refresh
// Se persiste, forzare logout/login:
try await SupabaseManager.client.auth.signOut()
```

#### 2. Build fails - Font not found

**Causa**: Font custom non copiati nel bundle

**Soluzione**:
1. Xcode → Target → Build Phases
2. Copy Bundle Resources
3. Aggiungi tutti i file `.ttf` da `/Core/Fonts/`
4. Verifica `Info.plist` → `UIAppFonts` array

#### 3. Background tasks not running

**Causa**: Background modes non configurati

**Soluzione**:
1. Verifica `Info.plist` → `UIBackgroundModes` → `remote-notification`
2. Verifica `BGTaskSchedulerPermittedIdentifiers`
3. Disabilita Low Power Mode su device fisico
4. Test con: Debug → Simulate Background Fetch

#### 4. Supabase connection failed

**Causa**: URL o KEY errati in `Api.plist`

**Soluzione**:
```bash
# Verifica credenziali
cat TyreVibes/Api.plist | grep SUPABASE

# Dovrebbe mostrare:
# SUPABASE_URL: https://jbcbrnegmqraivdfmlsn.supabase.co
# SUPABASE_KEY: sb_publishable_...
```

#### 5. Google Sign-In fails

**Causa**: URL Scheme non configurato

**Soluzione**:
1. Verifica `Info.plist` → `CFBundleURLTypes`
2. Deve contenere: `com.googleusercontent.apps.628808645845-...`
3. Verifica `GoogleService-Info.plist` presente

#### 6. Decoding error with API response

**Causa**: Mismatch tra schema JSON e modello Swift

**Debug**:
```swift
// Aggiungi logging nel NetworkManager
do {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(T.self, from: data)
    return result
} catch {
    // ⬇️ Aggiungi questo
    print("❌ Decoding error: \(error)")
    if let decodingError = error as? DecodingError {
        switch decodingError {
        case .keyNotFound(let key, _):
            print("Missing key: \(key)")
        case .typeMismatch(let type, let context):
            print("Type mismatch for type \(type): \(context)")
        default:
            print(decodingError)
        }
    }
    // Print raw JSON
    print("Raw JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
    throw NetworkError.decodingError(error)
}
```

#### 7. Edge Function timeout

**Causa**: Funzione impiega troppo tempo

**Soluzione**:
1. Controlla logs in Supabase Dashboard
2. Ottimizza query database (aggiungi indici)
3. Aumenta timeout nel NetworkManager (default 30s)

#### 8. RLS policy blocks query

**Causa**: Row Level Security impedisce accesso

**Debug**:
```sql
-- Verifica policy attive
SELECT * FROM pg_policies
WHERE tablename = 'your_table_name';

-- Testa query come service role (bypassa RLS)
SET ROLE service_role;
SELECT * FROM your_table;
```

### Logging & Debugging

#### AppLogger

Location: `/TyreVibes/Core/Utility/AppLogger.swift`

**Emoji conventions**:
- 🌐 Network requests
- ✅ Success operations
- ❌ Errors
- ⚠️ Warnings
- 🔍 Info/Debug
- 📋 Headers
- 📦 Request body
- 📥 Response data
- 🔗 Deep links

```swift
// Uso
print("🌐 [NetworkManager] Fetching vehicles")
print("✅ [VehicleService] Cached \(count) vehicles")
print("❌ [AuthService] Login failed: \(error)")
```

#### Debug Build Only

```swift
#if DEBUG
print("📋 [NetworkManager] Headers: \(headers)")
print("📦 [NetworkManager] Body: \(String(data: body, encoding: .utf8))")
#endif
```

### Performance Profiling

#### Instruments

```bash
# Memory leaks
Product → Profile → Leaks

# Time profiler
Product → Profile → Time Profiler

# Network activity
Product → Profile → Network
```

#### SwiftUI Performance

```swift
// Identifica view ridisegnate
let _ = Self._printChanges()  // In body

// Measure time
let start = Date()
await heavyOperation()
let elapsed = Date().timeIntervalSince(start)
print("⏱️ Operation took \(elapsed)s")
```

---

## 📚 Risorse Utili

### Documentazione Interna

- `/DEPLOYMENT_GUIDE.md` - Guida deployment completa
- `/BACKGROUND_JOBS.md` - Documentazione background jobs
- `/NOTIFICHE_GIORNALIERE.md` - Sistema notifiche
- `/supabase/README.md` - Setup Supabase
- `/Features/Auth/README_SPID_AUTH.md` - Autenticazione SPID

### File Chiave da Conoscere

| File | Location | Descrizione |
|------|----------|-------------|
| **NetworkManager** | `/Core/Service/NetworkManager.swift` | HTTP client con JWT automatico |
| **AuthService** | `/Core/Service/AuthService.swift` | Gestione autenticazione multi-provider |
| **SupabaseManager** | `/Core/Service/SupabaseManager.swift` | Client Supabase singleton |
| **VehicleService** | `/Core/Service/VehicleService.swift` | CRUD veicoli |
| **AppLogger** | `/Core/Utility/AppLogger.swift` | Sistema logging |
| **ErrorHandler** | `/Core/Utility/ErrorHandler.swift` | Gestione errori centralizzata |
| **Api.plist** | `/Api.plist` | Configurazione endpoint API |
| **Localizable** | `/Localizable.xcstrings` | Traduzioni IT/EN |

### Stack Overflow Tags

- `swift`, `swiftui`, `combine`
- `supabase`, `supabase-swift`
- `ios16`, `xcode`
- `coreml`, `vision-framework`

### Supabase Dashboard

- **URL**: https://supabase.com/dashboard/project/jbcbrnegmqraivdfmlsn
- **Database**: PostgreSQL con RLS
- **Auth**: Gestione utenti
- **Storage**: File uploads
- **Edge Functions**: Serverless functions
- **SQL Editor**: Query dirette

---

## ✅ Checklist per Nuove Features

Quando aggiungi una nuova feature:

- [ ] Crea un nuovo ViewModel in `/Core/ViewModel/` (se necessario)
- [ ] Aggiungi il Service in `/Core/Service/` per business logic
- [ ] Definisci i Model in `/Core/Model/` (struct Codable)
- [ ] Crea le View in `/Features/NomeFeature/`
- [ ] Aggiungi le stringhe localizzate in `Localizable.xcstrings`
- [ ] Implementa error handling con custom Error enum
- [ ] Usa `@MainActor` per i ViewModel
- [ ] Usa `async/await` per tutte le operazioni asincrone
- [ ] Aggiungi logging con emoji convention (`print("🌐 ...")`)
- [ ] Testa su device fisico (non solo simulatore)
- [ ] Scrivi test unitari in `/TyreVibesTests/`
- [ ] Aggiorna questo CLAUDE.md se necessario
- [ ] Commit con messaggio descrittivo (`feat: ...`)

---

## 🎓 Regole d'Oro per Assistenti AI

1. **Parla sempre in italiano** quando interagisci con questo progetto

2. **JWT Supabase ALWAYS**: Tutte le API usano Bearer token automatico tramite NetworkManager

3. **async/await ONLY**: Non usare mai completion handlers o callback

4. **MVVM strict**: View → ViewModel → Service → API. No business logic nelle View.

5. **@MainActor for ViewModels**: Tutti i ViewModel devono essere `@MainActor`

6. **Type-safe everything**: Usa enum per errori, stati, configurazioni. No magic strings.

7. **Test before commit**: Almeno build senza errori. Idealmente aggiungi test.

8. **Document as you go**: Aggiorna documentazione quando cambi architettura

9. **Security first**: Non committare secrets. Usa Keychain per token sensibili.

10. **User experience**: SwiftUI è dichiarativo. Pensa in termini di stato, non imperativi.

---

## 📞 Supporto

Per problemi o domande:

1. **Cerca nei file di documentazione** (`.md` files)
2. **Controlla i logs** di Supabase Dashboard
3. **Debug con emoji logging** (`print("🌐 ...")`)
4. **Verifica configurazione** in file `.plist`
5. **Consulta questo CLAUDE.md** per convenzioni e pattern

---

**Versione**: 1.0
**Ultimo aggiornamento**: 2025-11-16
**Autore**: TyreVibes Team + Claude AI

---

_Questo documento è destinato agli assistenti AI per comprendere rapidamente la struttura, le convenzioni e i workflow di sviluppo del progetto TyreVibes._
