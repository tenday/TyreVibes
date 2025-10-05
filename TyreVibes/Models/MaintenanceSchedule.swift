//
//  MaintenanceSchedule.swift
//  TyreVibes
//
//  Created on 2025-10-04.
//  Model for scheduled maintenance
//

import Foundation
import SwiftUI

struct MaintenanceSchedule: Identifiable, Codable {
    let id: String
    let type: MaintenanceType
    let title: String
    let description: String
    let scheduledDate: Date
    let estimatedCost: Double?
    let priority: Priority
    let vehicleId: String
    let tyreId: String?
    let metadata: MaintenanceMetadata?

    enum MaintenanceType: String, Codable {
        case rotation
        case replacement
        case pressureCheck
        case alignment
        case seasonalChange
        case inspection
        case balancing

        var icon: String {
            switch self {
            case .rotation: return "arrow.clockwise"
            case .replacement: return "arrow.triangle.2.circlepath"
            case .pressureCheck: return "gauge"
            case .alignment: return "align.horizontal.left"
            case .seasonalChange: return "thermometer.snowflake"
            case .inspection: return "magnifyingglass"
            case .balancing: return "scalemass"
            }
        }

        var color: Color {
            switch self {
            case .rotation: return Color(red: 0.0, green: 0.48, blue: 1.0)
            case .replacement: return Color(red: 1.0, green: 0.58, blue: 0.0)
            case .pressureCheck: return Color(red: 0.0, green: 0.78, blue: 0.75)
            case .alignment: return Color(red: 0.35, green: 0.34, blue: 0.84)
            case .seasonalChange: return Color(red: 0.53, green: 0.81, blue: 0.98)
            case .inspection: return Color(red: 1.0, green: 0.80, blue: 0.0)
            case .balancing: return Color(red: 0.56, green: 0.56, blue: 0.58)
            }
        }

        var localizedName: String {
            switch self {
            case .rotation: return String(localized: "maintenance.type.rotation")
            case .replacement: return String(localized: "maintenance.type.replacement")
            case .pressureCheck: return String(localized: "maintenance.type.pressureCheck")
            case .alignment: return String(localized: "maintenance.type.alignment")
            case .seasonalChange: return String(localized: "maintenance.type.seasonalChange")
            case .inspection: return String(localized: "maintenance.type.inspection")
            case .balancing: return String(localized: "maintenance.type.balancing")
            }
        }
    }

    enum Priority: String, Codable {
        case low
        case medium
        case high
        case critical

        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .critical: return .red
            }
        }

        var label: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }

    struct MaintenanceMetadata: Codable {
        let currentTreadDepth: Double?
        let targetTreadDepth: Double?
        let currentMileage: Int?
        let targetMileage: Int?
        let lastServiceDate: Date?
        let dueInDays: Int?
        let dueInKm: Int?
    }

    init(
        id: String = UUID().uuidString,
        type: MaintenanceType,
        title: String,
        description: String,
        scheduledDate: Date,
        estimatedCost: Double? = nil,
        priority: Priority = .medium,
        vehicleId: String,
        tyreId: String? = nil,
        metadata: MaintenanceMetadata? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.scheduledDate = scheduledDate
        self.estimatedCost = estimatedCost
        self.priority = priority
        self.vehicleId = vehicleId
        self.tyreId = tyreId
        self.metadata = metadata
    }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: scheduledDate).day ?? 0
    }

    var monthsUntil: Int {
        Calendar.current.dateComponents([.month], from: Date(), to: scheduledDate).month ?? 0
    }

    var isOverdue: Bool {
        return scheduledDate < Date()
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: scheduledDate)
    }

    var relativeTimeString: String {
        if isOverdue {
            return String(localized: "maintenance.overdue")
        }

        let days = daysUntil
        if days == 0 {
            return String(localized: "maintenance.today")
        } else if days == 1 {
            return String(localized: "maintenance.tomorrow")
        } else if days <= 7 {
            return String(localized: "maintenance.inDays \(days)")
        } else if days <= 30 {
            let weeks = days / 7
            return String(localized: "maintenance.inWeeks \(weeks)")
        } else {
            let months = monthsUntil
            return String(localized: "maintenance.inMonths \(months)")
        }
    }
}

// MARK: - Sample Data
extension MaintenanceSchedule {
    static let samples: [MaintenanceSchedule] = [
        MaintenanceSchedule(
            type: .rotation,
            title: "Tyre Rotation",
            description: "Rotate tyres to ensure even wear",
            scheduledDate: Date().addingTimeInterval(14 * 24 * 3600),
            estimatedCost: 50.0,
            priority: .medium,
            vehicleId: "vehicle1",
            metadata: MaintenanceMetadata(
                currentTreadDepth: nil,
                targetTreadDepth: nil,
                currentMileage: 45000,
                targetMileage: 50000,
                lastServiceDate: Date().addingTimeInterval(-90 * 24 * 3600),
                dueInDays: 14,
                dueInKm: 5000
            )
        ),
        MaintenanceSchedule(
            type: .seasonalChange,
            title: "Winter Tyre Change",
            description: "Switch to winter tyres for the cold season",
            scheduledDate: Date().addingTimeInterval(45 * 24 * 3600),
            estimatedCost: 100.0,
            priority: .high,
            vehicleId: "vehicle1"
        ),
        MaintenanceSchedule(
            type: .replacement,
            title: "Tyre Replacement",
            description: "Replace worn tyres based on tread depth analysis",
            scheduledDate: Date().addingTimeInterval(90 * 24 * 3600),
            estimatedCost: 400.0,
            priority: .high,
            vehicleId: "vehicle1",
            metadata: MaintenanceMetadata(
                currentTreadDepth: 4.2,
                targetTreadDepth: 3.0,
                currentMileage: 45000,
                targetMileage: 55000,
                lastServiceDate: nil,
                dueInDays: 90,
                dueInKm: 10000
            )
        )
    ]
}
