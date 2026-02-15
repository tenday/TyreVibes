import Foundation
import SwiftUI

@MainActor
class MaintenanceCostViewModel: ObservableObject {
    let vehicleId: Int

    @Published var totalCost: Double = 0
    @Published var costByCategory: [(category: String, cost: Double, color: Color)] = []
    @Published var monthlyTrend: [(month: Date, cost: Double)] = []
    @Published var costPerKm: Double = 0
    @Published var selectedTimeRange: TimeRange = .year

    enum TimeRange: String, CaseIterable {
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1A"
        case allTime = "Tutto"

        var localizedLabel: String {
            switch self {
            case .threeMonths: return String(localized: "maintenance.timeRange.threeMonths")
            case .sixMonths: return String(localized: "maintenance.timeRange.sixMonths")
            case .year: return String(localized: "maintenance.timeRange.year")
            case .allTime: return String(localized: "maintenance.timeRange.allTime")
            }
        }

        var months: Int? {
            switch self {
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .year: return 12
            case .allTime: return nil
            }
        }
    }

    private var allEntries: [CompletedMaintenanceEntry] {
        MaintenanceHistoryStore.shared.entries(for: vehicleId)
    }

    private var filteredEntries: [CompletedMaintenanceEntry] {
        guard let months = selectedTimeRange.months else { return allEntries }
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
        return allEntries.filter { $0.date >= cutoff }
    }

    init(vehicleId: Int) {
        self.vehicleId = vehicleId
        loadData()
    }

    func loadData() {
        let entries = filteredEntries

        // Total cost
        totalCost = entries.compactMap(\.cost).reduce(0, +)

        // Cost by category
        var categoryMap: [MaintenanceSchedule.MaintenanceCategory: Double] = [:]
        for entry in entries {
            guard let cost = entry.cost, let type = entry.maintenanceType else { continue }
            categoryMap[type.category, default: 0] += cost
        }
        costByCategory = categoryMap
            .map { (category: $0.key.localizedName, cost: $0.value, color: colorForCategory($0.key)) }
            .sorted { $0.cost > $1.cost }

        // Monthly trend
        let calendar = Calendar.current
        var monthMap: [Date: Double] = [:]
        for entry in entries {
            guard let cost = entry.cost else { continue }
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            let monthStart = calendar.date(from: components) ?? entry.date
            monthMap[monthStart, default: 0] += cost
        }
        monthlyTrend = monthMap
            .map { (month: $0.key, cost: $0.value) }
            .sorted { $0.month < $1.month }

        // Cost per km
        let mileageStore = VehicleMileageStore.shared
        if let currentKm = mileageStore.mileage(for: vehicleId) {
            let history = mileageStore.mileageHistory(for: vehicleId)
            if let firstEntry = history.first, currentKm > firstEntry.km {
                let kmDriven = currentKm - firstEntry.km
                if kmDriven > 0 {
                    costPerKm = totalCost / Double(kmDriven)
                }
            }
        }
    }

    func onTimeRangeChanged() {
        loadData()
    }

    private func colorForCategory(_ category: MaintenanceSchedule.MaintenanceCategory) -> Color {
        switch category {
        case .tyres: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .engine: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .brakes: return Color(red: 0.90, green: 0.30, blue: 0.24)
        case .fluids: return Color(red: 0.61, green: 0.15, blue: 0.69)
        case .filters: return Color(red: 0.47, green: 0.87, blue: 0.47)
        case .other: return Color(red: 0.55, green: 0.47, blue: 0.70)
        }
    }
}
