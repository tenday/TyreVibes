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

        // Cattura screenshot
        capturedScreenshot = UIApplication.shared.captureScreenshot()

        // Mostra sheet
        showBugReportSheet = true
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
            submissionError = "La descrizione del bug non può essere vuota"
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

            // Crea request
            let request = BugReportRequest(
                userId: userId,
                description: description,
                screenshot: screenshotBase64,
                deviceInfo: DeviceInfo.current,
                timestamp: ISO8601DateFormatter().string(from: Date())
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

            print("✅ [BUG-REPORT] Segnalazione inviata con successo!")

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
