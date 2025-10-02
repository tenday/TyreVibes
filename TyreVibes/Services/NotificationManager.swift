//
//  NotificationManager.swift
//  TyreVibes
//
//  Created on 2025-10-02.
//  Scalable notification management system
//

import Foundation
import UserNotifications
import Combine

/// Scalable notification manager with flexible configuration
class NotificationManager: NSObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Types

    enum NotificationType: String, CaseIterable {
        case tyreInspection = "tyre_inspection"
        case tyreReplacement = "tyre_replacement"
        case pressureCheck = "pressure_check"
        case rotation = "tyre_rotation"
        case alignment = "wheel_alignment"
        case seasonal = "seasonal_change"
        case warranty = "warranty_expiry"
        case custom = "custom"

        var category: String {
            return rawValue
        }
    }

    struct NotificationConfig {
        let type: NotificationType
        let title: String
        let body: String
        let identifier: String?
        let badge: Int?
        let sound: UNNotificationSound
        let userInfo: [String: Any]
        let attachments: [UNNotificationAttachment]
        let categoryIdentifier: String?
        let threadIdentifier: String?
        let launchImageName: String?

        init(
            type: NotificationType,
            title: String,
            body: String,
            identifier: String? = nil,
            badge: Int? = nil,
            sound: UNNotificationSound = .default,
            userInfo: [String: Any] = [:],
            attachments: [UNNotificationAttachment] = [],
            categoryIdentifier: String? = nil,
            threadIdentifier: String? = nil,
            launchImageName: String? = nil
        ) {
            self.type = type
            self.title = title
            self.body = body
            self.identifier = identifier ?? UUID().uuidString
            self.badge = badge
            self.sound = sound
            self.userInfo = userInfo
            self.attachments = attachments
            self.categoryIdentifier = categoryIdentifier ?? type.category
            self.threadIdentifier = threadIdentifier
            self.launchImageName = launchImageName
        }
    }

    struct ScheduledNotification: Codable {
        let identifier: String
        let type: String
        let title: String
        let body: String
        let scheduledDate: Date
        let repeatInterval: TimeInterval?
        let isRecurring: Bool
    }

    enum NotificationAction: String {
        case viewDetails = "VIEW_DETAILS"
        case snooze = "SNOOZE"
        case complete = "COMPLETE"
        case dismiss = "DISMISS"
        case scheduleService = "SCHEDULE_SERVICE"
        case viewTyreInfo = "VIEW_TYRE_INFO"

        var title: String {
            switch self {
            case .viewDetails: return "Visualizza"
            case .snooze: return "Posticipa"
            case .complete: return "Completato"
            case .dismiss: return "Ignora"
            case .scheduleService: return "Prenota"
            case .viewTyreInfo: return "Info Pneumatico"
            }
        }
    }

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()
    private var notificationHandlers: [String: (UNNotificationResponse) -> Void] = [:]
    private var scheduledNotifications: [String: ScheduledNotification] = [:]

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingNotificationsCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        center.delegate = self
        loadScheduledNotifications()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]

        do {
            let granted = try await center.requestAuthorization(options: options)
            await updateAuthorizationStatus()

            if granted {
                await registerCategories()
            }

            return granted
        } catch {
            throw error
        }
    }

    func checkAuthorizationStatus() {
        Task {
            await updateAuthorizationStatus()
        }
    }

    @MainActor
    private func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Scheduling Notifications

    /// Schedule immediate notification
    func scheduleImmediate(_ config: NotificationConfig) async throws {
        let content = createNotificationContent(from: config)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: config.identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        await updatePendingCount()
    }

    /// Schedule notification at specific date
    func schedule(
        _ config: NotificationConfig,
        at date: Date,
        repeating: Calendar.Component? = nil
    ) async throws {
        let content = createNotificationContent(from: config)

        let trigger: UNNotificationTrigger

        if let component = repeating {
            let dateComponents = Calendar.current.dateComponents(
                getComponentSet(for: component),
                from: date
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: config.identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        // Store scheduled notification
        let scheduled = ScheduledNotification(
            identifier: request.identifier,
            type: config.type.rawValue,
            title: config.title,
            body: config.body,
            scheduledDate: date,
            repeatInterval: repeating != nil ? date.timeIntervalSince(Date()) : nil,
            isRecurring: repeating != nil
        )

        scheduledNotifications[request.identifier] = scheduled
        saveScheduledNotifications()

        try await center.add(request)
        await updatePendingCount()
    }

    /// Schedule notification after time interval
    func schedule(
        _ config: NotificationConfig,
        after interval: TimeInterval,
        repeating: Bool = false
    ) async throws {
        let content = createNotificationContent(from: config)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: repeating)

        let request = UNNotificationRequest(
            identifier: config.identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let scheduled = ScheduledNotification(
            identifier: request.identifier,
            type: config.type.rawValue,
            title: config.title,
            body: config.body,
            scheduledDate: Date().addingTimeInterval(interval),
            repeatInterval: repeating ? interval : nil,
            isRecurring: repeating
        )

        scheduledNotifications[request.identifier] = scheduled
        saveScheduledNotifications()

        try await center.add(request)
        await updatePendingCount()
    }

    // MARK: - Recurring Notifications

    /// Schedule daily notification
    func scheduleDaily(_ config: NotificationConfig, at time: DateComponents) async throws {
        let content = createNotificationContent(from: config)
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        let request = UNNotificationRequest(
            identifier: config.identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let scheduled = ScheduledNotification(
            identifier: request.identifier,
            type: config.type.rawValue,
            title: config.title,
            body: config.body,
            scheduledDate: Date(),
            repeatInterval: 24 * 3600,
            isRecurring: true
        )

        scheduledNotifications[request.identifier] = scheduled
        saveScheduledNotifications()

        try await center.add(request)
        await updatePendingCount()
    }

    /// Schedule weekly notification
    func scheduleWeekly(
        _ config: NotificationConfig,
        on weekday: Int,
        at time: DateComponents
    ) async throws {
        var dateComponents = time
        dateComponents.weekday = weekday

        let content = createNotificationContent(from: config)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: config.identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let scheduled = ScheduledNotification(
            identifier: request.identifier,
            type: config.type.rawValue,
            title: config.title,
            body: config.body,
            scheduledDate: Date(),
            repeatInterval: 7 * 24 * 3600,
            isRecurring: true
        )

        scheduledNotifications[request.identifier] = scheduled
        saveScheduledNotifications()

        try await center.add(request)
        await updatePendingCount()
    }

    // MARK: - Management

    /// Cancel notification by identifier
    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledNotifications.removeValue(forKey: identifier)
        saveScheduledNotifications()

        Task {
            await updatePendingCount()
        }
    }

    /// Cancel all notifications of a specific type
    func cancel(type: NotificationType) async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .filter { request in
                guard let userInfo = request.content.userInfo as? [String: String] else { return false }
                return userInfo["type"] == type.rawValue
            }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        identifiers.forEach { scheduledNotifications.removeValue(forKey: $0) }
        saveScheduledNotifications()

        await updatePendingCount()
    }

    /// Cancel all notifications
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        scheduledNotifications.removeAll()
        saveScheduledNotifications()

        Task {
            await updatePendingCount()
        }
    }

    /// Get all pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }

    /// Get pending notifications by type
    func getPendingNotifications(ofType type: NotificationType) async -> [UNNotificationRequest] {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { request in
            guard let userInfo = request.content.userInfo as? [String: String] else { return false }
            return userInfo["type"] == type.rawValue
        }
    }

    /// Remove delivered notifications
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Clear all delivered notifications
    func clearAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Badge Management

    func setBadgeCount(_ count: Int) async {
        do {
            try await center.setBadgeCount(count)
        } catch {
            // Handle or log the error without throwing to avoid breaking callers
            print("Failed to set badge count: \(error)")
        }
    }

    func clearBadge() async {
        do {
            try await center.setBadgeCount(0)
        } catch {
            // Handle or log the error without throwing to avoid breaking callers
            print("Failed to clear badge count: \(error)")
        }
    }

    // MARK: - Action Handlers

    func registerHandler(
        for action: NotificationAction,
        handler: @escaping (UNNotificationResponse) -> Void
    ) {
        notificationHandlers[action.rawValue] = handler
    }

    func unregisterHandler(for action: NotificationAction) {
        notificationHandlers.removeValue(forKey: action.rawValue)
    }

    // MARK: - Private Methods

    private func createNotificationContent(from config: NotificationConfig) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        content.title = config.title
        content.body = config.body
        content.sound = config.sound

        if let badge = config.badge {
            content.badge = NSNumber(value: badge)
        }

        var userInfo = config.userInfo
        userInfo["type"] = config.type.rawValue
        content.userInfo = userInfo

        content.attachments = config.attachments

        if let categoryIdentifier = config.categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }

        if let threadIdentifier = config.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        if let launchImageName = config.launchImageName {
            content.launchImageName = launchImageName
        }

        return content
    }

    private func registerCategories() async {
        var categories: Set<UNNotificationCategory> = []

        // Tyre Inspection Category
        let inspectionActions = [
            UNNotificationAction(
                identifier: NotificationAction.viewDetails.rawValue,
                title: NotificationAction.viewDetails.title,
                options: .foreground
            ),
            UNNotificationAction(
                identifier: NotificationAction.snooze.rawValue,
                title: NotificationAction.snooze.title,
                options: []
            ),
            UNNotificationAction(
                identifier: NotificationAction.complete.rawValue,
                title: NotificationAction.complete.title,
                options: .destructive
            )
        ]

        let inspectionCategory = UNNotificationCategory(
            identifier: NotificationType.tyreInspection.category,
            actions: inspectionActions,
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(inspectionCategory)

        // Tyre Replacement Category
        let replacementActions = [
            UNNotificationAction(
                identifier: NotificationAction.scheduleService.rawValue,
                title: NotificationAction.scheduleService.title,
                options: .foreground
            ),
            UNNotificationAction(
                identifier: NotificationAction.viewTyreInfo.rawValue,
                title: NotificationAction.viewTyreInfo.title,
                options: .foreground
            ),
            UNNotificationAction(
                identifier: NotificationAction.dismiss.rawValue,
                title: NotificationAction.dismiss.title,
                options: []
            )
        ]

        let replacementCategory = UNNotificationCategory(
            identifier: NotificationType.tyreReplacement.category,
            actions: replacementActions,
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(replacementCategory)

        // Pressure Check Category
        let pressureActions = [
            UNNotificationAction(
                identifier: NotificationAction.complete.rawValue,
                title: NotificationAction.complete.title,
                options: .destructive
            ),
            UNNotificationAction(
                identifier: NotificationAction.snooze.rawValue,
                title: NotificationAction.snooze.title,
                options: []
            )
        ]

        let pressureCategory = UNNotificationCategory(
            identifier: NotificationType.pressureCheck.category,
            actions: pressureActions,
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(pressureCategory)

        // Register all categories
        center.setNotificationCategories(categories)
    }

    private func getComponentSet(for component: Calendar.Component) -> Set<Calendar.Component> {
        switch component {
        case .day:
            return [.hour, .minute, .second]
        case .weekday:
            return [.weekday, .hour, .minute, .second]
        case .month:
            return [.day, .hour, .minute, .second]
        case .year:
            return [.month, .day, .hour, .minute, .second]
        default:
            return [.hour, .minute, .second]
        }
    }

    @MainActor
    private func updatePendingCount() async {
        let pending = await center.pendingNotificationRequests()
        pendingNotificationsCount = pending.count
    }

    // MARK: - Persistence

    private func saveScheduledNotifications() {
        let array = Array(scheduledNotifications.values)
        if let encoded = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(encoded, forKey: "ScheduledNotifications")
        }
    }

    private func loadScheduledNotifications() {
        guard let data = UserDefaults.standard.data(forKey: "ScheduledNotifications"),
              let decoded = try? JSONDecoder().decode([ScheduledNotification].self, from: data) else {
            return
        }

        scheduledNotifications = Dictionary(uniqueKeysWithValues: decoded.map { ($0.identifier, $0) })
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        // Handle default action (tap on notification)
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Navigate to appropriate screen based on notification type
            if let userInfo = response.notification.request.content.userInfo as? [String: Any],
               let type = userInfo["type"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NotificationTapped"),
                    object: nil,
                    userInfo: ["type": type, "response": response]
                )
            }
        } else if let handler = notificationHandlers[actionIdentifier] {
            // Execute registered handler
            handler(response)
        }

        completionHandler()
    }
}

