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

    // MARK: - Maintenance Category
    enum MaintenanceCategory: String, Codable, CaseIterable {
        case tyres = "Pneumatici"
        case engine = "Motore"
        case brakes = "Freni"
        case fluids = "Liquidi"
        case filters = "Filtri"
        case other = "Altro"

        var localizedName: String {
            switch self {
            case .tyres: return String(localized: "maintenance.category.tyres")
            case .engine: return String(localized: "maintenance.category.engine")
            case .brakes: return String(localized: "maintenance.category.brakes")
            case .fluids: return String(localized: "maintenance.category.fluids")
            case .filters: return String(localized: "maintenance.category.filters")
            case .other: return String(localized: "maintenance.category.other")
            }
        }

        var icon: String {
            switch self {
            case .tyres: return "circle.circle"
            case .engine: return "engine.combustion"
            case .brakes: return "brake.signal"
            case .fluids: return "drop.fill"
            case .filters: return "aqi.medium"
            case .other: return "wrench.and.screwdriver"
            }
        }
    }

    // MARK: - Maintenance Type
    enum MaintenanceType: String, Codable, CaseIterable {
        // Pneumatici
        case rotation
        case replacement
        case pressureCheck
        case alignment
        case seasonalChange
        case inspection
        case balancing
        // Motore
        case oilChange
        case sparkPlugs
        case timingBelt
        case clutch
        case generalService
        // Freni
        case brakePads
        case brakeDiscs
        // Liquidi
        case brakeFluid
        case coolant
        case washerFluid
        // Filtri
        case airFilter
        case oilFilter
        case fuelFilter
        case cabinFilter
        // Altro
        case battery
        case shockAbsorbers

        var category: MaintenanceCategory {
            switch self {
            case .rotation, .replacement, .pressureCheck, .alignment, .seasonalChange, .inspection, .balancing:
                return .tyres
            case .oilChange, .sparkPlugs, .timingBelt, .clutch, .generalService:
                return .engine
            case .brakePads, .brakeDiscs:
                return .brakes
            case .brakeFluid, .coolant, .washerFluid:
                return .fluids
            case .airFilter, .oilFilter, .fuelFilter, .cabinFilter:
                return .filters
            case .battery, .shockAbsorbers:
                return .other
            }
        }

        var icon: String {
            switch self {
            case .rotation: return "arrow.clockwise"
            case .replacement: return "arrow.triangle.2.circlepath"
            case .pressureCheck: return "gauge"
            case .alignment: return "align.horizontal.left"
            case .seasonalChange: return "thermometer.snowflake"
            case .inspection: return "magnifyingglass"
            case .balancing: return "scalemass"
            case .oilChange: return "drop.fill"
            case .sparkPlugs: return "bolt.fill"
            case .timingBelt: return "gear"
            case .clutch: return "gearshift.layout.sixspeed"
            case .generalService: return "wrench.and.screwdriver.fill"
            case .brakePads: return "brake.signal"
            case .brakeDiscs: return "circle.dashed"
            case .brakeFluid: return "drop.triangle"
            case .coolant: return "thermometer.medium"
            case .washerFluid: return "wiper.rear.and.fluid"
            case .airFilter: return "wind"
            case .oilFilter: return "line.3.horizontal.decrease.circle"
            case .fuelFilter: return "fuelpump"
            case .cabinFilter: return "air.purifier"
            case .battery: return "battery.100"
            case .shockAbsorbers: return "arrow.up.and.down"
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
            case .oilChange: return Color(red: 0.85, green: 0.65, blue: 0.13)
            case .sparkPlugs: return Color(red: 1.0, green: 0.84, blue: 0.0)
            case .timingBelt: return Color(red: 0.60, green: 0.40, blue: 0.80)
            case .clutch: return Color(red: 0.75, green: 0.35, blue: 0.55)
            case .generalService: return Color(red: 0.30, green: 0.69, blue: 0.31)
            case .brakePads: return Color(red: 0.90, green: 0.30, blue: 0.24)
            case .brakeDiscs: return Color(red: 0.83, green: 0.33, blue: 0.33)
            case .brakeFluid: return Color(red: 0.61, green: 0.15, blue: 0.69)
            case .coolant: return Color(red: 0.13, green: 0.59, blue: 0.95)
            case .washerFluid: return Color(red: 0.40, green: 0.73, blue: 0.94)
            case .airFilter: return Color(red: 0.47, green: 0.87, blue: 0.47)
            case .oilFilter: return Color(red: 0.70, green: 0.55, blue: 0.34)
            case .fuelFilter: return Color(red: 0.95, green: 0.61, blue: 0.07)
            case .cabinFilter: return Color(red: 0.56, green: 0.79, blue: 0.67)
            case .battery: return Color(red: 0.15, green: 0.68, blue: 0.38)
            case .shockAbsorbers: return Color(red: 0.55, green: 0.47, blue: 0.70)
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
            case .oilChange: return String(localized: "maintenance.type.oilChange")
            case .sparkPlugs: return String(localized: "maintenance.type.sparkPlugs")
            case .timingBelt: return String(localized: "maintenance.type.timingBelt")
            case .clutch: return String(localized: "maintenance.type.clutch")
            case .generalService: return String(localized: "maintenance.type.generalService")
            case .brakePads: return String(localized: "maintenance.type.brakePads")
            case .brakeDiscs: return String(localized: "maintenance.type.brakeDiscs")
            case .brakeFluid: return String(localized: "maintenance.type.brakeFluid")
            case .coolant: return String(localized: "maintenance.type.coolant")
            case .washerFluid: return String(localized: "maintenance.type.washerFluid")
            case .airFilter: return String(localized: "maintenance.type.airFilter")
            case .oilFilter: return String(localized: "maintenance.type.oilFilter")
            case .fuelFilter: return String(localized: "maintenance.type.fuelFilter")
            case .cabinFilter: return String(localized: "maintenance.type.cabinFilter")
            case .battery: return String(localized: "maintenance.type.battery")
            case .shockAbsorbers: return String(localized: "maintenance.type.shockAbsorbers")
            }
        }

        /// Group all types by category for UI pickers
        static var groupedByCategory: [(category: MaintenanceCategory, types: [MaintenanceType])] {
            MaintenanceCategory.allCases.map { category in
                (category: category, types: allCases.filter { $0.category == category })
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
            case .low: return String(localized: "maintenance.priority.low")
            case .medium: return String(localized: "maintenance.priority.medium")
            case .high: return String(localized: "maintenance.priority.high")
            case .critical: return String(localized: "maintenance.priority.critical")
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
