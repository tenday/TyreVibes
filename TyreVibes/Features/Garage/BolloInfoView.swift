import SwiftUI

/// Vista per le informazioni sul bollo auto (tassa di circolazione)
struct BolloInfoView: View {
    let vehicle: VehicleResponse
    @State private var isAuthenticated = false
    @State private var showAuthScreen = false
    @State private var bolloInfo: BolloData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @ObservedObject private var authService = ACISPIDAuthService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            if isAuthenticated {
                // Utente autenticato - mostra info bollo
                if let bollo = bolloInfo {
                    bolloDetailsView(bollo)
                } else {
                    // Mostra pulsante per caricare info
                    loadBolloButton
                }
            } else {
                // Utente non autenticato - mostra pulsante login SPID
                spidLoginPrompt
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding()
        .cornerRadius(14)
        .onAppear {
            checkAuthenticationStatus()
        }
        .fullScreenCover(isPresented: $showAuthScreen) {
            ACISPIDAuthScreen()
        }
        .onChange(of: showAuthScreen) { _, newValue in
            if !newValue {
                // Quando la schermata di auth si chiude, ricontrolla lo stato
                checkAuthenticationStatus()
            }
        }
    }

    // MARK: - Subviews

    private var spidLoginPrompt: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Accedi con SPID per visualizzare le informazioni sul bollo")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }

            Button(action: {
                showAuthScreen = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.system(size: 16))
                    Text("Accedi con SPID")
                        .font(.customFont(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(.vertical, 8)
    }

    private var loadBolloButton: some View {
        Button(action: {
            loadBolloInfo()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
                Text("Carica informazioni bollo")
                    .font(.customFont(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }

    private func bolloDetailsView(_ bollo: BolloData) -> some View {
        VStack(spacing: 12) {
            // Stato pagamento
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stato Pagamento")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(bollo.isPaid ? "Pagato" : "Da Pagare")
                        .font(.customFont(size: 16, weight: .bold))
                        .foregroundColor(bollo.isPaid ? .green : .orange)
                }
                Spacer()
                Image(systemName: bollo.isPaid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(bollo.isPaid ? .green : .orange)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .cornerRadius(10)

            // Importo
            if let amount = bollo.amount {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Importo")
                            .font(.customFont(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Text("€ \(String(format: "%.2f", amount))")
                            .font(.customFont(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
            }

            // Date
            VStack(spacing: 8) {
                // Scadenza bollo
                if let expiryDate = bollo.expiryDate {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scadenza Bollo")
                                .font(.customFont(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Text(formatDate(expiryDate))
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                }

                // Termine pagamento
                if let paymentDeadline = bollo.paymentDeadline {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Termine Pagamento")
                                .font(.customFont(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Text(formatDate(paymentDeadline))
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        if bollo.isExpired {
                            Text("Scaduto")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                }
            }

            // Pulsante aggiorna
            Button(action: {
                loadBolloInfo()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                    Text("Aggiorna")
                        .font(.customFont(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Methods

    private func checkAuthenticationStatus() {
        guard let plateNumber = vehicle.plate?.plateNumber else {
            isAuthenticated = false
            bolloInfo = nil
            return
        }

        if let data = authService.bolloData(for: plateNumber) {
            isAuthenticated = true
            bolloInfo = data
            errorMessage = nil
        } else {
            isAuthenticated = false
            bolloInfo = nil
        }
    }

    private func loadBolloInfo() {
        guard let plateNumber = vehicle.plate?.plateNumber else {
            errorMessage = "Targa non disponibile"
            return
        }

        errorMessage = nil
        isLoading = false

        if let data = authService.bolloData(for: plateNumber) {
            bolloInfo = data
        } else {
            bolloInfo = nil
            errorMessage = "Informazioni non disponibili. Effettua nuovamente l'autenticazione."
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

struct BolloAPIResponse: Codable {
    let codiceEsito: Int
    let descrizioneEsito: String
    let veicoli: [VeicoloBollo]?
}

struct VeicoloBollo: Codable {
    let targa: String
    let fabbrica: String?
    let tipo: String?
    let bollo: BolloInfo?
    let storicoPagamenti: [StoricoPagamento]?
}

struct BolloInfo: Codable {
    let targa: String
    let tipoVeicolo: Int
    let dataDecorrenza: String?
    let dataScadenza: String?
    let dataTerminePagamento: String?
    let importoDovuto: Double?
    let importoVersato: Double?
    let saldo: Double?
    let regione: Int?
    let stato: String?
}

struct StoricoPagamento: Codable {
    let targa: String
    let dataDecorrenza: String?
    let dataScadenza: String?
    let dataTerminePagamento: String?
    let mesiValidita: Int?
    let importoDovuto: String?
    let saldo: String?
    let stato: String?
    let inCorso: Bool?
}

// Modello semplificato per la UI
struct BolloData {
    let isPaid: Bool
    let amount: Double?
    let expiryDate: Date?
    let isExpired: Bool
    let paymentDeadline: Date?
    let historicalPayments: [StoricoPagamento]

    init(from bolloInfo: BolloInfo, storico: [StoricoPagamento]) {
        self.isPaid = bolloInfo.stato?.uppercased() == "PAGATO"
        self.amount = bolloInfo.importoDovuto
        self.historicalPayments = storico

        // Converti le date
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateFormat = "dd/MM/yyyy"

        if let scadenzaStr = bolloInfo.dataScadenza {
            self.expiryDate = dateFormatter.date(from: scadenzaStr)
        } else {
            self.expiryDate = nil
        }

        if let terminePagStr = bolloInfo.dataTerminePagamento {
            self.paymentDeadline = dateFormatter.date(from: terminePagStr)
        } else {
            self.paymentDeadline = nil
        }

        // Controlla se è scaduto
        if let deadline = paymentDeadline {
            self.isExpired = deadline < Date()
        } else {
            self.isExpired = false
        }
    }
}

enum BolloError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case vehicleNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Autenticazione richiesta"
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta non valida"
        case .httpError(let code):
            return "Errore HTTP \(code)"
        case .apiError(let message):
            return "Errore API: \(message)"
        case .vehicleNotFound:
            return "Veicolo non trovato o bollo non disponibile"
        }
    }
}

