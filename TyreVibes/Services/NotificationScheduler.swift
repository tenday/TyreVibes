//
//  NotificationScheduler.swift
//  TyreVibes
//
//  Created on 2025-10-04.
//  Predictive notification scheduling service
//

import Foundation
import Combine

@MainActor
class NotificationScheduler: ObservableObject {

    static let shared = NotificationScheduler()

    @Published var upcomingNotifications: [AppNotification] = []
    @Published var scheduledCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants for Predictions

    private enum MaintenanceIntervals {
        static let tyreRotationKm = 10000 // Every 10,000 km
        static let pressureCheckDays = 30 // Monthly
        static let alignmentCheckMonths = 12 // Yearly
        static let inspectionMonths = 6 // Bi-annually
        static let seasonalChangeMonths = 6 // Twice a year (summer/winter)
        static let warrantyCheckDays = 90 // 3 months before expiry
    }

    private enum TyreReplacementThresholds {
        static let minTreadDepthMM = 1.6 // Legal minimum
        static let recommendedTreadDepthMM = 3.0 // Recommended replacement
        static let warningTreadDepthMM = 4.0 // Warning threshold
        static let maxTyreAgeYears = 6 // Maximum tyre age
    }

    private init() {
        loadScheduledNotifications()
    }

    // MARK: - Prediction Algorithms

    /// Predict when tyre replacement will be needed based on tread depth and usage
    func predictTyreReplacement(
        currentTreadDepth: Double,
        mileage: Int,
        averageKmPerMonth: Int,
        tyreAge: TimeInterval
    ) -> Date? {
        guard currentTreadDepth > TyreReplacementThresholds.minTreadDepthMM else {
            return Date() // Immediate replacement needed
        }

        // Calculate wear rate (mm per km)
        let totalWear = 8.0 - currentTreadDepth // Assuming new tyre is 8mm
        let wearRate = totalWear / Double(mileage)

        // Calculate remaining safe depth
        let remainingDepth = currentTreadDepth - TyreReplacementThresholds.recommendedTreadDepthMM

        // Predict km until replacement
        let remainingKm = remainingDepth / wearRate

        // Convert to months
        let remainingMonths = Int(remainingKm / Double(averageKmPerMonth))

        // Check age-based replacement
        let tyreAgeYears = tyreAge / (365.25 * 24 * 3600)
        let ageBasedMonths = Int((Double(TyreReplacementThresholds.maxTyreAgeYears) - tyreAgeYears) * 12)

        // Use the earlier date
        let monthsUntilReplacement = min(remainingMonths, ageBasedMonths)

        guard monthsUntilReplacement > 0 else {
            return Date()
        }

        return Calendar.current.date(byAdding: .month, value: monthsUntilReplacement, to: Date())
    }

    /// Predict next rotation based on current mileage and average usage
    func predictNextRotation(
        currentMileage: Int,
        lastRotationMileage: Int?,
        averageKmPerMonth: Int
    ) -> Date? {
        let lastRotation = lastRotationMileage ?? 0
        let kmSinceRotation = currentMileage - lastRotation
        let kmUntilRotation = MaintenanceIntervals.tyreRotationKm - kmSinceRotation

        guard kmUntilRotation > 0 else {
            return Date() // Rotation overdue
        }

        let monthsUntilRotation = kmUntilRotation / averageKmPerMonth
        return Calendar.current.date(byAdding: .month, value: monthsUntilRotation, to: Date())
    }

    /// Predict seasonal tyre change based on location and climate data
    func predictSeasonalChange(hemisphere: String = "north") -> Date? {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)

        // Northern hemisphere: Winter tyres Nov-Mar, Summer tyres Apr-Oct
        // Southern hemisphere: Opposite
        let isNorth = hemisphere.lowercased() == "north"

