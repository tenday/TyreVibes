# TyreVibes - Android (Kotlin)

Progetto Android convertito da iOS/Swift a Kotlin con Jetpack Compose.

## 📱 Informazioni Progetto

- **Package**: `it.tyrevibes.app`
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
- **Linguaggio**: Kotlin 1.9.20
- **UI Framework**: Jetpack Compose
- **Backend**: Supabase (con JWT authentication)

## 🏗️ Struttura Progetto

```
android/
├── app/
│   ├── src/main/
│   │   ├── java/it/tyrevibes/app/
│   │   │   ├── core/
│   │   │   │   ├── model/          # Data models
│   │   │   │   │   ├── Vehicle.kt
│   │   │   │   │   ├── Users.kt
│   │   │   │   │   ├── TyreAnalysisReportModels.kt
│   │   │   │   │   ├── AddressSuggestion.kt
│   │   │   │   │   ├── MaintenanceSchedule.kt
│   │   │   │   │   └── AppNotification.kt
│   │   │   │   └── service/        # Core services
│   │   │   │       ├── SupabaseManager.kt
│   │   │   │       ├── AuthService.kt
│   │   │   │       └── NetworkManager.kt
│   │   │   ├── TyreVibesApplication.kt
│   │   │   └── MainActivity.kt
│   │   ├── res/
│   │   │   ├── values/
│   │   │   │   ├── strings.xml
│   │   │   │   └── themes.xml
│   │   │   └── xml/
│   │   │       ├── file_paths.xml
│   │   │       ├── backup_rules.xml
│   │   │       └── data_extraction_rules.xml
│   │   └── AndroidManifest.xml
│   ├── build.gradle.kts
│   ├── google-services.json
│   └── proguard-rules.pro
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

## 📦 Dipendenze Principali

### Backend & Networking
- **Supabase Kotlin SDK** (v2.0.3): PostgREST, Auth, Realtime, Storage, Functions
- **Ktor Client** (v2.3.7): HTTP client per Android
- **Retrofit** (v2.9.0): API REST client
- **OkHttp** (v4.12.0): HTTP client avanzato

### UI
- **Jetpack Compose** (BOM 2024.01.00): Modern UI toolkit
- **Material 3**: Design system
- **Navigation Compose** (v2.7.6): Navigazione
- **Coil** (v2.5.0): Caricamento immagini

### Google Services
- **Google Sign-In** (v20.7.0): Autenticazione OAuth 2.0
- **Google Maps** (v18.2.0): Mappe e localizzazione
- **Play Services Location** (v21.0.1): Servizi di geolocalizzazione

### Machine Learning
- **ML Kit Text Recognition** (v16.0.0): OCR per riconoscimento targhe

### Camera
- **CameraX** (v1.3.1): Camera2, Lifecycle, View

### Storage & Preferences
- **DataStore** (v1.0.0): Preferenze moderne
- **Security Crypto** (v1.1.0-alpha06): Keystore sicuro

### Utilities
- **Accompanist Permissions** (v0.32.0): Gestione permessi
- **Work Manager** (v2.9.0): Background tasks

## 🔧 Configurazione

### 1. File di configurazione

Le credenziali sono gestite in `build.gradle.kts`:

```kotlin
buildConfigField("String", "SUPABASE_URL", "\"https://jbcbrnegmqraivdfmlsn.supabase.co\"")
buildConfigField("String", "SUPABASE_KEY", "\"sb_publishable_...\"")
buildConfigField("String", "BASE_URL", "\"https://www.tyrevibes.com/api\"")
```

### 2. Google Services

Il file `google-services.json` contiene la configurazione Firebase/Google:
- Project ID: `tyrevibes-f4fff`
- Package: `it.tyrevibes.app`

## 🚀 Come Buildare

```bash
cd android
./gradlew assembleDebug
```

Per build di release:
```bash
./gradlew assembleRelease
```

## 🔐 Autenticazione

L'app utilizza **Supabase Auth** con JWT tokens:

- Email/Password
- Google Sign-In OAuth
- OTP SMS verification
- Password recovery via email

Tutti i servizi (`AuthService`, `NetworkManager`) includono automaticamente il JWT token nelle richieste API.

## 📝 Prossimi Step

### Features da Implementare:
- [ ] ViewModels per MVVM
- [ ] UI Components in Jetpack Compose
- [ ] Features:
  - [ ] Authentication screens
  - [ ] Garage management
  - [ ] Tyre management
  - [ ] License plate recognition (ML Kit)
  - [ ] Map integration (Google Maps)
  - [ ] Settings
  - [ ] OnBoarding
  - [ ] Reports

### Servizi da Convertire:
- [ ] TyreService
- [ ] VehicleService
- [ ] LocationManager
- [ ] NotificationManager
- [ ] AddressService

## 📄 Licenza

© 2025 TyreVibes. Tutti i diritti riservati.
