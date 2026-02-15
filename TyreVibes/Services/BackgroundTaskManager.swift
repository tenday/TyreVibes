//
//  BackgroundTaskManager.swift
//  TyreVibes
//
//  Created by Claude Code
//  Gestisce i task in background per aggiornamento dati (assicurazioni, bollo, revisioni)
//

import Foundation
import BackgroundTasks
import os.log

/// Manager per la gestione dei background tasks iOS
/// Esegue refresh periodici per mantenere aggiornati i dati di assicurazioni, bollo e revisioni
@MainActor
class BackgroundTaskManager: ObservableObject {

    // MARK: - Properties

    static let shared = BackgroundTaskManager()

    /// Identifier univoco per il background refresh task
    static let backgroundRefreshTaskIdentifier = "com.tyrevibes.backgroundrefresh"

    /// Logger dedicato per i background tasks
    private let logger = Logger(subsystem: "com.tyrevibes", category: "BackgroundTasks")

    @Published var lastRefreshDate: Date?
    @Published var isRefreshing: Bool = false

    // MARK: - Initialization

    private init() {
        loadLastRefreshDate()
    }

    // MARK: - Public Methods

    /// Registra i background tasks nell'app
    /// Chiamare questo metodo in AppDelegate o nel main della app
    func registerBackgroundTasks() {
        logger.info("📝 Registrazione background tasks...")

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.logger.info("🚀 Background refresh task avviato")
            Task {
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }

        logger.info("✅ Background tasks registrati con successo")
    }

    /// Schedula il prossimo background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshTaskIdentifier)

