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
}
