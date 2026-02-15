//
//  AppNotification.swift
//  TyreVibes
//
//  Created on 2025-10-04.
//  In-app notification model
//

import Foundation
import SwiftUI

struct AppNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let vehicleId: String?
    let tyreId: String?
    let priority: Priority
    let actionRequired: Bool
    let scheduledDate: Date?
    let predictedDate: Date?
    let metadata: NotificationMetadata?

    enum Priority: String, Codable {
        case low
        case medium
        case high
        case critical

        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }

    struct NotificationMetadata: Codable {
        let treadDepth: Double?
        let pressurePSI: Double?
        let mileage: Int?
        let lastServiceDate: Date?
        let nextServiceDate: Date?
        let estimatedCost: Double?
        let warrantyExpiryDate: Date?
        let seasonalChangeDate: Date?
        let rotationDueKm: Int?
        let replacementDueMonths: Int?
    }

    enum NotificationType: String, Codable {
        case pressureAlert
        case seasonalReminder
        case maintenanceReminder
        case specialOffer
        case tyreReplacement
        case rotation
        case alignment
        case inspection
        case warranty
        // Mechanical maintenance reminders
        case oilChangeReminder
        case filterReminder
        case brakeReminder
        case batteryReminder
        case generalMaintenanceReminder

        var icon: String {
            switch self {
            case .pressureAlert: return "exclamationmark.triangle.fill"
            case .seasonalReminder: return "checkmark.circle.fill"
            case .maintenanceReminder: return "bell.fill"
            case .specialOffer: return "bag.fill"
            case .tyreReplacement: return "arrow.triangle.2.circlepath"
            case .rotation: return "arrow.clockwise"
            case .alignment: return "align.horizontal.left"
            case .inspection: return "magnifyingglass"
            case .warranty: return "shield.fill"
            case .oilChangeReminder: return "drop.fill"
            case .filterReminder: return "aqi.medium"
            case .brakeReminder: return "brake.signal"
            case .batteryReminder: return "battery.100"
            case .generalMaintenanceReminder: return "wrench.and.screwdriver.fill"
            }
        }

        var color: Color {
            switch self {
            case .pressureAlert: return Color(red: 1.0, green: 0.27, blue: 0.23)
            case .seasonalReminder: return Color(red: 0.0, green: 0.78, blue: 0.75)
            case .maintenanceReminder: return Color(red: 0.56, green: 0.56, blue: 0.58)
            case .specialOffer: return Color(red: 0.20, green: 0.78, blue: 0.35)
            case .tyreReplacement: return Color(red: 1.0, green: 0.58, blue: 0.0)
            case .rotation: return Color(red: 0.0, green: 0.48, blue: 1.0)
            case .alignment: return Color(red: 0.35, green: 0.34, blue: 0.84)
            case .inspection: return Color(red: 1.0, green: 0.80, blue: 0.0)
            case .warranty: return Color(red: 0.55, green: 0.27, blue: 0.07)
            case .oilChangeReminder: return Color(red: 0.85, green: 0.65, blue: 0.13)
            case .filterReminder: return Color(red: 0.47, green: 0.87, blue: 0.47)
            case .brakeReminder: return Color(red: 0.90, green: 0.30, blue: 0.24)
            case .batteryReminder: return Color(red: 0.15, green: 0.68, blue: 0.38)
            case .generalMaintenanceReminder: return Color(red: 0.30, green: 0.69, blue: 0.31)
            }
        }

        var localizedName: String {
            switch self {
            case .pressureAlert: return String(localized: "notification.type.pressureAlert")
            case .seasonalReminder: return String(localized: "notification.type.seasonalReminder")
            case .maintenanceReminder: return String(localized: "notification.type.maintenanceReminder")
            case .specialOffer: return String(localized: "notification.type.specialOffer")
            case .tyreReplacement: return String(localized: "notification.type.tyreReplacement")
            case .rotation: return String(localized: "notification.type.rotation")
            case .alignment: return String(localized: "notification.type.alignment")
            case .inspection: return String(localized: "notification.type.inspection")
            case .warranty: return String(localized: "notification.type.warranty")
            case .oilChangeReminder: return String(localized: "notification.type.oilChangeReminder")
            case .filterReminder: return String(localized: "notification.type.filterReminder")
            case .brakeReminder: return String(localized: "notification.type.brakeReminder")
            case .batteryReminder: return String(localized: "notification.type.batteryReminder")
            case .generalMaintenanceReminder: return String(localized: "notification.type.generalMaintenanceReminder")
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        message: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        vehicleId: String? = nil,
        tyreId: String? = nil,
        priority: Priority = .medium,
        actionRequired: Bool = false,
        scheduledDate: Date? = nil,
        predictedDate: Date? = nil,
        metadata: NotificationMetadata? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.vehicleId = vehicleId
        self.tyreId = tyreId
        self.priority = priority
        self.actionRequired = actionRequired
        self.scheduledDate = scheduledDate
        self.predictedDate = predictedDate
        self.metadata = metadata
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Sample Data
extension AppNotification {
    static let samples: [AppNotification] = [
        AppNotification(
            type: .pressureAlert,
            title: "Tire Pressure Alert",
            message: "Rear left tire pressure is low by 5 PSI. Check and inflate as soon as possible.",
            timestamp: Date().addingTimeInterval(-7200),
            isRead: false
        ),
        AppNotification(
            type: .seasonalReminder,
            title: "Seasonal Change Reminder",
            message: "Winter is approaching. Time to consider switching to winter tires in the next 2 weeks.",
            timestamp: Date().addingTimeInterval(-86400),
            isRead: false
        ),
        AppNotification(
            type: .maintenanceReminder,
            title: "Maintenance Reminder",
            message: "Your Toyota Camry is due for tire rotation. Schedule service soon.",
            timestamp: Date().addingTimeInterval(-259200),
            isRead: false
        ),
        AppNotification(
            type: .specialOffer,
            title: "Special Offer Available",
            message: "Based on your tire condition, you qualify for 15% off on Michelin tires at partner stores.",
            timestamp: Date().addingTimeInterval(-604800),
            isRead: false
        )
    ]
}