        // Esegui il refresh almeno ogni 6 ore
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("✅ Background refresh schedulato per tra 6 ore")
        } catch {
            logger.error("❌ Errore nello scheduling del background refresh: \(error.localizedDescription)")
        }
    }

    /// Esegue un refresh manuale (chiamato dall'utente)
    func performManualRefresh() async {
        logger.info("🔄 Refresh manuale avviato...")
        isRefreshing = true

        do {
            try await refreshAllData()
            logger.info("✅ Refresh manuale completato con successo")
        } catch {
            logger.error("❌ Errore nel refresh manuale: \(error.localizedDescription)")
        }

        isRefreshing = false
    }

    // MARK: - Private Methods

    /// Gestisce l'esecuzione del background refresh
    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        logger.info("⏰ Esecuzione background refresh...")

        // Schedula il prossimo refresh
        scheduleBackgroundRefresh()

        // Crea un task per gestire l'esecuzione
        let refreshTask = Task {
            do {
                try await refreshAllData()
                task.setTaskCompleted(success: true)
                logger.info("✅ Background refresh completato con successo")
            } catch {
                task.setTaskCompleted(success: false)
                logger.error("❌ Background refresh fallito: \(error.localizedDescription)")
            }
        }

        // Gestisci l'eventuale scadenza del task
        task.expirationHandler = {
            refreshTask.cancel()
            self.logger.warning("⚠️ Background refresh interrotto per timeout")
        }

        await refreshTask.value
    }

    /// Refresh di tutti i dati (assicurazioni, bollo, revisioni)
    private func refreshAllData() async throws {
        logger.info("🔄 Inizio refresh di tutti i dati...")

        let startTime = Date()

        // Esegui i refresh in parallelo per massimizzare performance
        async let insuranceRefresh = refreshInsuranceData()
        async let bolloRefresh = refreshBolloData()
        async let revisionRefresh = refreshRevisionData()
        async let notificationsRefresh = refreshNotifications()
        async let maintenanceRefresh = refreshMaintenanceScheduling()

        // Attendi il completamento di tutti i refresh
        let results = await [
            insuranceRefresh,
            bolloRefresh,
            revisionRefresh,
            notificationsRefresh,
            maintenanceRefresh
        ]

        // Verifica se ci sono stati errori
        let errors = results.compactMap { $0 }
        if !errors.isEmpty {
            logger.error("⚠️ Alcuni refresh hanno generato errori: \(errors.count)")
            for error in errors {
                logger.error("  - \(error.localizedDescription)")
            }
        }

        // Aggiorna la data dell'ultimo refresh
        lastRefreshDate = Date()
        saveLastRefreshDate()

        let duration = Date().timeIntervalSince(startTime)
        logger.info("✅ Refresh completato in \(String(format: "%.2f", duration))s")
    }

    /// Refresh dei dati delle assicurazioni
    private func refreshInsuranceData() async -> Error? {
        logger.info("🔍 Refresh assicurazioni...")

        do {
            // Chiama l'Edge Function per aggiornare le assicurazioni
            let response = try await callEdgeFunction(name: "update-insurance-expiry")
            logger.info("✅ Assicurazioni aggiornate: \(response)")
            return nil
        } catch {
            logger.error("❌ Errore refresh assicurazioni: \(error.localizedDescription)")
            return error
        }
    }

    /// Refresh dei dati del bollo
    private func refreshBolloData() async -> Error? {
        logger.info("🔍 Refresh bollo auto...")

        do {
            // Chiama l'Edge Function per aggiornare il bollo
            let response = try await callEdgeFunction(name: "update-bollo-status")
            logger.info("✅ Bollo aggiornato: \(response)")
            return nil
        } catch {
            logger.error("❌ Errore refresh bollo: \(error.localizedDescription)")
            return error
        }
    }

    /// Refresh dei dati delle revisioni
    private func refreshRevisionData() async -> Error? {
        logger.info("🔍 Refresh revisioni...")

        do {
            // Chiama l'Edge Function per aggiornare le revisioni
            let response = try await callEdgeFunction(name: "update-revision-status")
            logger.info("✅ Revisioni aggiornate: \(response)")
            return nil
        } catch {
            logger.error("❌ Errore refresh revisioni: \(error.localizedDescription)")
            return error
        }
    }

    /// Refresh delle notifiche dal server
    private func refreshNotifications() async -> Error? {
        logger.info("🔍 Refresh notifiche...")

        do {
            // Recupera le nuove notifiche dal database
            let notifications = try await fetchNotifications()

            // Aggiorna le notifiche locali
            await NotificationScheduler.shared.syncWithServerNotifications(notifications)

            logger.info("✅ Notifiche aggiornate: \(notifications.count) nuove")
            return nil
        } catch {
            logger.error("❌ Errore refresh notifiche: \(error.localizedDescription)")
            return error
        }
    }

    /// Ricalcola scheduling manutenzione meccanica per tutti i veicoli
    private func refreshMaintenanceScheduling() async -> Error? {
        logger.info("🔍 Refresh scheduling manutenzione...")

        do {
            // Recupera tutti i veicoli dell'utente
            let vehiclesData = try await SupabaseManager.client
                .from("vehicles")
                .select("id, brand, model")
                .execute()

            struct VehicleBasic: Decodable {
                let id: Int
                let brand: String
                let model: String
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let vehicles = try decoder.decode([VehicleBasic].self, from: vehiclesData.data)

            // Per ogni veicolo, ricalcola scheduling e notifiche
            for vehicle in vehicles {
                SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicle.id)
                NotificationScheduler.shared.scheduleMaintenanceReminders(
                    vehicleId: vehicle.id,
                    vehicleName: "\(vehicle.brand) \(vehicle.model)"
                )
            }

            logger.info("✅ Scheduling manutenzione aggiornato per \(vehicles.count) veicoli")
            return nil
        } catch {
            logger.error("❌ Errore refresh scheduling manutenzione: \(error.localizedDescription)")
            return error
        }
    }

    /// Chiama una Supabase Edge Function
    private func callEdgeFunction(name: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/\(name)") else {
            throw NSError(domain: "BackgroundTaskManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "URL non valido"
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Aggiungi il token JWT se l'utente è autenticato
        if let token = try? await SupabaseManager.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "BackgroundTaskManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Errore nella risposta del server"
            ])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BackgroundTaskManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Errore nel parsing della risposta"
            ])
        }

        return json
    }

    /// Recupera le notifiche dal database Supabase
    private func fetchNotifications() async throws -> [AppNotification] {
        let notifications = try await SupabaseManager.client
            .from("notifications")
            .select()
            .eq("read", value: false)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([AppNotification].self, from: notifications.data)
    }

    // MARK: - Persistence

    private func loadLastRefreshDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "LastBackgroundRefreshDate") as? Date {
            lastRefreshDate = timestamp
        }
    }

    private func saveLastRefreshDate() {
        UserDefaults.standard.set(lastRefreshDate, forKey: "LastBackgroundRefreshDate")
    }
}

// MARK: - Extensions

extension BackgroundTaskManager {

    /// Verifica se è necessario un refresh
    var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }

        // Refresh necessario se sono passate più di 6 ore
        let sixHoursAgo = Date().addingTimeInterval(-6 * 60 * 60)
        return lastRefresh < sixHoursAgo
    }

    /// Formatta la data dell'ultimo refresh per la UI
    var lastRefreshDescription: String {
        guard let lastRefresh = lastRefreshDate else {
            return "Mai"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.unitsStyle = .full

        return formatter.localizedString(for: lastRefresh, relativeTo: Date())
    }
}
