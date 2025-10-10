import Foundation
import Combine

/// Manager per gestire i retry in background del fetching delle revisioni
/// Quando la scansione targa non riesce a ottenere le revisioni, questo manager
/// effettua retry automatici senza bloccare l'utente
@MainActor
class RevisionRetryManager: ObservableObject {
    static let shared = RevisionRetryManager()

    @Published private(set) var revisionsByPlate: [String: [[String: String]]] = [:]
    @Published private(set) var isRetrying: [String: Bool] = [:]

    private var retryTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    /// Schedula retry in background per una targa specifica
    /// - Parameters:
    ///   - plate: La targa del veicolo
    ///   - tipoVeicolo: Tipo veicolo (default "A")
    ///   - maxAttempts: Numero massimo di tentativi (default 10)
    ///   - initialDelay: Ritardo iniziale in secondi (default 2)
    ///   - onSuccess: Callback chiamato quando le revisioni vengono fetchate con successo
    func scheduleBackgroundRetry(
        for plate: String,
        tipoVeicolo: String = "A",
        maxAttempts: Int = 10,
        initialDelay: TimeInterval = 2.0,
        onSuccess: ((RevisioniResult) -> Void)? = nil
    ) {
        // Cancella eventuali retry precedenti per questa targa
        cancelRetry(for: plate)

        let task = Task { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isRetrying[plate] = true
            }

            print("🔄 [RevisionRetry] Inizio retry in background per targa: \(plate)")

            // Attendi il delay iniziale prima di iniziare
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))

            var currentAttempt = 0
            var backoffDelay = 3.0 // Delay tra i tentativi (exponential backoff)

            while currentAttempt < maxAttempts {
                // Controlla se il task è stato cancellato
                if Task.isCancelled {
                    print("🛑 [RevisionRetry] Task cancellato per targa: \(plate)")
                    break
                }

                currentAttempt += 1
                print("🔄 [RevisionRetry] Tentativo \(currentAttempt)/\(maxAttempts) per targa: \(plate)")

                do {
                    // Prova a fetchare le revisioni
                    let revisioni = try await LicensePlateReader.fetchRevisioniSecureAsync(
                        plate: plate,
                        tipoVeicolo: tipoVeicolo,
                        maxAttempts: 4
                    )

                    // Controlla se abbiamo ottenuto dati validi
                    if !revisioni.isEmpty {
                        print("✅ [RevisionRetry] Revisioni ottenute con successo per targa: \(plate) (tentativo \(currentAttempt))")

                        // Converti in array di Revisione
                        let revisioniArray = parseRevisioni(from: revisioni)

                        await MainActor.run {
                            self.revisionsByPlate[plate] = revisioni
                            self.isRetrying[plate] = false

                            // Notifica il successo
                            onSuccess?(RevisioniResult(plate: plate, revisioni: revisioniArray))
                        }

                        // Aggiorna il database se necessario
                        await self.updateRevisioniInDatabase(plate: plate, revisioni: revisioniArray)

                        break // Successo, esci dal loop
                    } else {
                        print("⚠️ [RevisionRetry] Nessuna revisione trovata per targa: \(plate) (tentativo \(currentAttempt))")
                    }
                } catch {
                    print("❌ [RevisionRetry] Errore nel tentativo \(currentAttempt) per targa \(plate): \(error.localizedDescription)")
                }

                // Se non è l'ultimo tentativo, aspetta prima di riprovare (exponential backoff)
                if currentAttempt < maxAttempts && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    backoffDelay = min(backoffDelay * 1.5, 30.0) // Max 30 secondi
                }
            }

            // Se siamo arrivati qui senza successo
            if currentAttempt >= maxAttempts {
                print("❌ [RevisionRetry] Raggiunto numero massimo di tentativi per targa: \(plate)")
            }

            await MainActor.run {
                self.isRetrying[plate] = false
                self.retryTasks.removeValue(forKey: plate)
            }
        }

        retryTasks[plate] = task
    }

    /// Cancella i retry in background per una targa specifica
    func cancelRetry(for plate: String) {
        retryTasks[plate]?.cancel()
        retryTasks.removeValue(forKey: plate)
        isRetrying[plate] = false
    }

    /// Cancella tutti i retry in corso
    func cancelAllRetries() {
        retryTasks.values.forEach { $0.cancel() }
        retryTasks.removeAll()
        isRetrying.removeAll()
    }

    /// Ottieni le revisioni per una targa (se disponibili)
    func getRevisioni(for plate: String) -> [[String: String]]? {
        return revisionsByPlate[plate]
    }

    /// Controlla se è in corso un retry per una targa
    func isRetryingRevisioni(for plate: String) -> Bool {
        return isRetrying[plate] ?? false
    }

    // MARK: - Private Helpers

    /// Parse revisioni dal formato dizionario al formato Revisione
    private func parseRevisioni(from rawData: [[String: String]]) -> [Revisione] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return rawData.compactMap { dict in
            guard let km = dict["km"],
                  let esito = dict["esito"] else {
                return nil
            }

            var dataRevisione: Date?
            if let dataStr = dict["data"] {
                dataRevisione = dateFormatter.date(from: dataStr)
            }

            return Revisione(
                kmRevisione: km,
                dataRevisione: dataRevisione,
                esitoRevisione: esito
            )
        }
    }

    /// Aggiorna le revisioni nella cache per il veicolo
    private func updateRevisioniInDatabase(plate: String, revisioni: [Revisione]) async {
        // Aggiorna la cache con le nuove revisioni
        if var cachedData = PlateDataCache.get(plate) {
            cachedData.revisioni = revisioni
            PlateDataCache.set(plate, data: cachedData)
            print("✅ [RevisionRetry] Revisioni aggiornate nella cache per targa: \(plate)")
        } else {
            print("⚠️ [RevisionRetry] PlateData non trovata nella cache per targa: \(plate)")
        }
    }
}

// MARK: - Supporting Types

struct RevisioniResult {
    let plate: String
    let revisioni: [Revisione]
}
