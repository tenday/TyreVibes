//
//  BugReportManager.swift
//  TyreVibes
//
//  Created by Claude on 31/10/2025.
//

import SwiftUI
import Combine

@MainActor
class BugReportManager: ObservableObject {
    // MARK: - Published Properties

    @Published var showBugReportSheet = false
    @Published var showFeedbackOptions = false
    @Published var reportType: ReportType = .bug
    @Published var isSubmitting = false
    @Published var submissionError: String?
    @Published var showSuccessAlert = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var capturedScreenshot: UIImage?
    private let debounceInterval: TimeInterval = 1.0
    private var lastShakeTime: Date?
    private let hapticFeedback = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    init() {
        setupShakeListener()
        hapticFeedback.prepare()
    }

    // MARK: - Setup

    private func setupShakeListener() {
        NotificationCenter.default.publisher(for: .deviceDidShake)
            .sink { [weak self] _ in
                self?.handleShake()
            }
            .store(in: &cancellables)
    }

    // MARK: - Shake Handling

    private func handleShake() {
        // Debounce: evita trigger multipli
        let now = Date()
        if let lastShake = lastShakeTime,
           now.timeIntervalSince(lastShake) < debounceInterval {
            return
        }
        lastShakeTime = now

        // Haptic feedback
        hapticFeedback.notificationOccurred(.warning)

        // Cattura screenshot subito per averlo pronto
        capturedScreenshot = UIApplication.shared.captureScreenshot()

        // Mostra opzioni invece del sheet diretto
        showFeedbackOptions = true
    }
    
    // MARK: - Flow Control
    
    func selectReportType(_ type: ReportType) {
        self.reportType = type
        self.showFeedbackOptions = false
        // Ritardo leggero per permettere chiusura action sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showBugReportSheet = true
        }
    }

    // MARK: - Public Methods

    func dismissSheet() {
        showBugReportSheet = false
        capturedScreenshot = nil
        submissionError = nil
    }

    func getScreenshot() -> UIImage? {
        return capturedScreenshot
    }

    func submitBugReport(description: String, includeScreenshot: Bool) async {
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submissionError = "La descrizione non può essere vuota"
            return
        }

        isSubmitting = true
        submissionError = nil

        do {
            // Prepara screenshot se richiesto
            let screenshotBase64: String? = if includeScreenshot, let screenshot = capturedScreenshot {
                screenshot.toBase64(compressionQuality: 0.6)
            } else {
                nil
            }

            // Ottieni userId (può essere nil se non loggato)
            let userId = await AuthService.currentUserId
            
            // Ottieni breadcrumbs
            let breadcrumbs = UserActivityLogger.shared.getLogs()

            // Crea request
            let request = BugReportRequest(
                userId: userId,
                description: description,
                screenshot: screenshotBase64,
                deviceInfo: DeviceInfo.current,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                type: reportType,
                breadcrumbs: breadcrumbs
            )

            // Invia al backend
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            let bodyData = try encoder.encode(request)

            try await NetworkManager.shared.requestWithoutResponse(
                endpoint: "/v1/bug-reports",
                method: .post,
                body: bodyData
            )

            print("✅ [REPORT] \(reportType.title) inviato con successo!")

            // Success
            hapticFeedback.notificationOccurred(.success)
            showSuccessAlert = true

            // Chiudi sheet dopo un breve delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 secondi
            dismissSheet()
            showSuccessAlert = false

        } catch let error as NetworkError {
            submissionError = mapNetworkError(error)
            hapticFeedback.notificationOccurred(.error)
        } catch {
            submissionError = "Errore imprevisto: \(error.localizedDescription)"
            hapticFeedback.notificationOccurred(.error)
        }

        isSubmitting = false
    }

    // MARK: - Error Mapping

    private func mapNetworkError(_ error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta dal server non valida"
        case .httpError(let statusCode, let message):
            return "Errore HTTP \(statusCode): \(message ?? "Errore sconosciuto")"
        case .decodingError(let decodingError):
            return "Errore nella decodifica della risposta: \(decodingError.localizedDescription)"
        case .encodingError(let encodingError):
            return "Errore nella codifica della richiesta: \(encodingError.localizedDescription)"
        case .networkError(let networkError):
            return "Errore di rete: \(networkError.localizedDescription)"
        case .unauthorized:
            return "Non autorizzato. Effettua nuovamente l'accesso"
        case .forbidden:
            return "Accesso negato"
        case .notFound:
            return "Risorsa non trovata"
        case .serverError:
            return "Errore del server - Riprova più tardi"
        case .timeout:
            return "Timeout della richiesta"
        }
    }
}
