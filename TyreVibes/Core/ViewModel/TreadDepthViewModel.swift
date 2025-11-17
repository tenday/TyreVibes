//
//  TreadDepthViewModel.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import ARKit

// MARK: - Tread Depth ViewModel

@MainActor
class TreadDepthViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Stato della misurazione
    @Published var measurementState: MeasurementState = .idle

    /// Risultato dell'ultima misurazione
    @Published var lastMeasurement: TreadDepthMeasurement?

    /// Progresso della scansione (0-1)
    @Published var scanProgress: Float = 0.0

    /// Numero di punti acquisiti
    @Published var pointCount: Int = 0

    /// Messaggio di stato per l'utente
    @Published var statusMessage: String = "Pronto per iniziare"

    /// Indica se LiDAR è disponibile
    @Published var isLiDARAvailable: Bool = false

    /// Indica se è in corso una scansione
    @Published var isScanning: Bool = false

    /// Indica se è in corso l'elaborazione
    @Published var isProcessing: Bool = false

    /// Messaggio di errore
    @Published var errorMessage: String?

    /// Mostra alert errore
    @Published var showError: Bool = false

    /// Configurazione scansione
    @Published var scanConfiguration: LiDARTreadMeasurementService.ScanConfiguration = .default

    /// Storico misurazioni
    @Published var measurementHistory: [TreadDepthMeasurement] = []

    // MARK: - Private Properties

    private let service = LiDARTreadMeasurementService.shared
    private var cancellables = Set<AnyCancellable>()
    private var tyreId: UUID?

    // MARK: - Initialization

    init() {
        setupSubscriptions()
        checkLiDARAvailability()
        loadMeasurementHistory()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Sottoscrivi agli aggiornamenti del servizio
        service.measurementPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleMeasurementUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func checkLiDARAvailability() {
        isLiDARAvailable = service.isLiDARAvailable

        if !isLiDARAvailable {
            statusMessage = "LiDAR non disponibile su questo dispositivo"
            measurementState = .unavailable
        }
    }

    // MARK: - Public Methods

    /// Avvia la misurazione
    /// - Parameter tyreId: ID del pneumatico (opzionale)
    func startMeasurement(tyreId: UUID? = nil) {
        guard isLiDARAvailable else {
            showErrorAlert("LiDAR non disponibile su questo dispositivo")
            return
        }

        guard measurementState == .idle || measurementState == .completed else {
            return
        }

        self.tyreId = tyreId
        scanProgress = 0.0
        pointCount = 0
        errorMessage = nil

        service.startMeasurement(tyreId: tyreId, configuration: scanConfiguration)

        measurementState = .scanning
        isScanning = true
        statusMessage = "Scansiona la superficie del pneumatico..."

        print("🔍 [TreadDepthVM] Misurazione avviata")
    }

    /// Ferma la misurazione e processa i dati
    func stopMeasurement() async {
        guard isScanning else { return }

        isScanning = false
        isProcessing = true
        measurementState = .processing
        statusMessage = "Elaborazione dati in corso..."

        do {
            let measurement = try await service.finalizeMeasurement()
            lastMeasurement = measurement

            // Salva nello storico
            addToHistory(measurement)

            measurementState = .completed
            statusMessage = "Misurazione completata!"

            print("✅ [TreadDepthVM] Misurazione completata - Profondità: \(String(format: "%.2f", measurement.averageDepth))mm")
        } catch {
            handleError(error)
        }

        isProcessing = false
    }

    /// Annulla la misurazione
    func cancelMeasurement() {
        service.cancelMeasurement()

        isScanning = false
        isProcessing = false
        measurementState = .idle
        scanProgress = 0.0
        pointCount = 0
        statusMessage = "Misurazione annullata"

        print("⚠️ [TreadDepthVM] Misurazione annullata")
    }

    /// Reset dello stato
    func reset() {
        cancelMeasurement()
        lastMeasurement = nil
        errorMessage = nil
        statusMessage = "Pronto per iniziare"
    }

    /// Salva la misurazione nel database
    /// - Parameter measurement: Misurazione da salvare
    func saveMeasurement(_ measurement: TreadDepthMeasurement) async {
        // TODO: Implementare salvataggio su Supabase
        // Questo sarà integrato con il TyreService esistente

        print("💾 [TreadDepthVM] Salvataggio misurazione - ID: \(measurement.id)")

        // Per ora salva solo localmente
        addToHistory(measurement)
    }

    /// Elimina una misurazione dallo storico
    /// - Parameter measurement: Misurazione da eliminare
    func deleteMeasurement(_ measurement: TreadDepthMeasurement) {
        measurementHistory.removeAll { $0.id == measurement.id }
        saveMeasurementHistory()

        print("🗑️ [TreadDepthVM] Misurazione eliminata - ID: \(measurement.id)")
    }

    /// Esporta misurazione in formato JSON
    /// - Parameter measurement: Misurazione da esportare
    /// - Returns: Dati JSON
    func exportMeasurement(_ measurement: TreadDepthMeasurement) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(measurement)
            print("📤 [TreadDepthVM] Misurazione esportata")
            return data
        } catch {
            print("❌ [TreadDepthVM] Errore export: \(error)")
            return nil
        }
    }

    /// Calibra il sensore con un valore noto
    /// - Parameter knownDepth: Profondità nota in mm
    func calibrate(knownDepth: Double) async {
        isProcessing = true
        statusMessage = "Calibrazione in corso..."

        do {
            let calibrationData = try await service.calibrate(knownDepth: knownDepth)
            statusMessage = "Calibrazione completata!"

            print("✅ [TreadDepthVM] Calibrazione completata - Offset: \(calibrationData.offset)mm")
        } catch {
            handleError(error)
        }

        isProcessing = false
    }

    // MARK: - Private Methods

    private func handleMeasurementUpdate(_ update: MeasurementUpdate) {
        switch update {
        case .started:
            measurementState = .scanning
            statusMessage = "Scansione avviata..."

        case .progress(let progress, let count):
            scanProgress = progress
            pointCount = count
            statusMessage = "Scansione in corso... \(count) punti"

        case .processing:
            measurementState = .processing
            statusMessage = "Elaborazione dati..."

        case .completed(let measurement):
            lastMeasurement = measurement
            measurementState = .completed
            statusMessage = "Completato!"

        case .error(let error):
            handleError(error)

        case .cancelled:
            measurementState = .idle
            statusMessage = "Annullato"
        }
    }

    private func handleError(_ error: Error) {
        measurementState = .error

        if let measurementError = error as? MeasurementError {
            errorMessage = measurementError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }

        statusMessage = "Errore: \(errorMessage ?? "Sconosciuto")"
        showError = true

        print("❌ [TreadDepthVM] Errore: \(errorMessage ?? "N/A")")
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - History Management

    private func addToHistory(_ measurement: TreadDepthMeasurement) {
        // Aggiungi all'inizio dell'array
        measurementHistory.insert(measurement, at: 0)

        // Mantieni solo le ultime 50 misurazioni
        if measurementHistory.count > 50 {
            measurementHistory = Array(measurementHistory.prefix(50))
        }

        saveMeasurementHistory()
    }

    private func saveMeasurementHistory() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(measurementHistory) {
            UserDefaults.standard.set(encoded, forKey: "tread_measurement_history")
        }
    }

    private func loadMeasurementHistory() {
        guard let data = UserDefaults.standard.data(forKey: "tread_measurement_history") else {
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([TreadDepthMeasurement].self, from: data) {
            measurementHistory = decoded
            print("✅ [TreadDepthVM] Caricato storico - \(decoded.count) misurazioni")
        }
    }

    // MARK: - Computed Properties

    /// Messaggio formattato per la profondità media
    var formattedAverageDepth: String {
        guard let measurement = lastMeasurement else { return "N/A" }
        return String(format: "%.2f mm", measurement.averageDepth)
    }

    /// Messaggio formattato per il range di profondità
    var formattedDepthRange: String {
        guard let measurement = lastMeasurement else { return "N/A" }
        return String(format: "%.2f - %.2f mm",
                     measurement.minDepth,
                     measurement.maxDepth)
    }

    /// Colore per lo stato del battistrada
    var treadStatusColor: Color {
        guard let status = lastMeasurement?.treadStatus else { return .gray }

        switch status.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    /// Icona per lo stato del battistrada
    var treadStatusIcon: String {
        return lastMeasurement?.treadStatus.icon ?? "questionmark.circle"
    }

    /// Testo dello stato del battistrada
    var treadStatusText: String {
        return lastMeasurement?.treadStatus.displayName ?? "N/A"
    }

    /// Percentuale di confidenza formattata
    var formattedConfidence: String {
        guard let measurement = lastMeasurement else { return "N/A" }
        return String(format: "%.0f%%", measurement.confidenceScore)
    }

    /// Indicazione se la misurazione è affidabile
    var isReliableMeasurement: Bool {
        guard let measurement = lastMeasurement else { return false }
        return measurement.confidenceScore >= 70.0
    }
}

// MARK: - Measurement State

enum MeasurementState {
    case idle
    case scanning
    case processing
    case completed
    case error
    case unavailable

    var displayName: String {
        switch self {
        case .idle:
            return "Pronto"
        case .scanning:
            return "Scansione..."
        case .processing:
            return "Elaborazione..."
        case .completed:
            return "Completato"
        case .error:
            return "Errore"
        case .unavailable:
            return "Non disponibile"
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "camera.metering.center.weighted"
        case .scanning:
            return "viewfinder"
        case .processing:
            return "gearshape.2"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "nosign"
        }
    }
}
