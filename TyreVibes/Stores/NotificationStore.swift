//
//  NotificationStore.swift
//  TyreVibes
//
//  Created on 2025-10-04.
//  Notification state management
//

import Foundation
import Combine

@MainActor
class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var predictiveNotifications: [AppNotification] = []
    @Published var upcomingCount: Int = 0
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    private let storageKey = "AppNotifications"
    private let scheduler = NotificationScheduler.shared

    init() {
        loadNotifications()
        updateUnreadCount()
        loadPredictiveNotifications()
    }

    // MARK: - Public Methods

    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        saveNotifications()
        updateUnreadCount()
    }

    func markAsRead(_ notificationId: String) {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            saveNotifications()
            updateUnreadCount()

            // Sincronizza con il backend
            Task {
                await syncMarkAsReadToBackend(notificationId: notificationId)
            }
        }
    }

    func markAllAsRead() {
        notifications = notifications.map { notification in
            var updated = notification
            updated.isRead = true
            return updated
        }
        saveNotifications()
        updateUnreadCount()
    }

    func deleteNotification(notification: AppNotification) {
        if notification.scheduledDate != nil {
            // It's a predictive notification, so remove it from the scheduler
            scheduler.deleteNotification(notificationId: notification.id)
            loadPredictiveNotifications() // Reload to reflect changes
        } else {
            // It's a regular notification, remove from the main list
            notifications.removeAll { $0.id == notification.id }
            saveNotifications()

            // Sincronizza eliminazione con il backend
            Task {
                await syncDeleteToBackend(notificationId: notification.id)
            }
        }
        updateUnreadCount()
    }

    func clearAllNotifications() {
        notifications.removeAll()
        saveNotifications()
        updateUnreadCount()
    }

    func getUnreadNotifications() -> [AppNotification] {
        return notifications.filter { !$0.isRead }
    }

    // MARK: - Predictive Notifications

    func schedulePredictiveNotifications(
        vehicleId: String,
        vehicleName: String,
        currentMileage: Int,
        averageKmPerMonth: Int,
        tyres: [(id: String, treadDepth: Double, age: TimeInterval)],
        lastRotationMileage: Int? = nil,
        lastRotationDate: Date? = nil,
        lastAlignmentDate: Date? = nil,
        lastPressureCheckDate: Date? = nil,
        warrantyExpiryDate: Date? = nil
    ) {
        scheduler.scheduleNotificationsForVehicle(
            vehicleId: vehicleId,
            vehicleName: vehicleName,
            currentMileage: currentMileage,
            averageKmPerMonth: averageKmPerMonth,
            tyres: tyres,
            lastRotationMileage: lastRotationMileage,
            lastRotationDate: lastRotationDate,
            lastAlignmentDate: lastAlignmentDate,
            lastPressureCheckDate: lastPressureCheckDate,
            warrantyExpiryDate: warrantyExpiryDate
        )
        loadPredictiveNotifications()
    }

    func getUpcomingNotifications(withinDays days: Int = 30) -> [AppNotification] {
        return scheduler.getNotificationsDueWithin(days: days)
    }

    func getAllNotifications() -> [AppNotification] {
        let all = notifications + predictiveNotifications
        return all.sorted { notification1, notification2 in
            // Sort by priority first, then by date
            if notification1.priority.sortOrder != notification2.priority.sortOrder {
                return notification1.priority.sortOrder < notification2.priority.sortOrder
            }
            return notification1.timestamp > notification2.timestamp
        }
    }

    func getCriticalNotifications() -> [AppNotification] {
        return getAllNotifications().filter { $0.priority == .critical }
    }

    // MARK: - Private Methods

    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    private func saveNotifications() {
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadNotifications() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else {
            // Load sample notifications for demo
            notifications = AppNotification.samples
            return
        }
        notifications = decoded
    }

    private func loadPredictiveNotifications() {
        predictiveNotifications = scheduler.upcomingNotifications
        upcomingCount = scheduler.scheduledCount
    }

    // MARK: - Remote Sync

    /// Sincronizza le notifiche dal backend Supabase
    func syncNotificationsFromBackend() async {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            guard let session = try? await SupabaseManager.client.auth.session else {
                print("⚠️ Impossibile sincronizzare: utente non autenticato")
                return
            }

            let userId = session.user.id.uuidString

            let remoteNotifications = try await NotificationAPIService.shared.fetchNotifications(
                userId: userId,
                jwtToken: session.accessToken,
                limit: 100
            )

            // Merge con le notifiche locali (evita duplicati)
            let localIds = Set(notifications.map { $0.id })
            let newNotifications = remoteNotifications.filter { !localIds.contains($0.id) }

            notifications = (newNotifications + notifications).sorted { $0.timestamp > $1.timestamp }
            saveNotifications()
            updateUnreadCount()

            lastSyncDate = Date()
            print("✅ Sincronizzate \(newNotifications.count) nuove notifiche dal backend")

        } catch {
            print("❌ Errore sincronizzazione notifiche: \(error.localizedDescription)")
        }
    }

    /// Sincronizza lo stato "letto" al backend
    private func syncMarkAsReadToBackend(notificationId: String) async {
        do {
            guard let session = try? await SupabaseManager.client.auth.session else {
                return
            }

            try await NotificationAPIService.shared.markNotificationAsRead(
                notificationId: notificationId,
                jwtToken: session.accessToken
            )
        } catch {
            print("❌ Errore sincronizzazione mark as read: \(error.localizedDescription)")
        }
    }

    /// Sincronizza l'eliminazione al backend
    private func syncDeleteToBackend(notificationId: String) async {
        do {
            guard let session = try? await SupabaseManager.client.auth.session else {
                return
            }

            try await NotificationAPIService.shared.deleteNotification(
                notificationId: notificationId,
                jwtToken: session.accessToken
            )
        } catch {
            print("❌ Errore sincronizzazione delete: \(error.localizedDescription)")
        }
    }

    // MARK: - Sample Notifications Generator

    func generateSampleNotifications() {
        let samples = [
            AppNotification(
                type: .pressureAlert,
                title: "Tire Pressure Alert",
                message: "Rear left tire pressure is low by 5 PSI. Check and inflate as soon as possible.",
                timestamp: Date().addingTimeInterval(-7200)
            ),
            AppNotification(
                type: .seasonalReminder,
                title: "Seasonal Change Reminder",
                message: "Winter is approaching. Time to consider switching to winter tires in the next 2 weeks.",
                timestamp: Date().addingTimeInterval(-86400)
            ),
            AppNotification(
                type: .maintenanceReminder,
                title: "Maintenance Reminder",
                message: "Your Toyota Camry is due for tire rotation. Schedule service soon.",
                timestamp: Date().addingTimeInterval(-259200)
            ),
            AppNotification(
                type: .specialOffer,
                title: "Special Offer Available",
                message: "Based on your tire condition, you qualify for 15% off on Michelin tires at partner stores.",
                timestamp: Date().addingTimeInterval(-604800)
            )
        ]

        notifications = samples
        saveNotifications()
        updateUnreadCount()
    }
}
