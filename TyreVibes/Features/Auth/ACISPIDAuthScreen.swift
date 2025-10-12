import SwiftUI

/// Screen per gestire l'autenticazione SPID tramite ACI
struct ACISPIDAuthScreen: View {
    @StateObject private var authService = ACISPIDAuthService.shared
    @State private var showWebView = false
    @State private var loginURL: URL?
    @State private var vehicleResponse: BolloAPIResponse?
    @State private var showErrorBanner = false
    @State private var errorBannerMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                VStack(spacing: 30) {
                    // Logo o icona SPID
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.top, 50)

                    VStack(spacing: 12) {
                        Text("Autenticazione SPID")
                            .font(.customFont(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Accedi con le tue credenziali SPID per continuare")
                            .font(.customFont(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Spacer()

                    // Stato dell'autenticazione
                    if let response = vehicleResponse {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.green)

                            Text("Autenticazione Completata!")
                                .font(.customFont(size: 20, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Dati veicolo recuperati correttamente")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            if let veicoli = response.veicoli, !veicoli.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Veicoli trovati: \(veicoli.count)")
                                        .font(.customFont(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))

                                    ForEach(veicoli.prefix(3), id: \.targa) { veicolo in
                                        HStack {
                                            Text(veicolo.targa.uppercased())
                                                .font(.customFont(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(veicolo.bollo?.stato ?? "N/A")
                                                .font(.customFont(size: 11, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.2))
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.2))
                        )
                        .padding(.horizontal, 24)
                    } else if authService.isAuthenticating {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Autenticazione in corso...")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Pulsante di autenticazione
                    Button(action: {
                        startAuthentication()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20))

                            Text("Accedi con SPID")
                                .font(.customFont(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(authService.isAuthenticating || vehicleResponse != nil)
                    .opacity(authService.isAuthenticating || vehicleResponse != nil ? 0.5 : 1.0)
                    .padding(.horizontal, 24)

                    // Pulsante di reset (solo se autenticato)
                    if vehicleResponse != nil {
                        Button(action: {
                            resetAuthentication()
                        }) {
                            Text("Esci")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .overlay(alignment: .top) {
                if showErrorBanner {
                    ErrorBannerView(text: errorBannerMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .fullScreenCover(item: Binding(
                get: { showWebView && loginURL != nil ? loginURL : nil },
                set: { if $0 == nil { showWebView = false } }
            )) { url in
                ACISPIDWebView(
                    loginURL: url,
                    onVehicleData: { response in
                        handleAuthSuccess(response: response)
                    },
                    onAuthFailure: { error in
                        handleAuthFailure(error: error)
                    },
                    onDismiss: {
                        showWebView = false
                        authService.isAuthenticating = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
}

private struct ErrorBannerView: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))

            Text(text)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.red.opacity(0.85), .orange.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Methods

    private func startAuthentication() {
        authService.startAuthentication { result in
            switch result {
            case .success(let url):
                print("✅ [ACISPIDAuthScreen] URL di login ricevuto: \(url.absoluteString)")
                // IMPORTANTE: Imposta l'URL e mostra la WebView in un'unica transazione atomica
                // per evitare race conditions
                DispatchQueue.main.async { [weak authService] in
                    guard authService != nil else { return }
                    self.loginURL = url
                    // Aspetta che l'URL sia stato effettivamente settato prima di mostrare la WebView
                    DispatchQueue.main.async {
                        self.showWebView = true
                    }
                }

            case .failure(let error):
                print("❌ [ACISPIDAuthScreen] Errore: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorBannerMessage = error.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.showErrorBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showErrorBanner = false
                        }
                    }
                }
            }
        }
    }

    private func handleAuthSuccess(response: BolloAPIResponse) {
        print("🎉 [ACISPIDAuthScreen] Autenticazione completata con successo")
        print("🚗 [ACISPIDAuthScreen] Risposta vehicle ricevuta con \(response.veicoli?.count ?? 0) veicoli")

        Task { @MainActor in
            vehicleResponse = response
            showErrorBanner = false
            showWebView = false

            authService.handleVehicleResponse(response)

            dismiss()
        }
    }

    private func handleAuthFailure(error: Error) {
        print("❌ [ACISPIDAuthScreen] Autenticazione fallita: \(error.localizedDescription)")

        Task { @MainActor in
            errorBannerMessage = error.localizedDescription
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showErrorBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showErrorBanner = false
                }
            }
            showWebView = false
            authService.isAuthenticating = false
        }
    }

    private func resetAuthentication() {
        vehicleResponse = nil
        loginURL = nil
        authService.reset()
    }
}

// MARK: - Extensions

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Preview

#Preview {
    ACISPIDAuthScreen()
}
