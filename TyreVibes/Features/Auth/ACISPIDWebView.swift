import SwiftUI
import WebKit

/// WebView per l'autenticazione SPID tramite ACI
///
/// NOTA IMPORTANTE: La WebView deve rimanere sempre attiva nella view hierarchy,
/// anche quando viene nascosta all'utente tramite overlay. Questo perché il flusso
/// di autenticazione richiede navigazioni in background (genNotAuth → vehicle) dopo
/// il completamento del login SPID. Rimuovere la WebView dalla hierarchy causerebbe
/// il blocco di queste navigazioni.
struct ACISPIDWebView: View {
    let loginURL: URL
    let onVehicleData: (BolloAPIResponse) -> Void
    let onAuthFailure: (Error) -> Void
    let onDismiss: () -> Void

    @StateObject private var coordinator = WebViewCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                // LAYER 1: WebView sempre presente e attiva
                // Non viene mai rimossa dalla view hierarchy, così può navigare liberamente
                VStack(spacing: 0) {
                    // Progress bar durante il caricamento
                    if coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
                    }

                    // WebView sempre attiva
                    SPIDWebViewRepresentable(
                        loginURL: loginURL,
                        onVehicleData: onVehicleData,
                        onAuthFailure: onAuthFailure
                    )
                    .environmentObject(coordinator)
                }

                // LAYER 2: Overlay di loading sopra la WebView
                // Mostrato dopo il completamento del login SPID per nascondere le navigazioni API
                if coordinator.hideWebView {
                    ZStack {
                        // Background opaco per coprire completamente la WebView
                        Color.customBackgroundColor
                            .ignoresSafeArea()

                        // Loading indicator e testi
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Recupero dati veicolo...")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Text("Attendi qualche secondo")
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))

                            // Pulsante per annullare
                            Button(action: {
                                print("⚠️ [ACISPIDWebView] Utente ha annullato il recupero dati")
                                coordinator.authError = ACIAuthError.authenticationCancelled
                                onDismiss()
                            }) {
                                Text("Annulla")
                                    .font(.customFont(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationTitle("Autenticazione SPID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        ACISPIDAuthService.shared.handleAuthenticationFailure(error: .authenticationCancelled)
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if coordinator.canGoBack {
                        Button(action: {
                            coordinator.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(coordinator.$vehicleResponse.compactMap { $0 }) { response in
            onVehicleData(response)
        }
        .onReceive(coordinator.$authError) { error in
            if let error = error {
                onAuthFailure(error)
            }
        }
    }
}

// MARK: - WebView Representable

struct SPIDWebViewRepresentable: UIViewRepresentable {
    let loginURL: URL
    let onVehicleData: (BolloAPIResponse) -> Void
    let onAuthFailure: (Error) -> Void

    @EnvironmentObject var coordinator: WebViewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        print("🏗️ [ACISPIDWebView] makeUIView chiamato")

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        // Abilita media playback e altre features
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Fix: Usa background bianco invece di trasparente
        webView.isOpaque = true
        webView.backgroundColor = .white

        // Imposta user agent per mobile
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        // Assegna la webView al coordinator
        context.coordinator.webView = webView
        context.coordinator.onVehicleData = onVehicleData
        context.coordinator.onAuthFailure = onAuthFailure

        // Carica l'URL dopo un brevissimo delay per assicurare che tutto sia configurato
        DispatchQueue.main.async {
            print("🌐 [ACISPIDWebView] Caricamento URL: \(loginURL.absoluteString)")
            let request = URLRequest(url: loginURL)
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Non fare nulla qui - il caricamento avviene solo in makeUIView
        print("🔄 [ACISPIDWebView] updateUIView chiamato")
    }

    func makeCoordinator() -> WebViewCoordinator {
        print("🤝 [ACISPIDWebView] makeCoordinator chiamato - usando coordinator da environment")
        return coordinator
    }
}

// MARK: - WebView Coordinator

@MainActor
class WebViewCoordinator: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var authSuccess = false
    @Published var authError: Error?
    @Published var vehicleResponse: BolloAPIResponse?
    @Published var hideWebView = false  // Flag per nascondere la WebView dopo il login SPID

    var onVehicleData: ((BolloAPIResponse) -> Void)?
    var onAuthFailure: ((Error) -> Void)?

    weak var webView: WKWebView? {
        didSet {
            Task { @MainActor in
                self.updateNavigationState()
            }
        }
    }

    // Pattern che indica il completamento dell'autenticazione SPID su IAM ACI
    private let authCompletedPattern = "iam.aci.it/auth/realms/Cittadini/broker/after-post-broker-login"

    // URL patterns che indicano errore
    private let errorPatterns = [
        "error",
        "cancel",
        "denied",
        "auth_error"
    ]

    private var didNavigateToVehicleEndpoint = false  // Flag per tracciare il completamento dell'auth SPID
    private var authCompleted = false  // Flag per bloccare navigazioni dopo il successo

    func goBack() {
        webView?.goBack()
        Task { @MainActor in self.updateNavigationState() }
    }

    private func updateNavigationState() {
        // Ensure this runs on the main actor and publish asynchronously to avoid view-update conflicts
        let canGoBackNow = webView?.canGoBack ?? false
        if canGoBack != canGoBackNow {
            // Defer publication to the next runloop to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.canGoBack = canGoBackNow
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Log dettagliato per capire quale pagina sta per caricare
        if let url = webView.url {
            print("⏳ [ACISPIDWebView] Inizio caricamento: \(url.absoluteString)")
            if url.absoluteString == "about:blank" {
                print("⚠️ [ACISPIDWebView] ATTENZIONE: Tentativo di caricamento di about:blank")
                print("   - authCompleted: \(authCompleted)")
                print("   - Se authCompleted=true, questa navigazione sarà bloccata")
            }
        }

        Task { @MainActor in
            self.isLoading = true
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.isLoading = false
            self.updateNavigationState()
        }

        // Stampa l'URL finale caricato
        guard let currentURL = webView.url else {
            print("⚠️ [ACISPIDWebView] Nessun URL dopo il caricamento")
            return
        }

        let urlString = currentURL.absoluteString
        print("📍 [ACISPIDWebView] Pagina caricata: \(urlString)")

        // Log speciale per about:blank
        if urlString == "about:blank" {
            print("⚠️ [ACISPIDWebView] RILEVATO: Caricamento completato di about:blank")
            print("   - authCompleted: \(authCompleted)")
            print("   - Questa pagina dovrebbe essere stata bloccata se authCompleted = true")
        }

        // DEBUG: Log dello stato dei flag
        print("🔍 [DEBUG] Flag Status:")
        print("   - didNavigateToVehicleEndpoint: \(didNavigateToVehicleEndpoint)")
        print("   - authCompleted: \(authCompleted)")

        // STRATEGIA: Dopo l'autenticazione SPID, nascondi la WebView e naviga all'endpoint vehicle
        // La WebView estrarrà il JSON dalla pagina quando sarà caricata
        if !didNavigateToVehicleEndpoint && urlString.contains(authCompletedPattern) {
            print("✅ [ACISPIDWebView] Autenticazione SPID completata su IAM ACI!")
            print("📋 [ACISPIDWebView] Navigazione all'endpoint vehicle...")

            // Marca che abbiamo completato l'autenticazione SPID
            didNavigateToVehicleEndpoint = true

            // Nascondi la WebView per non mostrare la pagina di caricamento all'utente
            Task { @MainActor in
                self.hideWebView = true
            }

            // Aspetta 1 secondo per stabilizzare i cookie, poi naviga direttamente alla pagina di login ACI
            // che reindirizza automaticamente all'endpoint vehicle con il parametro purl
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, let webView = self.webView else {
                    print("❌ [ACISPIDWebView] WebView non disponibile per navigare a vehicle")
                    return
                }

                // Naviga al login ACI che gestisce automaticamente il redirect a vehicle
                // Questo approccio permette alla pagina web di gestire reCAPTCHA tramite JavaScript
                var components = URLComponents(string: "https://login.aci.it/index.php/")
                components?.queryItems = [
                    URLQueryItem(name: "do", value: "loginSpid"),
                    URLQueryItem(name: "application_key", value: "bollonet"),
                    URLQueryItem(name: "purl", value: "https://bollo.aci.it/api/v2/vehicle")
                ]

                guard let loginURL = components?.url else {
                    print("❌ [ACISPIDWebView] Impossibile costruire URL di login")
                    return
                }

                print("🌐 [ACISPIDWebView] Navigazione a: \(loginURL.absoluteString)")
                print("📋 [ACISPIDWebView] Questo reindirizza automaticamente a vehicle con i cookie di sessione")

                DispatchQueue.main.async {
                    webView.load(URLRequest(url: loginURL))
                }
            }
            return
        }

        // Controlla se la pagina contiene un JSON di risposta dall'API vehicle
        // Questo viene chiamato per ogni pagina caricata, incluso l'endpoint vehicle
        if didNavigateToVehicleEndpoint && !authCompleted {
            checkForAuthResponse(in: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            print("❌ [ACISPIDWebView] Navigation failed: \(error.localizedDescription)")
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let urlString = url.absoluteString
        print("🔍 [ACISPIDWebView] Navigazione a: \(urlString)")

        // Intercetta SOLO URL di errore
        if errorPatterns.contains(where: { urlString.contains($0) }) {
            print("❌ [ACISPIDWebView] URL di errore intercettato")
            Task { @MainActor in
                self.authError = ACIAuthError.authenticationFailed
            }
            decisionHandler(.cancel)
            return
        }

        // Permetti TUTTE le altre navigazioni
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let url = navigationResponse.response.url {
            let urlString = url.absoluteString
            print("📥 [ACISPIDWebView] Risposta da: \(urlString)")

            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("📡 [ACISPIDWebView] Status code: \(httpResponse.statusCode)")
            }
        }

        decisionHandler(.allow)
    }

    // MARK: - Helper Methods

    /// Controlla se la pagina contiene un JSON di risposta dall'autenticazione
    /// NOTA: Questo metodo è mantenuto come fallback, ma normalmente non viene più usato
    /// perché usiamo URLSession direttamente invece della WebView per le chiamate API
    private func checkForAuthResponse(in webView: WKWebView) {
        // Se l'autenticazione è già completata, non fare nulla
        if authCompleted {
            print("⏭️ [ACISPIDWebView] Autenticazione già completata, skip checkForAuthResponse")
            return
        }

        // Script JavaScript per estrarre il contenuto della pagina
        let script = """
        (function() {
            function extractJSON(fromNode) {
                if (!fromNode) { return null; }
                var candidate = (fromNode.innerText || fromNode.textContent || "").trim();
                if (!candidate) { return null; }
                if (candidate.startsWith("{") || candidate.startsWith("[")) {
                    try {
                        var parsed = JSON.parse(candidate);
                        // Verifica che contenga le chiavi che ci aspettiamo
                        if (parsed.codiceEsito !== undefined || parsed.veicoli !== undefined) {
                            return candidate;
                        }
                    } catch (e) {
                        return null;
                    }
                }
                return null;
            }

            // Prova dal body, dal primo <pre> e poi dall'intero documento
            var body = document.body;
            var jsonFromBody = extractJSON(body);
            if (jsonFromBody) { return jsonFromBody; }

            var pre = document.querySelector("pre");
            var jsonFromPre = extractJSON(pre);
            if (jsonFromPre) { return jsonFromPre; }

            var root = document.documentElement;
            return extractJSON(root);
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [ACISPIDWebView] Errore valutazione JS: \(error.localizedDescription)")
                return
            }

            if let jsonString = result as? String, !jsonString.isEmpty {
                print("✅ [ACISPIDWebView] JSON valido trovato nella pagina!")
                print("📄 [ACISPIDWebView] JSON completo ricevuto:")
                print("=" + String(repeating: "=", count: 80))
                print(jsonString)
                print("=" + String(repeating: "=", count: 80))

                guard let data = jsonString.data(using: .utf8) else {
                    print("❌ [ACISPIDWebView] Impossibile ottenere dati UTF-8 dal JSON")
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let response = try decoder.decode(BolloAPIResponse.self, from: data)
                    print("✅ [ACISPIDWebView] JSON decodificato con successo!")
                    print("📊 [ACISPIDWebView] Codice Esito: \(response.codiceEsito)")
                    print("📊 [ACISPIDWebView] Descrizione Esito: \(response.descrizioneEsito)")
                    print("🚗 [ACISPIDWebView] Veicoli trovati: \(response.veicoli?.count ?? 0)")

                    // Log dettagliato di ogni veicolo
                    if let veicoli = response.veicoli {
                        for (index, veicolo) in veicoli.enumerated() {
                            print("\n🚙 [ACISPIDWebView] === VEICOLO #\(index + 1) ===")
                            print("   Targa: \(veicolo.targa)")
                            print("   Fabbrica: \(veicolo.fabbrica ?? "N/A")")
                            print("   Tipo: \(veicolo.tipo ?? "N/A")")

                            if let bollo = veicolo.bollo {
                                print("   📋 Bollo:")
                                print("      Tipo Veicolo: \(bollo.tipoVeicolo)")
                                print("      Data Decorrenza: \(bollo.dataDecorrenza ?? "N/A")")
                                print("      Data Scadenza: \(bollo.dataScadenza ?? "N/A")")
                                print("      Data Termine Pagamento: \(bollo.dataTerminePagamento ?? "N/A")")
                                print("      Importo Dovuto: €\(bollo.importoDovuto ?? 0.0)")
                                print("      Importo Versato: €\(bollo.importoVersato ?? 0.0)")
                                print("      Saldo: €\(bollo.saldo ?? 0.0)")
                                print("      Stato: \(bollo.stato ?? "N/A")")
                                print("      Regione: \(bollo.regione ?? 0)")
                            }

                            if let storico = veicolo.storicoPagamenti, !storico.isEmpty {
                                print("   📜 Storico Pagamenti: \(storico.count) voci")
                            }
                        }
                    }
                    print("\n" + String(repeating: "=", count: 80))

                    // IMPORTANTE: Marca l'autenticazione come completata per bloccare navigazioni successive
                    self.authCompleted = true
                    print("🎯 [ACISPIDWebView] Autenticazione completata - ulteriori navigazioni verranno bloccate")

                    Task { @MainActor in
                        self.vehicleResponse = response
                        self.authSuccess = true

                        // Chiama il callback
                        self.onVehicleData?(response)
                    }
                } catch {
                    print("❌ [ACISPIDWebView] Errore decoding JSON: \(error.localizedDescription)")
                    print("❌ [ACISPIDWebView] JSON che ha causato l'errore:")
                    print(jsonString)

                    Task { @MainActor in
                        self.authError = ACIAuthError.decodingError
                        self.onAuthFailure?(ACIAuthError.decodingError)
                    }
                }
            } else {
                print("⏭️ [ACISPIDWebView] Nessun JSON trovato in questa pagina, continua navigazione...")
            }
        }
    }

    private func requestVehicleData() {
        guard webView != nil else {
            print("❌ [ACISPIDWebView] WebView non disponibile per il recupero cookie")
            return
        }

        print("🚀 [ACISPIDWebView] Inizio recupero dati veicolo...")

        getCookies { [weak self] cookies in
            guard let self = self else { return }

            // Verifica che ci siano cookie validi
            if cookies.isEmpty {
                print("⚠️ [ACISPIDWebView] Nessun cookie ACI trovato!")
                print("⚠️ [ACISPIDWebView] L'autenticazione potrebbe non essere completa")
                return
            }

            print("✅ [ACISPIDWebView] Cookie ACI trovati: \(cookies.count)")
            print("🌐 [ACISPIDWebView] Chiamata API vehicle in corso...")

            ACISPIDAuthService.shared.fetchVehicleData(using: cookies) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let response):
                    print("✅ [ACISPIDWebView] Dati veicolo ricevuti con successo!")
                    print("🚗 [ACISPIDWebView] Veicoli trovati: \(response.veicoli?.count ?? 0)")

                    Task { @MainActor in
                        self.vehicleResponse = response
                        self.authSuccess = true

                        // Chiama anche i callback se disponibili
                        self.onVehicleData?(response)
                    }

                case .failure(let error):
                    print("❌ [ACISPIDWebView] Errore recupero dati veicolo: \(error.localizedDescription)")

                    Task { @MainActor in
                        self.authError = error

                        // Chiama anche il callback di errore
                        self.onAuthFailure?(error)
                    }
                }
            }
        }
    }

    /// Recupera i cookie quando l'autenticazione è completata
    func getCookies(completion: @escaping ([HTTPCookie]) -> Void) {
        guard let webView = webView else {
            print("❌ [ACISPIDWebView] WebView non disponibile per getCookies")
            completion([])
            return
        }

        let dataStore = webView.configuration.websiteDataStore
        let cookieStore = dataStore.httpCookieStore

        print("🔍 [ACISPIDWebView] Recupero cookie dal dataStore...")

        cookieStore.getAllCookies { cookies in
            print("📊 [ACISPIDWebView] Cookie totali recuperati: \(cookies.count)")

            // Filtra i cookie rilevanti per ACI/Bollonet
            let relevantCookies = cookies.filter { cookie in
                let domain = cookie.domain.lowercased()
                return domain.contains("aci.it")
            }

            // Verifica cookie specifici per bollo.aci.it
            let bolloCookies = relevantCookies.filter { $0.domain.contains("bollo.aci.it") }
            let iamCookies = relevantCookies.filter { $0.domain.contains("iam.aci.it") }

            print("📋 [ACISPIDWebView] Cookie breakdown:")
            print("   - Cookie totali ACI: \(relevantCookies.count)")
            print("   - Cookie bollo.aci.it: \(bolloCookies.count)")
            print("   - Cookie iam.aci.it: \(iamCookies.count)")

            if relevantCookies.isEmpty {
                print("⚠️ [ACISPIDWebView] Nessun cookie aci.it trovato!")
                print("📋 [ACISPIDWebView] Domini disponibili:")
                let uniqueDomains = Set(cookies.map { $0.domain })
                for domain in uniqueDomains.prefix(10) {
                    print("   - \(domain)")
                }
            } else {
                print("✅ [ACISPIDWebView] Cookie ACI trovati: \(relevantCookies.count)")

                // Log cookie importanti per il debug
                let importantCookieNames = ["KEYCLOAK_SESSION", "KEYCLOAK_SESSION_LEGACY", "AUTH_SESSION_ID", "JSESSIONID"]
                for cookie in relevantCookies {
                    let isImportant = importantCookieNames.contains(cookie.name)
                    let prefix = isImportant ? "🔑" : "🍪"
                    print("\(prefix) [ACISPIDWebView]   \(cookie.name)")
                    print("      Domain: \(cookie.domain)")
                    print("      Path: \(cookie.path)")
                    print("      Value: \(cookie.value.prefix(30))...")
                    print("      Secure: \(cookie.isSecure), HttpOnly: \(cookie.isHTTPOnly)")
                    print("      Expires: \(cookie.expiresDate?.description ?? "session")")
                }
            }

            completion(relevantCookies)
        }
    }
}

// MARK: - Preview

#Preview {
    if let url = URL(string: "https://login.aci.it/index.php/?do=loginSpidMobile&application_key=bollonet&purl=https%3A%2F%2Fbollo.aci.it%2Fapi%2Fv2%2Fvehicle") {
        ACISPIDWebView(
            loginURL: url,
            onVehicleData: { response in
                print("Auth success: \(response.veicoli?.count ?? 0) veicoli")
            },
            onAuthFailure: { error in
                print("Auth failure: \(error)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
}
