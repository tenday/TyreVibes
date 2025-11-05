# Framework KPI per TyreVibes

**Versione:** 1.0
**Data:** 24 Ottobre 2025
**Piattaforma:** iOS
**Owner:** Product & Engineering Team

---

## 📊 Executive Summary

Questo documento definisce il framework completo di Key Performance Indicators (KPI) per TyreVibes, un'applicazione iOS per la gestione e monitoraggio pneumatici. I KPI sono organizzati in 4 categorie principali:

1. **Technical KPIs** - Qualità tecnica, performance, affidabilità
2. **Product KPIs** - Engagement, feature adoption, retention
3. **Business KPIs** - Revenue, conversion, crescita
4. **UX KPIs** - Soddisfazione utente, usabilità, accessibilità

Ogni KPI include:
- **Definizione** precisa e misurabile
- **Baseline** attuale (se disponibile)
- **Target** a 3, 6, 12 mesi
- **Metodo di misurazione**
- **Frequenza di reporting**
- **Owner** responsabile del KPI

---

## 🎯 Indice

1. [Technical KPIs](#1-technical-kpis)
2. [Product KPIs](#2-product-kpis)
3. [Business KPIs](#3-business-kpis)
4. [UX KPIs](#4-ux-kpis)
5. [Implementation Plan](#5-implementation-plan)
6. [Dashboard Design](#6-dashboard-design)
7. [Reporting Cadence](#7-reporting-cadence)
8. [Alert Thresholds](#8-alert-thresholds)

---

## 1. Technical KPIs

### 1.1 Performance Metrics

#### 🚀 App Launch Time (Cold Start)
**Definizione:** Tempo dall'icona tap alla visualizzazione della prima schermata interattiva

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| P50 (mediana) | 3.2s | 2.5s | 2.0s | 1.8s |
| P90 | 5.1s | 3.5s | 2.8s | 2.5s |
| P99 | 8.3s | 5.0s | 4.0s | 3.5s |

**Misurazione:**
```swift
// TyreVibesApp.swift
@main
struct TyreVibesApp: App {
    init() {
        let launchTime = ProcessInfo.processInfo.systemUptime
        AnalyticsManager.shared.track(.appLaunched(coldStartTime: launchTime))
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Engineering Lead
**Tool:** Xcode Instruments, Firebase Performance

---

#### ⚡ Screen Load Time
**Definizione:** Tempo per caricare completamente una schermata (tutti i dati visualizzati)

| Schermata | Baseline | Target | Threshold Critico |
|-----------|----------|--------|-------------------|
| GarageScreen | 2.1s | <1.5s | >3.0s |
| CarDetails | 3.4s | <2.0s | >4.0s |
| TyreAnalysisScreen | 1.8s | <1.0s | >2.5s |
| ShopScreen | 2.7s | <2.0s | >4.0s |
| ReportView | 4.2s | <3.0s | >5.0s |

**Misurazione:**
```swift
class GarageViewModel: ObservableObject {
    func loadVehicles() async {
        let startTime = Date()

        // Load data
        vehicles = try await vehicleService.fetchVehicles()

        let duration = Date().timeIntervalSince(startTime)
        await AnalyticsManager.shared.track(
            .screenLoaded(
                name: "GarageScreen",
                duration: duration,
                itemCount: vehicles.count
            )
        )
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Engineering Lead

---

#### 🎯 License Plate Detection Time
**Definizione:** Tempo dall'inizio scan alla detection riuscita

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Avg Detection Time | 2.3s | 1.8s | 1.5s | 1.2s |
| Success Rate | 78% | 85% | 90% | 95% |
| First Attempt Success | 65% | 75% | 82% | 88% |

**Misurazione:**
```swift
class ScanPlateViewModel: ObservableObject {
    func startScanning() {
        scanStartTime = Date()
        attemptCount = 0
    }

    func plateDetected(_ plate: String) {
        attemptCount += 1
        let duration = Date().timeIntervalSince(scanStartTime)

        AnalyticsManager.shared.track(
            .plateDetected(
                duration: duration,
                attempts: attemptCount,
                confidence: detectionConfidence
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** ML Engineer

---

#### 🔄 Tyre Analysis Processing Time
**Definizione:** Tempo per completare l'analisi del battistrada/superficie

| Tipo Analisi | Baseline | Target | Threshold Critico |
|--------------|----------|--------|-------------------|
| Tread Depth | 4.8s | <3.5s | >6.0s |
| Surface Analysis | 6.2s | <4.5s | >8.0s |
| Complete Analysis | 8.9s | <6.0s | >10.0s |

**Misurazione:**
```swift
class TyreAnalysisViewModel: ObservableObject {
    func analyzeTyre(image: UIImage, type: AnalysisType) async {
        let startTime = Date()

        let result = try await treadDepthAnalyzer.analyze(image)

        let duration = Date().timeIntervalSince(startTime)
        await AnalyticsManager.shared.track(
            .tyreAnalysisCompleted(
                type: type,
                duration: duration,
                imageSize: image.size,
                success: result != nil
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** ML Engineer

---

#### 📱 Frame Rate (FPS)
**Definizione:** Frame per secondo durante scroll e animazioni

| Schermata | Target | Critico |
|-----------|--------|---------|
| GarageScreen Scroll | 60 FPS | <45 FPS |
| ShopScreen Scroll | 60 FPS | <45 FPS |
| CarDetails Animations | 60 FPS | <50 FPS |
| Map Pan/Zoom | 60 FPS | <45 FPS |

**Misurazione:**
```swift
class PerformanceMonitor {
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0

    func startMonitoring(screen: String) {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            AnalyticsManager.shared.track(.fpsRecorded(screen: currentScreen, fps: fps))

            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }
}
```

**Frequenza:** Continua (sampled)
**Owner:** iOS Engineer

---

### 1.2 Quality Metrics

#### ✅ Test Coverage
**Definizione:** Percentuale di codice coperto da test automatizzati

| Tipo | Baseline | Target 3M | Target 6M | Target 12M |
|------|----------|-----------|-----------|------------|
| Overall Coverage | 12% | 50% | 70% | 85% |
| Unit Tests | 8% | 60% | 75% | 85% |
| Integration Tests | 0% | 30% | 50% | 70% |
| UI Tests | 0% | 20% | 35% | 50% |
| ViewModels | 15% | 80% | 90% | 95% |
| Services | 10% | 75% | 85% | 90% |
| Core Logic | 20% | 85% | 92% | 95% |

**Misurazione:**
- Xcode Code Coverage Reports
- Sonar Cloud integration
- CI/CD pipeline reports

**Frequenza:** Ad ogni PR + Weekly Report
**Owner:** QA Lead

---

#### 🐛 Bug Density
**Definizione:** Numero di bug per 1000 linee di codice

| Severità | Baseline | Target 3M | Target 6M | Target 12M |
|----------|----------|-----------|-----------|------------|
| Critical | 0.8/KLOC | 0.3/KLOC | 0.1/KLOC | 0.05/KLOC |
| Major | 2.1/KLOC | 1.2/KLOC | 0.8/KLOC | 0.5/KLOC |
| Minor | 4.5/KLOC | 3.0/KLOC | 2.0/KLOC | 1.5/KLOC |
| Total | 7.4/KLOC | 4.5/KLOC | 2.9/KLOC | 2.05/KLOC |

**Misurazione:**
- Jira/GitHub Issues tracking
- Bug severity classification
- Weekly bug triage meetings

**Frequenza:** Settimanale
**Owner:** Engineering Manager

---

#### 🔥 Crash-Free Rate
**Definizione:** Percentuale di sessioni senza crash

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Crash-Free Sessions | 96.8% | 98.5% | 99.2% | 99.5% |
| Crash-Free Users | 95.2% | 97.5% | 98.5% | 99.0% |

**Per Feature:**
| Feature | Target Crash-Free Rate |
|---------|----------------------|
| Plate Scanning | >99.0% |
| Tyre Analysis | >98.5% |
| Vehicle Registration | >99.5% |
| Authentication | >99.9% |
| General Navigation | >99.8% |

**Misurazione:**
```swift
// AppDelegate / TyreVibesApp.swift
import FirebaseCrashlytics

func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    FirebaseCrashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

    // Custom keys for better crash reporting
    Crashlytics.crashlytics().setUserID(currentUserId)
    Crashlytics.crashlytics().setCustomValue(appVersion, forKey: "app_version")
    Crashlytics.crashlytics().setCustomValue(osVersion, forKey: "os_version")
}

// Crash tracking
do {
    try riskyOperation()
} catch {
    Crashlytics.crashlytics().record(error: error)
    AnalyticsManager.shared.track(.errorOccurred(error: error, screen: currentScreen))
}
```

**Frequenza:** Giornaliera (alert se <99%)
**Owner:** Engineering Lead

---

#### ⚠️ Error Rate
**Definizione:** Percentuale di operazioni che falliscono

| Operazione | Target Success Rate | Max Error Rate |
|------------|-------------------|----------------|
| Login | >99.5% | <0.5% |
| Vehicle Add | >98.0% | <2.0% |
| Tyre Registration | >97.5% | <2.5% |
| API Calls | >99.0% | <1.0% |
| Image Upload | >97.0% | <3.0% |
| Report Generation | >98.5% | <1.5% |

**Misurazione:**
```swift
class NetworkManager {
    func request<T: Codable>(_ endpoint: String) async throws -> T {
        let startTime = Date()
        var success = false
        var statusCode: Int?
        var errorType: String?

        defer {
            let duration = Date().timeIntervalSince(startTime)
            AnalyticsManager.shared.track(
                .apiRequestCompleted(
                    endpoint: endpoint,
                    duration: duration,
                    success: success,
                    statusCode: statusCode,
                    errorType: errorType
                )
            )
        }

        do {
            let response = try await performRequest(endpoint)
            statusCode = response.statusCode
            success = true
            return response.data
        } catch let error as NetworkError {
            errorType = error.errorType
            throw error
        }
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Backend + iOS Engineer

---

#### 📦 Binary Size
**Definizione:** Dimensione dell'app scaricabile dall'App Store

| Metrica | Baseline | Target | Max Threshold |
|---------|----------|--------|---------------|
| Download Size | 47 MB | <40 MB | 50 MB |
| Install Size | 132 MB | <110 MB | 150 MB |
| ML Model Size | 18 MB | <12 MB | 20 MB |

**Misurazione:**
- App Store Connect Analytics
- Xcode Build Reports
- `xcodebuild -showBuildSettings`

**Frequenza:** Ad ogni release
**Owner:** iOS Engineer

---

#### 🔋 Battery Impact
**Definizione:** Consumo batteria medio dell'app

| Scenario | Target | Max Acceptable |
|----------|--------|----------------|
| Background (1h) | <2% | <5% |
| Active Use (1h) | <8% | <12% |
| Camera Scan (5m) | <3% | <5% |
| Idle (1h) | <0.5% | <1% |

**Misurazione:**
- Xcode Energy Log
- Battery Usage API
- User surveys

**Frequenza:** Settimanale
**Owner:** iOS Engineer

---

#### 📶 Network Usage
**Definizione:** Dati scaricati/uploadati dall'app

| Tipo | Target (per sessione) | Max Acceptable |
|------|---------------------|----------------|
| Download | <5 MB | <10 MB |
| Upload | <2 MB | <8 MB |
| Background Sync | <500 KB | <2 MB |

**Misurazione:**
```swift
class NetworkMonitor {
    func trackDataUsage() {
        let cellularData = getCellularDataUsage()
        let wifiData = getWiFiDataUsage()

        AnalyticsManager.shared.track(
            .networkUsage(
                cellular: cellularData,
                wifi: wifiData,
                session: currentSessionId
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Backend Engineer

---

### 1.3 Reliability Metrics

#### ⏱️ API Response Time
**Definizione:** Tempo di risposta delle API backend

| Endpoint | P50 Target | P90 Target | P99 Target | Max |
|----------|-----------|-----------|-----------|-----|
| /vehicles | <300ms | <500ms | <1000ms | 2s |
| /vehicles/:id | <200ms | <400ms | <800ms | 1.5s |
| /tyres | <250ms | <450ms | <900ms | 1.8s |
| /auth/login | <400ms | <700ms | <1200ms | 2.5s |
| /analytics/report | <600ms | <1200ms | <2000ms | 4s |

**Misurazione:**
```swift
class NetworkManager {
    func request<T>(_ endpoint: String) async throws -> T {
        let startTime = Date()

        let response = try await performRequest(endpoint)

        let latency = Date().timeIntervalSince(startTime) * 1000 // ms

        AnalyticsManager.shared.track(
            .apiLatency(
                endpoint: endpoint,
                latency: latency,
                statusCode: response.statusCode
            )
        )

        return response.data
    }
}
```

**Frequenza:** Tempo reale
**Owner:** Backend Engineer

---

#### 🔄 API Success Rate
**Definizione:** Percentuale di API calls che hanno successo

| Endpoint | Target | Alert Threshold |
|----------|--------|-----------------|
| All Endpoints | >99.0% | <98.0% |
| Critical Endpoints | >99.5% | <99.0% |
| Non-Critical | >98.0% | <97.0% |

**Misurazione:**
- Backend monitoring (DataDog, New Relic)
- Client-side tracking via AnalyticsManager
- Weekly API health reports

**Frequenza:** Tempo reale + Weekly Report
**Owner:** Backend Engineer

---

#### 💾 Data Sync Success Rate
**Definizione:** Percentuale di sincronizzazioni completate con successo

| Tipo Sync | Target | Alert Threshold |
|-----------|--------|-----------------|
| Full Sync | >98% | <95% |
| Incremental Sync | >99% | <97% |
| Conflict Resolution | >95% | <90% |

**Frequenza:** Giornaliera
**Owner:** Backend Engineer

---

## 2. Product KPIs

### 2.1 User Acquisition Metrics

#### 👥 New User Sign-ups
**Definizione:** Numero di nuovi utenti registrati

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Daily Sign-ups | 12 | 30 | 80 | 200 |
| Weekly Sign-ups | 84 | 210 | 560 | 1,400 |
| Monthly Sign-ups | 360 | 900 | 2,400 | 6,000 |
| Sign-up Growth Rate | - | +150% | +167% | +150% |

**Misurazione:**
```swift
class AuthService {
    func signUp(email: String, password: String) async throws {
        let user = try await supabase.auth.signUp(email: email, password: password)

        await AnalyticsManager.shared.track(
            .userSignedUp(
                method: .email,
                timestamp: Date(),
                source: acquisitionSource
            )
        )
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Product Manager

---

#### 📱 App Installs
**Definizione:** Numero di installazioni dall'App Store

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Daily Installs | 28 | 70 | 180 | 450 |
| Install-to-Signup Rate | 35% | 45% | 55% | 65% |

**Misurazione:**
- App Store Connect Analytics
- Firebase Analytics (first_open event)
- Attribution tracking (AppsFlyer, Branch)

**Frequenza:** Giornaliera
**Owner:** Growth Lead

---

#### 📊 Acquisition Channel Distribution
**Definizione:** Percentuale di utenti per canale di acquisizione

| Canale | Current | Target 6M |
|--------|---------|-----------|
| Organic Search | 45% | 40% |
| Social Media | 15% | 25% |
| Paid Ads | 10% | 20% |
| Referral | 8% | 10% |
| Direct | 22% | 5% |

**Misurazione:**
```swift
struct AcquisitionTracker {
    func trackInstallSource() {
        let source = detectInstallSource()

        AnalyticsManager.shared.track(
            .appInstalled(
                source: source,
                campaign: campaignId,
                medium: medium
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Growth Lead

---

### 2.2 Activation Metrics

#### ✅ Onboarding Completion Rate
**Definizione:** Percentuale di utenti che completano l'onboarding

| Step | Completion Rate | Target |
|------|----------------|--------|
| Welcome Screen | 100% | 100% |
| Tutorial Slide 1 | 82% | >90% |
| Tutorial Slide 2 | 71% | >85% |
| Tutorial Slide 3 | 65% | >80% |
| Complete Onboarding | 58% | >75% |

**Misurazione:**
```swift
class OnboardingViewModel: ObservableObject {
    func advanceToStep(_ step: Int) {
        AnalyticsManager.shared.track(
            .onboardingStepViewed(
                step: step,
                timestamp: Date()
            )
        )
    }

    func completeOnboarding() {
        let duration = Date().timeIntervalSince(onboardingStartTime)

        AnalyticsManager.shared.track(
            .onboardingCompleted(
                duration: duration,
                stepsViewed: viewedSteps.count
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 🚗 Time to First Vehicle
**Definizione:** Tempo dalla registrazione all'aggiunta del primo veicolo

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Median Time | 8m 34s | 5m | 3m | 2m |
| % within 5 min | 42% | 60% | 75% | 85% |
| % within 10 min | 68% | 80% | 90% | 95% |

**Misurazione:**
```swift
class GarageViewModel: ObservableObject {
    func addVehicle(_ vehicle: Vehicle) async {
        guard let user = currentUser else { return }

        let timeSinceSignup = Date().timeIntervalSince(user.createdAt)
        let isFirstVehicle = vehicleCount == 0

        if isFirstVehicle {
            await AnalyticsManager.shared.track(
                .firstVehicleAdded(
                    timeSinceSignup: timeSinceSignup,
                    method: addMethod // scan vs manual
                )
            )
        }
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 📸 Plate Scan Adoption Rate
**Definizione:** Percentuale di utenti che usano lo scanner targa vs inserimento manuale

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Scan Attempt Rate | 52% | 65% | 75% | 85% |
| Scan Success Rate | 78% | 85% | 90% | 95% |
| Scan to Manual Fallback | 22% | 15% | 10% | 5% |

**Misurazione:**
```swift
class VehicleAddViewModel: ObservableObject {
    func selectAddMethod(_ method: AddMethod) {
        AnalyticsManager.shared.track(
            .vehicleAddMethodSelected(
                method: method, // .scan or .manual
                screen: "VehicleAdd"
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

### 2.3 Engagement Metrics

#### 📈 Daily Active Users (DAU)
**Definizione:** Numero di utenti unici che aprono l'app almeno una volta al giorno

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| DAU | 180 | 450 | 1,200 | 3,000 |
| DAU Growth Rate | - | +150% | +167% | +150% |

**Misurazione:**
```swift
@main
struct TyreVibesApp: App {
    init() {
        AnalyticsManager.shared.track(.appOpened(timestamp: Date()))
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Product Manager

---

#### 📅 Weekly Active Users (WAU)
**Definizione:** Numero di utenti unici che aprono l'app almeno una volta a settimana

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| WAU | 620 | 1,550 | 4,100 | 10,200 |
| WAU Growth Rate | - | +150% | +165% | +149% |

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 📆 Monthly Active Users (MAU)
**Definizione:** Numero di utenti unici che aprono l'app almeno una volta al mese

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| MAU | 1,850 | 4,600 | 12,200 | 30,400 |
| MAU Growth Rate | - | +149% | +165% | +149% |

**Frequenza:** Mensile
**Owner:** Product Manager

---

#### 📊 DAU/MAU Ratio (Stickiness)
**Definizione:** Rapporto tra DAU e MAU (misura di quanto l'app è "sticky")

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| DAU/MAU | 9.7% | 12% | 15% | 18% |

**Benchmark:**
- Buono: >15%
- Ottimo: >20%
- Eccellente: >25%

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### ⏱️ Session Duration
**Definizione:** Durata media di una sessione utente

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Avg Session | 3m 42s | 5m | 6m 30s | 8m |
| Median Session | 2m 18s | 3m 30s | 4m 30s | 5m 30s |

**Per Scenario:**
| Scenario | Target Duration |
|----------|----------------|
| Quick Check | 1-2 min |
| Vehicle Add | 3-5 min |
| Tyre Analysis | 5-8 min |
| Browse Shop | 6-10 min |
| Report Review | 4-7 min |

**Misurazione:**
```swift
class SessionManager {
    private var sessionStart: Date?

    func applicationDidBecomeActive() {
        sessionStart = Date()
    }

    func applicationWillResignActive() {
        guard let start = sessionStart else { return }
        let duration = Date().timeIntervalSince(start)

        AnalyticsManager.shared.track(
            .sessionEnded(
                duration: duration,
                screensVisited: visitedScreens.count,
                actions: performedActions.count
            )
        )
    }
}
```

**Frequenza:** Giornaliera
**Owner:** Product Manager

---

#### 🔁 Session Frequency
**Definizione:** Numero medio di sessioni per utente attivo al giorno

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Sessions/DAU | 1.8 | 2.2 | 2.6 | 3.0 |

**Frequenza:** Settimanale
**Owner:** Product Manager

---

### 2.4 Feature Adoption Metrics

#### 🎯 Feature Usage Rate
**Definizione:** Percentuale di utenti attivi che usano una feature almeno una volta

| Feature | Current | Target 6M | Target 12M |
|---------|---------|-----------|------------|
| License Plate Scan | 52% | 70% | 85% |
| Tyre Analysis | 38% | 55% | 70% |
| Maintenance Tracking | 28% | 45% | 60% |
| Bollo Calculator | 15% | 30% | 45% |
| Shop Browse | 22% | 40% | 55% |
| Report Generation | 12% | 25% | 40% |
| SPID Login | 8% | 15% | 25% |
| Notifications | 65% | 75% | 85% |

**Misurazione:**
```swift
class FeatureTracker {
    func trackFeatureUsage(_ feature: Feature) {
        let lastUsed = UserDefaults.standard.object(forKey: "feature_\(feature.id)_last_used") as? Date
        let isFirstUse = lastUsed == nil

        AnalyticsManager.shared.track(
            .featureUsed(
                feature: feature.name,
                isFirstUse: isFirstUse,
                userSegment: userSegment
            )
        )

        UserDefaults.standard.set(Date(), forKey: "feature_\(feature.id)_last_used")
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 🆕 Feature Discovery Rate
**Definizione:** Tempo medio per scoprire/usare una feature dalla registrazione

| Feature | Current Discovery Time | Target |
|---------|----------------------|--------|
| License Plate Scan | 2.3 giorni | <1 giorno |
| Tyre Analysis | 5.8 giorni | <3 giorni |
| Maintenance Tracking | 12.4 giorni | <7 giorni |
| Shop | 8.7 giorni | <5 giorni |

**Frequenza:** Mensile
**Owner:** Product Manager

---

#### 🔄 Feature Retention
**Definizione:** Percentuale di utenti che continuano a usare una feature dopo il primo utilizzo

| Feature | Day 1 | Day 7 | Day 30 | Target D30 |
|---------|-------|-------|--------|------------|
| License Plate Scan | 100% | 45% | 28% | >40% |
| Tyre Analysis | 100% | 52% | 35% | >50% |
| Maintenance | 100% | 68% | 54% | >65% |
| Shop | 100% | 38% | 22% | >35% |

**Frequenza:** Settimanale
**Owner:** Product Manager

---

### 2.5 Retention Metrics

#### 📊 User Retention Cohorts
**Definizione:** Percentuale di utenti che ritornano dopo N giorni dalla registrazione

| Cohort | Baseline | Target 3M | Target 6M | Target 12M |
|--------|----------|-----------|-----------|------------|
| Day 1 | 42% | 55% | 65% | 75% |
| Day 7 | 28% | 40% | 50% | 60% |
| Day 14 | 22% | 32% | 42% | 52% |
| Day 30 | 18% | 28% | 38% | 48% |
| Day 60 | 14% | 22% | 32% | 42% |
| Day 90 | 11% | 18% | 28% | 38% |

**Benchmark Industry:**
- Day 1: 50-60% (buono)
- Day 7: 30-40% (buono)
- Day 30: 20-30% (buono)

**Misurazione:**
```swift
class RetentionTracker {
    func trackUserReturn() {
        guard let user = currentUser else { return }

        let daysSinceSignup = Calendar.current.dateComponents(
            [.day],
            from: user.createdAt,
            to: Date()
        ).day ?? 0

        AnalyticsManager.shared.track(
            .userReturned(
                daysSinceSignup: daysSinceSignup,
                cohortWeek: user.signupWeek
            )
        )
    }
}
```

**Frequenza:** Settimanale per cohort
**Owner:** Product Manager

---

#### 🔙 Churn Rate
**Definizione:** Percentuale di utenti che abbandonano l'app

| Periodo | Current Churn | Target Churn | Max Acceptable |
|---------|--------------|--------------|----------------|
| Weekly | 8.2% | <5% | 10% |
| Monthly | 22.5% | <15% | 20% |
| Quarterly | 45.8% | <30% | 40% |

**Definizione di Churned User:**
- Nessuna apertura app per 30+ giorni consecutivi
- Nessuna interazione per 45+ giorni

**Misurazione:**
```swift
// Backend job (daily)
func calculateChurn() {
    let inactiveUsers = users.filter { user in
        let daysSinceLastActive = Date().daysSince(user.lastActiveAt)
        return daysSinceLastActive >= 30
    }

    let churnRate = Double(inactiveUsers.count) / Double(totalUsers)

    AnalyticsManager.shared.track(
        .churnCalculated(
            rate: churnRate,
            period: .monthly,
            inactiveCount: inactiveUsers.count
        )
    )
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### ⏮️ Resurrection Rate
**Definizione:** Percentuale di utenti churned che ritornano

| Periodo Churn | Resurrection Rate | Target |
|--------------|------------------|--------|
| 30-60 giorni | 12% | >20% |
| 60-90 giorni | 6% | >12% |
| 90+ giorni | 3% | >8% |

**Frequenza:** Mensile
**Owner:** Growth Lead

---

## 3. Business KPIs

### 3.1 Revenue Metrics

#### 💰 Monthly Recurring Revenue (MRR)
**Definizione:** Ricavi ricorrenti mensili da subscription

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| Total MRR | €1,240 | €3,500 | €9,500 | €25,000 |
| MRR Growth Rate | - | +182% | +171% | +163% |
| MRR per User | €8.20 | €9.50 | €10.50 | €11.50 |

**Componenti MRR:**
```
MRR = (New MRR) + (Expansion MRR) - (Churned MRR) - (Contraction MRR)
```

**Misurazione:**
```swift
class SubscriptionManager {
    func trackSubscription(_ subscription: Subscription) {
        AnalyticsManager.shared.track(
            .subscriptionStarted(
                plan: subscription.plan,
                price: subscription.monthlyPrice,
                billingCycle: subscription.cycle // monthly, annual
            )
        )
    }

    func trackSubscriptionCancellation(_ subscription: Subscription) {
        let lifetime = subscription.createdAt.daysUntil(Date())

        AnalyticsManager.shared.track(
            .subscriptionCancelled(
                plan: subscription.plan,
                lifetimeDays: lifetime,
                reason: cancellationReason
            )
        )
    }
}
```

**Frequenza:** Giornaliera + Monthly Report
**Owner:** Finance Lead

---

#### 💵 Average Revenue Per User (ARPU)
**Definizione:** Ricavo medio per utente attivo mensile

| Metrica | Baseline | Target 3M | Target 6M | Target 12M |
|---------|----------|-----------|-----------|------------|
| ARPU (all users) | €0.67 | €0.76 | €0.78 | €0.82 |
| ARPU (paying) | €9.80 | €10.50 | €11.20 | €12.00 |

**Calcolo:**
```
ARPU = Total Revenue / MAU
ARPU (paying) = Total Revenue / Paying Users
```

**Frequenza:** Mensile
**Owner:** Finance Lead

---

#### 💎 Lifetime Value (LTV)
**Definizione:** Ricavo totale atteso da un utente durante la sua "vita" sull'app

| Segmento | Current LTV | Target LTV | LTV:CAC Ratio |
|----------|------------|------------|---------------|
| Free User | €2.40 | €4.50 | 3.0:1 |
| Premium Monthly | €38.50 | €65.00 | 5.5:1 |
| Premium Yearly | €127.00 | €210.00 | 8.0:1 |

**Calcolo:**
```
LTV = (ARPU × Gross Margin %) / Churn Rate

Esempio:
ARPU = €9.80
Gross Margin = 75%
Churn Rate = 15% monthly

LTV = (€9.80 × 0.75) / 0.15 = €49.00
```

**Misurazione:**
- Tracking ricavi per cohort
- Churn rate monitoring
- Customer lifetime tracking

**Frequenza:** Mensile
**Owner:** Finance Lead

---

#### 💸 Customer Acquisition Cost (CAC)
**Definizione:** Costo medio per acquisire un nuovo utente

| Canale | Current CAC | Target CAC | Max Acceptable |
|--------|------------|------------|----------------|
| Organic | €0.00 | €0.00 | €0.00 |
| Social Ads | €3.80 | €2.50 | €5.00 |
| Google Ads | €4.20 | €3.00 | €6.00 |
| Referral | €1.20 | €1.00 | €2.00 |
| Blended CAC | €1.85 | €1.50 | €3.00 |

**Calcolo:**
```
CAC = Total Marketing Spend / New Users Acquired
```

**Frequenza:** Mensile
**Owner:** Growth Lead

---

#### 📈 LTV:CAC Ratio
**Definizione:** Rapporto tra lifetime value e customer acquisition cost

| Segmento | Current Ratio | Target Ratio | Healthy Range |
|----------|--------------|--------------|---------------|
| Free Users | 1.3:1 | 3.0:1 | >3:1 |
| Premium Users | 4.8:1 | 6.0:1 | >5:1 |
| Blended | 3.2:1 | 5.0:1 | >4:1 |

**Benchmark:**
- <1:1 - Insostenibile
- 1-3:1 - Problematico
- 3-5:1 - Buono
- >5:1 - Eccellente

**Frequenza:** Mensile
**Owner:** Finance Lead + Growth Lead

---

### 3.2 Conversion Metrics

#### 🎯 Free to Premium Conversion Rate
**Definizione:** Percentuale di utenti free che diventano premium

| Periodo | Current | Target 3M | Target 6M | Target 12M |
|---------|---------|-----------|-----------|------------|
| 7-day | 2.1% | 3.5% | 5.0% | 6.5% |
| 14-day | 3.8% | 5.5% | 7.5% | 9.5% |
| 30-day | 5.2% | 7.5% | 10.0% | 13.0% |
| 90-day | 6.8% | 9.5% | 13.0% | 17.0% |

**Misurazione:**
```swift
class PaywallManager {
    func presentPaywall(trigger: PaywallTrigger) {
        AnalyticsManager.shared.track(
            .paywallPresented(
                trigger: trigger, // feature_gate, onboarding, settings
                plan: recommendedPlan
            )
        )
    }

    func purchaseCompleted(_ product: Product) {
        guard let user = currentUser else { return }

        let daysSinceSignup = Date().daysSince(user.createdAt)

        AnalyticsManager.shared.track(
            .subscriptionPurchased(
                plan: product.id,
                price: product.price,
                daysSinceSignup: daysSinceSignup,
                paywallTrigger: lastPaywallTrigger
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 🎁 Trial to Paid Conversion Rate
**Definizione:** Percentuale di utenti trial che diventano paying (se implementato trial)

| Metrica | Target | Industry Benchmark |
|---------|--------|-------------------|
| Trial to Paid | >40% | 25-45% |
| Trial Duration | 7 giorni | 7-14 giorni |

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 💳 Paywall Conversion Rate
**Definizione:** Percentuale di utenti che vedono paywall e completano acquisto

| Paywall Trigger | Current | Target | Industry Avg |
|----------------|---------|--------|--------------|
| Feature Gate | 8.2% | >12% | 5-10% |
| Onboarding | 4.5% | >7% | 3-6% |
| Settings | 2.1% | >4% | 2-4% |
| Post-Analysis | 11.3% | >15% | 8-12% |
| Overall | 6.5% | >10% | 5-8% |

**Misurazione:**
```swift
class PaywallViewModel: ObservableObject {
    func trackPaywallView() {
        paywallViewTime = Date()

        AnalyticsManager.shared.track(
            .paywallViewed(
                trigger: trigger,
                plans: availablePlans
            )
        )
    }

    func trackPaywallDismiss() {
        let duration = Date().timeIntervalSince(paywallViewTime)

        AnalyticsManager.shared.track(
            .paywallDismissed(
                trigger: trigger,
                viewDuration: duration,
                interacted: userInteracted
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 📊 Subscription Plan Distribution
**Definizione:** Distribuzione percentuale tra piani subscription

| Piano | Current | Target |
|-------|---------|--------|
| Free | 93.2% | 87.0% |
| Monthly Premium | 4.8% | 6.5% |
| Yearly Premium | 2.0% | 6.5% |

**Target Mix Optimization:**
- Aumentare % yearly (maggior LTV, minor churn)
- Mantenere free users engaged (word of mouth)

**Frequenza:** Mensile
**Owner:** Product Manager

---

### 3.3 Growth Metrics

#### 📈 User Growth Rate
**Definizione:** Tasso di crescita della user base

| Periodo | Current Growth | Target Growth |
|---------|---------------|---------------|
| Week over Week | 6.2% | >10% |
| Month over Month | 28.4% | >40% |
| Quarter over Quarter | 112.5% | >150% |

**Calcolo:**
```
Growth Rate = ((New Users - Churned Users) / Previous Period Users) × 100
```

**Frequenza:** Settimanale
**Owner:** Growth Lead

---

#### 🎯 Viral Coefficient (K-Factor)
**Definizione:** Numero medio di nuovi utenti portati da ogni utente esistente

| Metrica | Current | Target | Viral Growth |
|---------|---------|--------|--------------|
| K-Factor | 0.32 | >1.0 | K>1 = crescita virale |
| Invites Sent/User | 0.8 | 2.5 | - |
| Invite Accept Rate | 40% | 40% | - |

**Calcolo:**
```
K = (Invites per User) × (Conversion Rate)

Esempio:
Invites = 2.5
Conversion = 40%
K = 2.5 × 0.40 = 1.0 (growth esponenziale!)
```

**Misurazione:**
```swift
class ReferralManager {
    func sendInvite(to contact: Contact) {
        AnalyticsManager.shared.track(
            .inviteSent(
                userId: currentUserId,
                channel: inviteChannel // sms, email, social
            )
        )
    }

    func trackReferralSignup(referralCode: String) {
        AnalyticsManager.shared.track(
            .referralSignup(
                referrerId: getReferrerId(code: referralCode),
                refereeId: currentUserId
            )
        )
    }
}
```

**Frequenza:** Mensile
**Owner:** Growth Lead

---

#### 🔄 Referral Program Metrics
**Definizione:** Performance del programma referral (se implementato)

| Metrica | Target |
|---------|--------|
| % Users Who Refer | >15% |
| Avg Referrals/Referrer | >2.5 |
| Referral Conversion Rate | >35% |
| Referred User LTV | >120% of organic |

**Frequenza:** Mensile
**Owner:** Growth Lead

---

## 4. UX KPIs

### 4.1 Satisfaction Metrics

#### ⭐ App Store Rating
**Definizione:** Rating medio sull'App Store

| Metrica | Current | Target 3M | Target 6M | Target 12M |
|---------|---------|-----------|-----------|------------|
| Overall Rating | 4.2 ⭐ | 4.4 ⭐ | 4.6 ⭐ | 4.7 ⭐ |
| 5-star % | 58% | 65% | 72% | 78% |
| 1-star % | 12% | 8% | 5% | 3% |

**Rating Distribution Target:**
```
5 ⭐ : ████████████████████ 78%
4 ⭐ : ████░░░░░░░░░░░░░░░░ 15%
3 ⭐ : ██░░░░░░░░░░░░░░░░░░ 4%
2 ⭐ : █░░░░░░░░░░░░░░░░░░░ 2%
1 ⭐ : █░░░░░░░░░░░░░░░░░░░ 1%
```

**Misurazione:**
- App Store Connect Analytics
- SKStoreReviewController prompts
- In-app satisfaction surveys

**Frequenza:** Settimanale
**Owner:** Product Manager

---

#### 📝 Net Promoter Score (NPS)
**Definizione:** Probabilità che gli utenti raccomandino l'app (0-10)

| Categoria | Score Range | Current % | Target % |
|-----------|------------|-----------|----------|
| Promoters | 9-10 | 42% | >60% |
| Passives | 7-8 | 38% | <25% |
| Detractors | 0-6 | 20% | <15% |
| **NPS Score** | **(P-D)** | **+22** | **>50** |

**Calcolo:**
```
NPS = % Promoters - % Detractors

Esempio:
Promoters: 60%
Detractors: 10%
NPS = 60 - 10 = +50 (Eccellente!)
```

**Benchmark:**
- <0: Critico
- 0-30: Migliorabile
- 30-50: Buono
- 50-70: Eccellente
- >70: World Class

**Misurazione:**
```swift
class NPSSurveyManager {
    func promptNPSSurvey() {
        // Show after 7 days of usage, 3+ sessions
        guard shouldShowNPS() else { return }

        presentNPSSurvey { score, feedback in
            AnalyticsManager.shared.track(
                .npsSurveyCompleted(
                    score: score,
                    category: self.getNPSCategory(score),
                    feedback: feedback,
                    userSegment: currentUserSegment
                )
            )
        }
    }

    private func getNPSCategory(_ score: Int) -> NPSCategory {
        switch score {
        case 9...10: return .promoter
        case 7...8: return .passive
        default: return .detractor
        }
    }
}
```

**Frequenza:** Mensile (survey ogni 90 giorni per utente)
**Owner:** Product Manager

---

#### 😊 Customer Satisfaction Score (CSAT)
**Definizione:** Soddisfazione post-interazione specifica (1-5 scale)

| Feature/Interaction | Current CSAT | Target |
|--------------------|-------------|--------|
| Overall App | 3.9/5 | >4.3/5 |
| Plate Scanning | 4.1/5 | >4.5/5 |
| Tyre Analysis | 3.7/5 | >4.2/5 |
| Vehicle Registration | 4.0/5 | >4.4/5 |
| Customer Support | 3.6/5 | >4.5/5 |

**Misurazione:**
```swift
class CSATManager {
    func promptFeatureSatisfaction(_ feature: Feature) {
        // Show dopo completamento feature
        presentSatisfactionSurvey(feature: feature) { rating in
            AnalyticsManager.shared.track(
                .featureSatisfaction(
                    feature: feature.name,
                    rating: rating,
                    context: interactionContext
                )
            )
        }
    }
}
```

**Frequenza:** Continua (post-interaction)
**Owner:** Product Manager

---

### 4.2 Usability Metrics

#### ⏱️ Task Completion Time
**Definizione:** Tempo medio per completare task principali

| Task | Current | Target | Max Acceptable |
|------|---------|--------|----------------|
| Add Vehicle (scan) | 1m 48s | <1m 15s | 2m 30s |
| Add Vehicle (manual) | 3m 24s | <2m 30s | 4m |
| Register Tyre | 2m 12s | <1m 45s | 3m |
| Analyze Tyre | 52s | <40s | 1m 30s |
| Generate Report | 38s | <30s | 1m |
| Find Shop | 1m 5s | <50s | 1m 30s |

**Misurazione:**
```swift
class TaskTimer {
    private var taskStartTime: [String: Date] = [:]

    func startTask(_ taskName: String) {
        taskStartTime[taskName] = Date()

        AnalyticsManager.shared.track(
            .taskStarted(
                task: taskName,
                screen: currentScreen
            )
        )
    }

    func completeTask(_ taskName: String, success: Bool) {
        guard let startTime = taskStartTime[taskName] else { return }

        let duration = Date().timeIntervalSince(startTime)

        AnalyticsManager.shared.track(
            .taskCompleted(
                task: taskName,
                duration: duration,
                success: success,
                attempts: attemptCount
            )
        )

        taskStartTime.removeValue(forKey: taskName)
    }
}
```

**Frequenza:** Settimanale
**Owner:** UX Designer

---

#### ✅ Task Success Rate
**Definizione:** Percentuale di task completati con successo

| Task | Current | Target | Min Acceptable |
|------|---------|--------|----------------|
| Add Vehicle | 92% | >95% | 90% |
| Plate Scan | 78% | >90% | 85% |
| Tyre Analysis | 88% | >93% | 88% |
| Report Generation | 96% | >98% | 95% |
| Account Creation | 94% | >97% | 93% |

**Frequenza:** Settimanale
**Owner:** UX Designer

---

#### 🔙 Error Recovery Rate
**Definizione:** Percentuale di utenti che risolvono un errore e completano il task

| Error Type | Recovery Rate | Target |
|-----------|--------------|--------|
| Plate Scan Failed | 65% | >80% |
| Photo Quality Low | 72% | >85% |
| Network Error | 58% | >75% |
| Form Validation | 88% | >92% |

**Misurazione:**
```swift
class ErrorRecoveryTracker {
    func trackError(_ error: AppError, screen: String) {
        errorTimestamp[error.id] = Date()

        AnalyticsManager.shared.track(
            .errorOccurred(
                error: error,
                screen: screen,
                context: errorContext
            )
        )
    }

    func trackRecovery(errorId: String, success: Bool) {
        guard let errorTime = errorTimestamp[errorId] else { return }

        let recoveryTime = Date().timeIntervalSince(errorTime)

        AnalyticsManager.shared.track(
            .errorRecovery(
                errorId: errorId,
                success: success,
                recoveryTime: recoveryTime
            )
        )
    }
}
```

**Frequenza:** Settimanale
**Owner:** UX Designer + Engineering

---

#### 🚪 Exit Rate per Screen
**Definizione:** Percentuale di sessioni che terminano su ogni schermata

| Screen | Current Exit Rate | Target | Max Acceptable |
|--------|------------------|--------|----------------|
| GarageScreen | 18% | <15% | 20% |
| CarDetails | 12% | <10% | 15% |
| VehicleAddForm | 28% | <20% | 25% |
| PaywallScreen | 78% | <65% | 80% |
| ShopScreen | 24% | <18% | 25% |

**High Exit Rate = Problema UX**

**Frequenza:** Settimanale
**Owner:** UX Designer

---

### 4.3 Accessibility Metrics

#### ♿ VoiceOver Usage
**Definizione:** Percentuale di utenti che usano VoiceOver

| Metrica | Current | Target |
|---------|---------|--------|
| VoiceOver Users | 2.1% | Track (no target) |
| VoiceOver Task Success | 68% | >90% |

**Misurazione:**
```swift
func applicationDidFinishLaunching() {
    let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

    AnalyticsManager.shared.track(
        .accessibilityFeatureUsed(
            feature: "VoiceOver",
            enabled: isVoiceOverRunning
        )
    )

    // Track VoiceOver state changes
    NotificationCenter.default.addObserver(
        forName: UIAccessibility.voiceOverStatusDidChangeNotification,
        object: nil,
        queue: .main
    ) { _ in
        // Track change
    }
}
```

**Frequenza:** Mensile
**Owner:** iOS Engineer

---

#### 🔤 Dynamic Type Usage
**Definizione:** Distribuzione delle dimensioni testo usate

| Size | Usage % | Target Support |
|------|---------|---------------|
| XS - M | 78% | 100% |
| L - XL | 16% | 100% |
| XXL+ | 6% | 100% |

**Misurazione:**
```swift
@Environment(\.sizeCategory) var sizeCategory

func trackDynamicType() {
    AnalyticsManager.shared.track(
        .dynamicTypeUsed(
            category: sizeCategory.rawValue
        )
    )
}
```

**Frequenza:** Mensile
**Owner:** iOS Engineer

---

#### 🎨 Contrast Ratio Compliance
**Definizione:** Percentuale di elementi UI che rispettano WCAG AA (4.5:1)

| Componente | Compliant | Target |
|-----------|-----------|--------|
| Text on Background | 87% | 100% |
| Buttons | 94% | 100% |
| Icons | 81% | 100% |
| Links | 92% | 100% |

**Audit Tool:** Xcode Accessibility Inspector

**Frequenza:** Ad ogni release
**Owner:** UX Designer

---

### 4.4 Support Metrics

#### 📧 Support Ticket Volume
**Definizione:** Numero di ticket di supporto ricevuti

| Metrica | Current | Target |
|---------|---------|--------|
| Tickets/100 DAU | 2.8 | <1.5 |
| Avg Response Time | 18h | <12h |
| First Response Time | 6h | <4h |
| Resolution Time | 38h | <24h |

**Per Categoria:**
| Categoria | % of Tickets | Target % |
|-----------|-------------|----------|
| Bug Reports | 35% | <25% |
| Feature Requests | 18% | Track |
| How-to Questions | 28% | <15% (migliorare onboarding) |
| Account Issues | 12% | <10% |
| Other | 7% | Track |

**Frequenza:** Settimanale
**Owner:** Customer Success Lead

---

#### ❓ In-App Help Usage
**Definizione:** Utilizzo delle risorse di aiuto in-app

| Risorsa | Usage Rate | Target |
|---------|-----------|--------|
| FAQ | 8% users | >15% |
| Tutorial Videos | 4% users | >10% |
| Tooltips | 22% users | Track |
| Contact Support | 2.8% users | <2% |

**Frequenza:** Mensile
**Owner:** Product Manager

---

## 5. Implementation Plan

### 5.1 Analytics Infrastructure

#### Phase 1: Foundation (Settimane 1-2)

**1.1 AnalyticsManager Implementation**

```swift
// Core/Service/AnalyticsManager.swift

protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: Any] { get }
    var timestamp: Date { get }
    var userId: String? { get }
}

actor AnalyticsManager {
    static let shared = AnalyticsManager()

    private var eventQueue: [AnalyticsEvent] = []
    private var isEnabled: Bool
    private let batchSize = 20
    private let flushInterval: TimeInterval = 60 // 1 min

    init() {
        isEnabled = FeatureFlags.shared.isAnalyticsEnabled
        startPeriodicFlush()
    }

    // MARK: - Event Tracking

    func track(_ event: Event) {
        guard isEnabled else { return }

        eventQueue.append(event)

        // Log locally for debugging
        AppLogger.shared.info("📊 Analytics: \(event.name)", metadata: event.parameters)

        // Flush if batch size reached
        if eventQueue.count >= batchSize {
            Task {
                await flush()
            }
        }
    }

    // MARK: - Event Types

    enum Event: AnalyticsEvent {
        // Lifecycle
        case appOpened(timestamp: Date)
        case appLaunched(coldStartTime: TimeInterval)
        case sessionEnded(duration: TimeInterval, screensVisited: Int, actions: Int)

        // Authentication
        case userSignedUp(method: AuthMethod, source: String?)
        case userLoggedIn(method: AuthMethod)
        case userLoggedOut

        // Onboarding
        case onboardingStepViewed(step: Int, timestamp: Date)
        case onboardingCompleted(duration: TimeInterval, stepsViewed: Int)
        case onboardingSkipped(lastStep: Int)

        // Vehicle Management
        case vehicleAddMethodSelected(method: VehicleAddMethod, screen: String)
        case plateDetected(duration: TimeInterval, attempts: Int, confidence: Double)
        case plateScanFailed(reason: String, attempts: Int)
        case vehicleAdded(method: VehicleAddMethod, timeSinceSignup: TimeInterval?)
        case firstVehicleAdded(timeSinceSignup: TimeInterval, method: VehicleAddMethod)
        case vehicleViewed(vehicleId: String)
        case vehicleDeleted(vehicleId: String, vehicleAge: TimeInterval)

        // Tyre Management
        case tyreRegistered(method: TyreAddMethod)
        case tyreAnalysisStarted(type: AnalysisType)
        case tyreAnalysisCompleted(type: AnalysisType, duration: TimeInterval, success: Bool)
        case tyreAnalysisFailed(type: AnalysisType, error: String)

        // Reports
        case reportViewed(reportId: String, reportType: String)
        case reportGenerated(format: String, duration: TimeInterval)
        case reportShared(channel: String)

        // Shop
        case shopViewed
        case tyreProductViewed(brand: String, model: String)
        case shopFiltered(filters: [String: String])

        // Subscription
        case paywallPresented(trigger: PaywallTrigger, plan: String)
        case paywallViewed(trigger: PaywallTrigger, plans: [String])
        case paywallDismissed(trigger: PaywallTrigger, viewDuration: TimeInterval, interacted: Bool)
        case subscriptionPurchased(plan: String, price: Decimal, daysSinceSignup: Int, trigger: PaywallTrigger)
        case subscriptionCancelled(plan: String, lifetimeDays: Int, reason: String?)

        // Features
        case featureUsed(feature: String, isFirstUse: Bool, userSegment: String)

        // Screens
        case screenLoaded(name: String, duration: TimeInterval, itemCount: Int?)
        case screenViewed(name: String)

        // Performance
        case fpsRecorded(screen: String, fps: Double)
        case apiLatency(endpoint: String, latency: Double, statusCode: Int)
        case apiRequestCompleted(endpoint: String, duration: TimeInterval, success: Bool, statusCode: Int?, errorType: String?)

        // Errors
        case errorOccurred(error: AppError, screen: String)
        case errorRecovery(errorId: String, success: Bool, recoveryTime: TimeInterval)

        // Tasks
        case taskStarted(task: String, screen: String)
        case taskCompleted(task: String, duration: TimeInterval, success: Bool, attempts: Int)

        // User Feedback
        case npsSurveyCompleted(score: Int, category: NPSCategory, feedback: String?, userSegment: String)
        case featureSatisfaction(feature: String, rating: Int, context: String)

        // Referrals
        case inviteSent(userId: String, channel: String)
        case referralSignup(referrerId: String, refereeId: String)

        // Accessibility
        case accessibilityFeatureUsed(feature: String, enabled: Bool)
        case dynamicTypeUsed(category: String)

        var name: String {
            switch self {
            case .appOpened: return "app_opened"
            case .appLaunched: return "app_launched"
            case .sessionEnded: return "session_ended"
            case .userSignedUp: return "user_signed_up"
            case .userLoggedIn: return "user_logged_in"
            case .userLoggedOut: return "user_logged_out"
            case .onboardingStepViewed: return "onboarding_step_viewed"
            case .onboardingCompleted: return "onboarding_completed"
            case .onboardingSkipped: return "onboarding_skipped"
            case .vehicleAddMethodSelected: return "vehicle_add_method_selected"
            case .plateDetected: return "plate_detected"
            case .plateScanFailed: return "plate_scan_failed"
            case .vehicleAdded: return "vehicle_added"
            case .firstVehicleAdded: return "first_vehicle_added"
            case .vehicleViewed: return "vehicle_viewed"
            case .vehicleDeleted: return "vehicle_deleted"
            case .tyreRegistered: return "tyre_registered"
            case .tyreAnalysisStarted: return "tyre_analysis_started"
            case .tyreAnalysisCompleted: return "tyre_analysis_completed"
            case .tyreAnalysisFailed: return "tyre_analysis_failed"
            case .reportViewed: return "report_viewed"
            case .reportGenerated: return "report_generated"
            case .reportShared: return "report_shared"
            case .shopViewed: return "shop_viewed"
            case .tyreProductViewed: return "tyre_product_viewed"
            case .shopFiltered: return "shop_filtered"
            case .paywallPresented: return "paywall_presented"
            case .paywallViewed: return "paywall_viewed"
            case .paywallDismissed: return "paywall_dismissed"
            case .subscriptionPurchased: return "subscription_purchased"
            case .subscriptionCancelled: return "subscription_cancelled"
            case .featureUsed: return "feature_used"
            case .screenLoaded: return "screen_loaded"
            case .screenViewed: return "screen_viewed"
            case .fpsRecorded: return "fps_recorded"
            case .apiLatency: return "api_latency"
            case .apiRequestCompleted: return "api_request_completed"
            case .errorOccurred: return "error_occurred"
            case .errorRecovery: return "error_recovery"
            case .taskStarted: return "task_started"
            case .taskCompleted: return "task_completed"
            case .npsSurveyCompleted: return "nps_survey_completed"
            case .featureSatisfaction: return "feature_satisfaction"
            case .inviteSent: return "invite_sent"
            case .referralSignup: return "referral_signup"
            case .accessibilityFeatureUsed: return "accessibility_feature_used"
            case .dynamicTypeUsed: return "dynamic_type_used"
            }
        }

        var parameters: [String: Any] {
            // Implementation for each case
            // Returns dictionary of parameters
            switch self {
            case .appLaunched(let coldStartTime):
                return ["cold_start_time": coldStartTime]
            case .userSignedUp(let method, let source):
                return [
                    "method": method.rawValue,
                    "source": source ?? "unknown"
                ]
            // ... implement for all cases
            default:
                return [:]
            }
        }

        var timestamp: Date {
            return Date()
        }

        var userId: String? {
            return AuthService.shared.currentUserId
        }
    }

    // MARK: - Flush

    private func flush() async {
        guard !eventQueue.isEmpty else { return }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        do {
            try await sendToBackend(eventsToSend)
        } catch {
            // Re-queue events on failure
            eventQueue.append(contentsOf: eventsToSend)
            AppLogger.shared.error("Failed to send analytics: \(error)")
        }
    }

    private func sendToBackend(_ events: [AnalyticsEvent]) async throws {
        let payload = events.map { event in
            [
                "name": event.name,
                "parameters": event.parameters,
                "timestamp": event.timestamp.ISO8601Format(),
                "user_id": event.userId ?? "anonymous"
            ]
        }

        try await NetworkManager.shared.post("/analytics/events", body: ["events": payload])
    }

    private func startPeriodicFlush() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flush()
            }
        }
    }
}

// MARK: - Supporting Types

enum AuthMethod: String {
    case email
    case apple
    case google
    case spid
    case otp
}

enum VehicleAddMethod: String {
    case scan
    case manual
}

enum TyreAddMethod: String {
    case manual
    case photo
}

enum AnalysisType: String {
    case tread
    case surface
    case complete
}

enum PaywallTrigger: String {
    case featureGate = "feature_gate"
    case onboarding = "onboarding"
    case settings = "settings"
    case postAnalysis = "post_analysis"
}

enum NPSCategory: String {
    case promoter
    case passive
    case detractor
}
```

---

#### Phase 2: Integration (Settimane 3-4)

**2.1 Integrate Analytics in ViewModels**

Esempio di integrazione in un ViewModel esistente:

```swift
// Core/ViewModel/GarageViewModel.swift

class GarageViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var isLoading = false

    private let vehicleService: VehicleService

    func loadVehicles() async {
        isLoading = true
        let startTime = Date()

        defer {
            isLoading = false

            let duration = Date().timeIntervalSince(startTime)
            Task {
                await AnalyticsManager.shared.track(
                    .screenLoaded(
                        name: "GarageScreen",
                        duration: duration,
                        itemCount: vehicles.count
                    )
                )
            }
        }

        do {
            vehicles = try await vehicleService.fetchVehicles()
        } catch {
            // Error handling
        }
    }

    func selectVehicle(_ vehicle: Vehicle) {
        Task {
            await AnalyticsManager.shared.track(
                .vehicleViewed(vehicleId: vehicle.id)
            )
        }
    }
}
```

---

#### Phase 3: Backend & Dashboard (Settimane 5-6)

**3.1 Backend Analytics API**

```typescript
// Backend: /api/analytics/events
POST /analytics/events
{
  "events": [
    {
      "name": "vehicle_added",
      "parameters": {
        "method": "scan",
        "time_since_signup": 320
      },
      "timestamp": "2025-10-24T10:30:00Z",
      "user_id": "user_123"
    }
  ]
}

// Response
{
  "received": 1,
  "processed": 1
}
```

**3.2 Analytics Database Schema**

```sql
CREATE TABLE analytics_events (
    id UUID PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    session_id VARCHAR(100),
    parameters JSONB,
    timestamp TIMESTAMP NOT NULL,
    app_version VARCHAR(20),
    os_version VARCHAR(20),
    device_model VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_analytics_event_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_timestamp ON analytics_events(timestamp);

-- Aggregated tables for performance
CREATE TABLE daily_kpis (
    date DATE PRIMARY KEY,
    dau INT,
    new_users INT,
    sessions INT,
    avg_session_duration FLOAT,
    crash_free_rate FLOAT,
    -- ... more KPIs
    calculated_at TIMESTAMP DEFAULT NOW()
);
```

---

### 5.2 Data Collection Strategy

**Sampling Strategy:**
```swift
class AnalyticsManager {
    // Sample performance events (not every frame)
    func shouldSamplePerformanceEvent() -> Bool {
        return Double.random(in: 0...1) < 0.1 // 10% sampling
    }

    // Always track critical events
    func shouldTrackEvent(_ event: Event) -> Bool {
        switch event {
        case .userSignedUp, .subscriptionPurchased, .errorOccurred:
            return true // Always track
        case .fpsRecorded:
            return shouldSamplePerformanceEvent() // Sample
        default:
            return true
        }
    }
}
```

**Privacy Compliance:**
```swift
class AnalyticsManager {
    func track(_ event: Event) {
        // Check user consent
        guard hasUserConsent() else { return }

        // Anonymize PII
        var sanitizedEvent = event
        sanitizedEvent.parameters = sanitizePII(event.parameters)

        // Track
        eventQueue.append(sanitizedEvent)
    }

    private func sanitizePII(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized = parameters

        // Remove email, phone, etc.
        sanitized.removeValue(forKey: "email")
        sanitized.removeValue(forKey: "phone")

        // Hash license plates
        if let plate = sanitized["license_plate"] as? String {
            sanitized["license_plate_hash"] = plate.sha256Hash
            sanitized.removeValue(forKey: "license_plate")
        }

        return sanitized
    }
}
```

---

## 6. Dashboard Design

### 6.1 Executive Dashboard (CEO/Founders)

**Daily View:**
```
┌─────────────────────────────────────────────────────────┐
│ TyreVibes KPI Dashboard - 24 Ottobre 2025              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📊 Growth Metrics                                      │
│  ┌─────────────┬──────────┬──────────┬─────────────┐  │
│  │   Metric    │  Today   │   WoW    │    Target   │  │
│  ├─────────────┼──────────┼──────────┼─────────────┤  │
│  │ MAU         │  12,234  │  +12.4%  │  ✅ 12,000  │  │
│  │ DAU         │   1,203  │   +8.2%  │  ✅ 1,200   │  │
│  │ New Users   │      87  │  +15.3%  │  ✅ 80      │  │
│  │ Churn Rate  │   14.2%  │   -1.8%  │  ✅ <15%    │  │
│  └─────────────┴──────────┴──────────┴─────────────┘  │
│                                                         │
│  💰 Revenue Metrics                                     │
│  ┌─────────────┬──────────┬──────────┬─────────────┐  │
│  │   Metric    │   MTD    │   MoM    │    Target   │  │
│  ├─────────────┼──────────┼──────────┼─────────────┤  │
│  │ MRR         │  €9,543  │  +28.4%  │  ✅ €9,500  │  │
│  │ ARPU        │   €0.78  │   +2.6%  │  ✅ €0.76   │  │
│  │ Conv Rate   │    7.8%  │   +1.2%  │  ✅ 7.5%    │  │
│  │ LTV:CAC     │    4.8:1 │   +0.3   │  ❌ 5.0:1   │  │
│  └─────────────┴──────────┴──────────┴─────────────┘  │
│                                                         │
│  ⚡ Health Metrics                                      │
│  ┌─────────────┬──────────┬──────────┬─────────────┐  │
│  │   Metric    │  Current │  7-day   │    Target   │  │
│  ├─────────────┼──────────┼──────────┼─────────────┤  │
│  │ Crash-Free  │   99.2%  │   99.1%  │  ✅ >99%    │  │
│  │ App Rating  │  4.6 ⭐   │   4.5 ⭐  │  ✅ >4.5    │  │
│  │ NPS Score   │     +42  │     +38  │  ❌ >50     │  │
│  └─────────────┴──────────┴──────────┴─────────────┘  │
│                                                         │
│  📈 Growth Chart (Last 30 Days)                         │
│   3500 │                                         ╱╲    │
│        │                                      ╱╲╱  ╲   │
│   3000 │                                   ╱╲╱      │  │
│        │                                ╱╲╱          │  │
│   2500 │                             ╱╲╱             │  │
│        │                          ╱╲╱                │  │
│   2000 │                       ╱╲╱                   │  │
│        │────────────────────╱╲╱─────────────────────│  │
│        Oct 1              Oct 15              Oct 30 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 6.2 Product Dashboard (Product Manager)

**Weekly View:**
```
┌─────────────────────────────────────────────────────────┐
│ Product KPIs - Week 43, 2025                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🎯 Feature Adoption (WAU %)                            │
│  ┌────────────────────┬─────────┬─────────┬──────────┐ │
│  │ Feature            │ Current │  +/- WoW│  Target  │ │
│  ├────────────────────┼─────────┼─────────┼──────────┤ │
│  │ Plate Scan         │   68%   │  +4%    │  ✅ 65%  │ │
│  │ Tyre Analysis      │   52%   │  +6%    │  ✅ 50%  │ │
│  │ Maintenance Track  │   42%   │  +3%    │  ❌ 45%  │ │
│  │ Shop Browse        │   38%   │  -2%    │  ❌ 40%  │ │
│  │ Report Generation  │   24%   │  +1%    │  ❌ 25%  │ │
│  └────────────────────┴─────────┴─────────┴──────────┘ │
│                                                         │
│  📊 Funnel Analysis                                     │
│                                                         │
│  User Registration                                      │
│  ████████████████████ 100% (243 users)                 │
│           ↓                                             │
│  Complete Onboarding                                    │
│  ██████████████░░░░░░ 72% (175 users)                  │
│           ↓                                             │
│  Add First Vehicle                                      │
│  ████████████░░░░░░░░ 64% (156 users)                  │
│           ↓                                             │
│  Complete First Analysis                                │
│  ████████░░░░░░░░░░░░ 42% (102 users)                  │
│           ↓                                             │
│  Return Day 7                                           │
│  ██████░░░░░░░░░░░░░░ 31% (75 users)                   │
│                                                         │
│  🔴 Drop-off: Add Vehicle → Analysis (22%)              │
│  💡 Action: Improve analysis onboarding                 │
│                                                         │
│  ⏱️  Task Performance                                   │
│  ┌─────────────────────┬──────┬────────┬─────────────┐ │
│  │ Task                │  P50 │  P90   │   Target    │ │
│  ├─────────────────────┼──────┼────────┼─────────────┤ │
│  │ Add Vehicle (scan)  │ 1:18 │  2:24  │  ✅ <1:30   │ │
│  │ Add Vehicle (manual)│ 2:42 │  4:12  │  ❌ <2:30   │ │
│  │ Tyre Analysis       │ 0:38 │  1:02  │  ✅ <0:45   │ │
│  │ Generate Report     │ 0:28 │  0:52  │  ✅ <0:30   │ │
│  └─────────────────────┴──────┴────────┴─────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 6.3 Engineering Dashboard (Tech Lead)

**Real-time View:**
```
┌─────────────────────────────────────────────────────────┐
│ Engineering KPIs - Live                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ⚡ Performance Metrics                                  │
│  ┌─────────────────┬─────┬─────┬─────┬──────────────┐  │
│  │ Metric          │ P50 │ P90 │ P99 │   Status     │  │
│  ├─────────────────┼─────┼─────┼─────┼──────────────┤  │
│  │ App Launch      │ 1.8s│ 2.4s│ 3.2s│  ✅ Healthy  │  │
│  │ Plate Detection │ 1.5s│ 2.8s│ 4.2s│  ⚠️  Slow    │  │
│  │ Tyre Analysis   │ 3.2s│ 5.1s│ 7.8s│  ✅ Healthy  │  │
│  │ API /vehicles   │ 280ms│480ms│920ms│  ✅ Healthy │  │
│  └─────────────────┴─────┴─────┴─────┴──────────────┘  │
│                                                         │
│  🐛 Quality Metrics (Last 7 Days)                       │
│  ┌──────────────────┬──────────┬──────────┬──────────┐ │
│  │ Metric           │  Current │   Trend  │  Target  │ │
│  ├──────────────────┼──────────┼──────────┼──────────┤ │
│  │ Crash-Free Rate  │  99.2%   │    ↑     │ ✅ >99%  │ │
│  │ Error Rate       │   1.4%   │    ↓     │ ✅ <2%   │ │
│  │ API Success      │  98.8%   │    →     │ ❌ >99%  │ │
│  │ Test Coverage    │  68%     │    ↑     │ ❌ >70%  │ │
│  └──────────────────┴──────────┴──────────┴──────────┘ │
│                                                         │
│  📊 Error Distribution (Last 24h)                       │
│  ┌──────────────────────────────────────────┐          │
│  │ Network Errors      ████████░░░░ 42%     │          │
│  │ ML Model Failures   ██████░░░░░░ 28%     │          │
│  │ Image Processing    ████░░░░░░░░ 18%     │          │
│  │ Data Validation     ██░░░░░░░░░░  9%     │          │
│  │ Other               █░░░░░░░░░░░  3%     │          │
│  └──────────────────────────────────────────┘          │
│                                                         │
│  🔥 Critical Alerts                                     │
│  ⚠️  Plate detection P99 above threshold (4.2s > 4.0s) │
│  ⚠️  API success rate below target (98.8% < 99%)       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Reporting Cadence

### 7.1 Real-time Monitoring

**Always On (24/7):**
- Crash rate
- API success rate
- Critical errors
- Payment processing

**Alerting Thresholds:**
```swift
struct AlertThreshold {
    static let crashFreeRate = 0.99      // Alert if < 99%
    static let apiSuccessRate = 0.98     // Alert if < 98%
    static let errorRate = 0.02          // Alert if > 2%
    static let p99LaunchTime = 5.0       // Alert if > 5s
}
```

---

### 7.2 Daily Reports

**Delivered:** 9:00 AM via Email + Slack

**Recipients:** Engineering Lead, Product Manager, CEO

**Content:**
- DAU, MAU, retention rates
- New user sign-ups
- Crash-free rate
- Critical errors (if any)
- Top 5 features used
- Revenue metrics (MRR, conversions)

---

### 7.3 Weekly Reports

**Delivered:** Monday 10:00 AM

**Recipients:** All stakeholders

**Content:**
- Week-over-week growth
- Feature adoption trends
- Funnel analysis
- Task completion metrics
- User feedback summary (NPS, ratings)
- Engineering health (test coverage, bug density)
- Action items for next week

---

### 7.4 Monthly Business Reviews

**Delivered:** First Monday of month

**Recipients:** Leadership team

**Content:**
- Comprehensive KPI review vs targets
- Cohort retention analysis
- Revenue breakdown
- Feature performance deep-dive
- Competitive analysis
- Roadmap impact assessment
- Strategic recommendations

---

## 8. Alert Thresholds

### 8.1 Critical Alerts (Immediate Action)

**Trigger:** Instant notification via PagerDuty/Slack

| Metric | Threshold | Action |
|--------|-----------|--------|
| Crash-Free Rate | <98% | Investigate immediately |
| API Success Rate | <97% | Check backend health |
| Payment Processing | <99% | Revenue loss, urgent fix |
| Authentication | <99% | User acquisition blocked |

---

### 8.2 Warning Alerts (24h Response)

**Trigger:** Email + Slack notification

| Metric | Threshold | Action |
|--------|-----------|--------|
| Crash-Free Rate | 98-99% | Monitor, investigate if persists |
| Error Rate | >3% | Review error logs |
| P99 Launch Time | >5s | Performance investigation |
| DAU Drop | >15% WoW | User research |

---

### 8.3 Info Alerts (Weekly Review)

**Trigger:** Included in weekly report

| Metric | Threshold | Action |
|--------|-----------|--------|
| Feature Adoption | <50% of target | UX review |
| Churn Rate | >20% | User interviews |
| NPS Score | <30 | Product improvements |

---

## 9. Next Steps

### Immediate Actions (Week 1-2)

1. ✅ **Approve KPI Framework** - Review and sign-off by leadership
2. ✅ **Implement AnalyticsManager** - Core infrastructure (iOS)
3. ✅ **Setup Backend Analytics API** - Event ingestion endpoint
4. ✅ **Create Analytics Database** - PostgreSQL schema

### Short-term (Week 3-6)

5. ✅ **Integrate Analytics** - Add tracking to all ViewModels
6. ✅ **Build Dashboards** - Grafana/Metabase setup
7. ✅ **Setup Alerts** - PagerDuty integration
8. ✅ **Document Playbooks** - Alert response procedures

### Medium-term (Week 7-12)

9. ✅ **A/B Testing Framework** - Experimentation platform
10. ✅ **User Surveys** - NPS, CSAT surveys
11. ✅ **Cohort Analysis** - Automated cohort reports
12. ✅ **Predictive Analytics** - ML models for churn prediction

---

## 10. Success Criteria

**3 Months:**
- ✅ All KPIs tracked and dashboarded
- ✅ Weekly reports automated
- ✅ Alert system operational
- ✅ 50% of targets achieved

**6 Months:**
- ✅ 70% of targets achieved
- ✅ A/B testing running
- ✅ Data-driven decision making established
- ✅ Predictive models in production

**12 Months:**
- ✅ 85%+ of targets achieved
- ✅ World-class metrics (>4.7⭐ rating, >50 NPS)
- ✅ Profitable unit economics (LTV:CAC >5:1)
- ✅ Sustainable growth (>40% MoM)

---

**Document Owner:** Product Team
**Last Updated:** 24 Ottobre 2025
**Next Review:** 24 Novembre 2025

---

*🤖 Generated with [Claude Code](https://claude.com/claude-code)*