        var targetMonth: Int
        if isNorth {
            // Check if we need winter or summer tyres
            if month >= 4 && month <= 10 {
                // Currently summer season, predict winter change
                targetMonth = 11 // November
            } else {
                // Currently winter season, predict summer change
                targetMonth = 4 // April
            }
        } else {
            // Southern hemisphere (opposite)
            if month >= 10 || month <= 3 {
                // Currently summer season, predict winter change
                targetMonth = 5 // May
            } else {
                // Currently winter season, predict summer change
                targetMonth = 10 // October
            }
        }

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.month = targetMonth
        components.day = 1

        guard var targetDate = calendar.date(from: components) else { return nil }

        // If target date is in the past, add a year
        if targetDate < now {
            targetDate = calendar.date(byAdding: .year, value: 1, to: targetDate) ?? targetDate
        }

        return targetDate
    }

    /// Predict pressure check reminder
    func predictPressureCheck(lastCheckDate: Date?) -> Date? {
        let lastCheck = lastCheckDate ?? Date()
        return Calendar.current.date(byAdding: .day, value: MaintenanceIntervals.pressureCheckDays, to: lastCheck)
    }

    /// Predict alignment check
    func predictAlignmentCheck(lastAlignmentDate: Date?) -> Date? {
        let lastAlignment = lastAlignmentDate ?? Date()
        return Calendar.current.date(byAdding: .month, value: MaintenanceIntervals.alignmentCheckMonths, to: lastAlignment)
    }

    /// Predict warranty expiry notification
    func predictWarrantyReminder(warrantyExpiryDate: Date) -> Date? {
        return Calendar.current.date(byAdding: .day, value: -MaintenanceIntervals.warrantyCheckDays, to: warrantyExpiryDate)
    }

    // MARK: - Notification Scheduling

    /// Schedule all predictive notifications for a vehicle
    func scheduleNotificationsForVehicle(
        vehicleId: String,
        vehicleName: String,
        currentMileage: Int,
        averageKmPerMonth: Int,
        tyres: [(id: String, treadDepth: Double, age: TimeInterval)],
        lastRotationMileage: Int?,
        lastRotationDate: Date?,
        lastAlignmentDate: Date?,
        lastPressureCheckDate: Date?,
        warrantyExpiryDate: Date?
    ) {
        var notifications: [AppNotification] = []

        // 1. Tyre Replacement Predictions
        for tyre in tyres {
            if let predictedDate = predictTyreReplacement(
                currentTreadDepth: tyre.treadDepth,
                mileage: currentMileage,
                averageKmPerMonth: averageKmPerMonth,
                tyreAge: tyre.age
            ) {
                let monthsUntil = Calendar.current.dateComponents([.month], from: Date(), to: predictedDate).month ?? 0

                let priority: AppNotification.Priority = monthsUntil <= 1 ? .critical : monthsUntil <= 3 ? .high : .medium

                let notification = AppNotification(
                    type: .tyreReplacement,
                    title: "Predicted Tyre Replacement",
                    message: "Based on current wear, tyre replacement for \(vehicleName) is predicted in approximately \(monthsUntil) months.",
                    timestamp: Date(),
                    isRead: false,
                    vehicleId: vehicleId,
                    tyreId: tyre.id,
                    priority: priority,
                    actionRequired: monthsUntil <= 2,
                    scheduledDate: predictedDate,
                    predictedDate: predictedDate,
                    metadata: AppNotification.NotificationMetadata(
                        treadDepth: tyre.treadDepth,
                        pressurePSI: nil,
                        mileage: currentMileage,
                        lastServiceDate: lastRotationDate,
                        nextServiceDate: predictedDate,
                        estimatedCost: 400.0,
                        warrantyExpiryDate: warrantyExpiryDate,
                        seasonalChangeDate: nil,
                        rotationDueKm: nil,
                        replacementDueMonths: monthsUntil
                    )
                )
                notifications.append(notification)
            }
        }

        // 2. Rotation Reminder
        if let nextRotationDate = predictNextRotation(
            currentMileage: currentMileage,
            lastRotationMileage: lastRotationMileage,
            averageKmPerMonth: averageKmPerMonth
        ) {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextRotationDate).day ?? 0
            let priority: AppNotification.Priority = daysUntil <= 7 ? .high : .medium

            let notification = AppNotification(
                type: .rotation,
                title: "Predicted Tyre Rotation",
                message: "Based on your driving patterns, \(vehicleName) will need tyre rotation in approximately \(daysUntil) days.",
                timestamp: Date(),
                isRead: false,
                vehicleId: vehicleId,
                priority: priority,
                actionRequired: daysUntil <= 14,
                scheduledDate: nextRotationDate,
                predictedDate: nextRotationDate,
                metadata: AppNotification.NotificationMetadata(
                    treadDepth: nil,
                    pressurePSI: nil,
                    mileage: currentMileage,
                    lastServiceDate: lastRotationDate,
                    nextServiceDate: nextRotationDate,
                    estimatedCost: 50.0,
                    warrantyExpiryDate: nil,
                    seasonalChangeDate: nil,
                    rotationDueKm: MaintenanceIntervals.tyreRotationKm,
                    replacementDueMonths: nil
                )
            )
            notifications.append(notification)
        }

        // 3. Seasonal Change
        if let seasonalDate = predictSeasonalChange() {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: seasonalDate).day ?? 0

            if daysUntil <= 60 && daysUntil > 0 { // Only notify within 60 days
                let notification = AppNotification(
                    type: .seasonalReminder,
                    title: "Seasonal Tyre Change Reminder",
                    message: "The season is changing in approximately \(daysUntil) days. Consider switching tyres for \(vehicleName).",
                    timestamp: Date(),
                    isRead: false,
                    vehicleId: vehicleId,
                    priority: .medium,
                    actionRequired: daysUntil <= 14,
                    scheduledDate: seasonalDate,
                    predictedDate: seasonalDate,
                    metadata: AppNotification.NotificationMetadata(
                        treadDepth: nil,
                        pressurePSI: nil,
                        mileage: nil,
                        lastServiceDate: nil,
                        nextServiceDate: seasonalDate,
                        estimatedCost: 100.0,
                        warrantyExpiryDate: nil,
                        seasonalChangeDate: seasonalDate,
                        rotationDueKm: nil,
                        replacementDueMonths: nil
                    )
                )
                notifications.append(notification)
            }
        }

        // 4. Pressure Check
        if let pressureCheckDate = predictPressureCheck(lastCheckDate: lastPressureCheckDate) {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: pressureCheckDate).day ?? 0

            if daysUntil <= 7 && daysUntil >= 0 {
                let notification = AppNotification(
                    type: .pressureAlert,
                    title: "Pressure Check Reminder",
                    message: "It's been a month since your last pressure check for \(vehicleName). Check and adjust as needed.",
                    timestamp: Date(),
                    isRead: false,
                    vehicleId: vehicleId,
                    priority: .low,
                    actionRequired: false,
                    scheduledDate: pressureCheckDate,
                    predictedDate: pressureCheckDate
                )
                notifications.append(notification)
            }
        }

        // 5. Alignment Check
        if let alignmentDate = predictAlignmentCheck(lastAlignmentDate: lastAlignmentDate) {
            let monthsUntil = Calendar.current.dateComponents([.month], from: Date(), to: alignmentDate).month ?? 0

            if monthsUntil <= 1 && monthsUntil >= 0 {
                let notification = AppNotification(
                    type: .alignment,
                    title: "Wheel Alignment Check",
                    message: "Annual alignment check recommended for \(vehicleName) in approximately \(monthsUntil) months.",
                    timestamp: Date(),
                    isRead: false,
                    vehicleId: vehicleId,
                    priority: .low,
                    actionRequired: false,
                    scheduledDate: alignmentDate,
                    predictedDate: alignmentDate,
                    metadata: AppNotification.NotificationMetadata(
                        treadDepth: nil,
                        pressurePSI: nil,
                        mileage: currentMileage,
                        lastServiceDate: lastAlignmentDate,
                        nextServiceDate: alignmentDate,
                        estimatedCost: 80.0,
                        warrantyExpiryDate: nil,
                        seasonalChangeDate: nil,
                        rotationDueKm: nil,
                        replacementDueMonths: nil
                    )
                )
                notifications.append(notification)
            }
        }

        // 6. Warranty Expiry
        if let warrantyDate = warrantyExpiryDate,
           let reminderDate = predictWarrantyReminder(warrantyExpiryDate: warrantyDate) {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: reminderDate).day ?? 0

            if daysUntil <= 30 && daysUntil >= 0 {
                let notification = AppNotification(
                    type: .warranty,
                    title: "Warranty Expiry Warning",
                    message: "Your tyre warranty for \(vehicleName) expires in \(daysUntil) days. Schedule an inspection if needed.",
                    timestamp: Date(),
                    isRead: false,
                    vehicleId: vehicleId,
                    priority: .medium,
                    actionRequired: true,
                    scheduledDate: reminderDate,
                    predictedDate: warrantyDate,
                    metadata: AppNotification.NotificationMetadata(
                        treadDepth: nil,
                        pressurePSI: nil,
                        mileage: nil,
                        lastServiceDate: nil,
                        nextServiceDate: nil,
                        estimatedCost: nil,
                        warrantyExpiryDate: warrantyDate,
                        seasonalChangeDate: nil,
                        rotationDueKm: nil,
                        replacementDueMonths: nil
                    )
                )
                notifications.append(notification)
            }
        }

        // Store and update
        upcomingNotifications = notifications
        saveScheduledNotifications()
        scheduledCount = notifications.count
    }

    // MARK: - Mechanical Maintenance Scheduling

    /// Schedule maintenance reminders for all mechanical types based on SmartMaintenanceScheduler
    func scheduleMaintenanceReminders(vehicleId: Int, vehicleName: String) {
        // Evaluate and update schedule store
        SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)

        // Read the updated schedules from the store
        let schedules = MaintenanceScheduleStore.shared.schedules(for: vehicleId)
        var notifications: [AppNotification] = []

        for schedule in schedules {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: schedule.scheduledDate).day ?? 0

            // Determine notification type based on maintenance category
            let notificationType: AppNotification.NotificationType
            switch schedule.type.category {
            case .engine:
                notificationType = schedule.type == .oilChange ? .oilChangeReminder : .generalMaintenanceReminder
            case .filters:
                notificationType = .filterReminder
            case .brakes:
                notificationType = .brakeReminder
            case .fluids:
                notificationType = .generalMaintenanceReminder
            case .tyres:
                continue // Tyre notifications handled by existing methods
            case .other:
                notificationType = schedule.type == .battery ? .batteryReminder : .generalMaintenanceReminder
            }

            // Priority escalation
            let priority: AppNotification.Priority
            if daysUntil < 0 && abs(daysUntil) > 30 {
                priority = .critical
            } else if daysUntil < 0 {
                priority = .high
            } else if daysUntil <= 7 {
                priority = .medium
            } else {
                priority = .low
            }

            // Only create notifications for items within 60 days or overdue
            guard daysUntil <= 60 else { continue }

            let notification = AppNotification(
                type: notificationType,
                title: schedule.title,
                message: schedule.description,
                timestamp: Date(),
                isRead: false,
                vehicleId: String(vehicleId),
                priority: priority,
                actionRequired: daysUntil <= 7,
                scheduledDate: schedule.scheduledDate,
                predictedDate: schedule.scheduledDate,
                metadata: AppNotification.NotificationMetadata(
                    treadDepth: nil,
                    pressurePSI: nil,
                    mileage: schedule.metadata?.currentMileage,
                    lastServiceDate: schedule.metadata?.lastServiceDate,
                    nextServiceDate: schedule.scheduledDate,
                    estimatedCost: schedule.estimatedCost,
                    warrantyExpiryDate: nil,
                    seasonalChangeDate: nil,
                    rotationDueKm: nil,
                    replacementDueMonths: nil
                )
            )
            notifications.append(notification)
        }

        // Merge with existing tyre notifications (don't overwrite)
        let tyreTypes: Set<AppNotification.NotificationType> = [
            .pressureAlert, .seasonalReminder, .tyreReplacement, .rotation, .alignment, .inspection, .warranty
        ]
        let existingTyreNotifications = upcomingNotifications.filter { tyreTypes.contains($0.type) }

        upcomingNotifications = existingTyreNotifications + notifications
        saveScheduledNotifications()
        scheduledCount = upcomingNotifications.count
    }

    // MARK: - Persistence

    private func saveScheduledNotifications() {
        if let encoded = try? JSONEncoder().encode(upcomingNotifications) {
            UserDefaults.standard.set(encoded, forKey: "ScheduledPredictiveNotifications")
        }
    }

    private func loadScheduledNotifications() {
        guard let data = UserDefaults.standard.data(forKey: "ScheduledPredictiveNotifications"),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else {
            return
        }
        upcomingNotifications = decoded
        scheduledCount = decoded.count
    }

    // MARK: - Public API

    func clearScheduledNotifications() {
        upcomingNotifications.removeAll()
        saveScheduledNotifications()
        scheduledCount = 0
    }

    func getNotificationsDueWithin(days: Int) -> [AppNotification] {
        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return upcomingNotifications.filter { notification in
            guard let scheduledDate = notification.scheduledDate else { return false }
            return scheduledDate <= targetDate
        }.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    func deleteNotification(notificationId: String) {
        if let index = upcomingNotifications.firstIndex(where: { $0.id == notificationId }) {
            upcomingNotifications.remove(at: index)
            saveScheduledNotifications()
            scheduledCount = upcomingNotifications.count
        }
    }

    // MARK: - Background Sync Integration

    /// Sincronizza con le notifiche ricevute dal server (assicurazioni, bollo, revisioni)
    /// Chiamato dal BackgroundTaskManager dopo il refresh
    func syncWithServerNotifications(_ serverNotifications: [AppNotification]) {
        // Rimuovi notifiche duplicate (già presenti localmente)
        let existingIds = Set(upcomingNotifications.map { $0.id })
        let newNotifications = serverNotifications.filter { !existingIds.contains($0.id) }

        if !newNotifications.isEmpty {
            // Aggiungi le nuove notifiche
            upcomingNotifications.append(contentsOf: newNotifications)

            // Ordina per data schedulata e priorità
            upcomingNotifications.sort { notification1, notification2 in
                if let date1 = notification1.scheduledDate,
                   let date2 = notification2.scheduledDate {
                    if date1 != date2 {
                        return date1 < date2
                    }
                }
                return notification1.priority.sortOrder < notification2.priority.sortOrder
            }

            // Salva le notifiche aggiornate
            saveScheduledNotifications()
            scheduledCount = upcomingNotifications.count

            // Mostra badge notification per nuove notifiche critiche/high priority
            let criticalCount = newNotifications.filter { $0.priority == .critical || $0.priority == .high }.count
            if criticalCount > 0 {
                // Aggiorna il badge dell'app
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewCriticalNotifications"),
                    object: nil,
                    userInfo: ["count": criticalCount]
                )
            }
        }
    }

    /// Marca una notifica come letta
    func markNotificationAsRead(notificationId: String) {
        if let index = upcomingNotifications.firstIndex(where: { $0.id == notificationId }) {
            upcomingNotifications[index].isRead = true
            saveScheduledNotifications()
        }
    }

    /// Ottieni notifiche non lette
    func getUnreadNotifications() -> [AppNotification] {
        return upcomingNotifications.filter { !$0.isRead }
    }

    /// Ottieni conteggio notifiche critiche
    func getCriticalNotificationsCount() -> Int {
        return upcomingNotifications.filter { $0.priority == .critical && !$0.isRead }.count
    }
}
