import SwiftUI
import WebKit

/// WebView per l'autenticazione SPID tramite ACI
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

                VStack(spacing: 0) {
                    // Progress bar
                    if coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
                    }

                    // WebView
                    SPIDWebViewRepresentable(
                        loginURL: loginURL,
                        coordinator: coordinator
                    )
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
    @ObservedObject var coordinator: WebViewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Imposta user agent per mobile
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        coordinator.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Carica l'URL di autenticazione SPID solo se non è già stato caricato
        if webView.url == nil {
            print("🌐 [ACISPIDWebView] Caricamento URL: \(loginURL.absoluteString)")
            let request = URLRequest(url: loginURL)
            webView.load(request)
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
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

    weak var webView: WKWebView? {
        didSet {
            Task { @MainActor in
                self.updateNavigationState()
            }
        }
    }

    private let successPatterns = [
        "bollo.aci.it",
        "loginSpid",
        "AreaRiservata"
    ]

    // URL patterns che indicano errore
    private let errorPatterns = [
        "error",
        "cancel",
        "denied",
        "auth_error"
    ]

    private var didRequestVehicle = false

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
        if let currentURL = webView.url {
            print("📍 [ACISPIDWebView] Pagina caricata: \(currentURL.absoluteString)")
        }

        checkForAuthResponse(in: webView)
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

        if !didRequestVehicle, successPatterns.contains(where: { urlString.contains($0) }) {
            didRequestVehicle = true
            requestVehicleData()
        }

        // Intercetta URL di errore
        if errorPatterns.contains(where: { urlString.contains($0) }) {
            print("❌ [ACISPIDWebView] URL di errore intercettato")
            Task { @MainActor in
                self.authError = ACIAuthError.authenticationFailed
            }
            decisionHandler(.cancel)
            return
        }

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
    private func checkForAuthResponse(in webView: WKWebView) {
        // Script JavaScript per estrarre il contenuto della pagina
        let script = """
        (function() {
            function extractJSON(fromNode) {
                if (!fromNode) { return null; }
                var candidate = (fromNode.innerText || fromNode.textContent || "").trim();
                if (!candidate) { return null; }
                if (candidate.startsWith("{") || candidate.startsWith("[")) {
                    try {
                        JSON.parse(candidate);
                        return candidate;
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

            if let jsonString = result as? String, self.vehicleResponse == nil {
                print("✅ [ACISPIDWebView] JSON trovato nella risposta!")
                print("📄 [ACISPIDWebView] JSON: \(jsonString)")

                guard let data = jsonString.data(using: .utf8) else {
                    print("❌ [ACISPIDWebView] Impossibile ottenere dati UTF-8 dal JSON")
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let response = try decoder.decode(BolloAPIResponse.self, from: data)
                    Task { @MainActor in
                        self.vehicleResponse = response
                        self.authSuccess = true
                        self.didRequestVehicle = true
                    }
                } catch {
                    print("❌ [ACISPIDWebView] Errore decoding JSON: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.authError = ACIAuthError.decodingError
                    }
                }
            }
        }
    }

    private func requestVehicleData() {
        guard let webView = webView else { return }

        getCookies { cookies in
            ACISPIDAuthService.shared.fetchVehicleData(using: cookies) { result in
                switch result {
                case .success(let response):
                    Task { @MainActor in
                        self.vehicleResponse = response
                        self.authSuccess = true
                    }
                case .failure(let error):
                    Task { @MainActor in
                        self.authError = error
                        self.didRequestVehicle = false
                    }
                }
            }
        }
    }

    /// Recupera i cookie quando l'autenticazione è completata
    func getCookies(completion: @escaping ([HTTPCookie]) -> Void) {
        guard let webView = webView else {
            completion([])
            return
        }

        let dataStore = webView.configuration.websiteDataStore
        let cookieStore = dataStore.httpCookieStore

        cookieStore.getAllCookies { cookies in
            print("🍪 [ACISPIDWebView] Recupero cookie: \(cookies.count) totali")

            // Filtra i cookie rilevanti per ACI/Bollonet
            let relevantCookies = cookies.filter { cookie in
                let domain = cookie.domain.lowercased()
                return domain.contains("aci.it")
            }

            print("✅ [ACISPIDWebView] Cookie ACI trovati: \(relevantCookies.count)")
            for cookie in relevantCookies {
                print("🍪 [ACISPIDWebView] Cookie: \(cookie.name) = \(cookie.value.prefix(20))...")
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
