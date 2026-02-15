import Foundation

enum DueTrigger: String {
    case km
    case time
    case none
}

@MainActor
class SmartMaintenanceScheduler: ObservableObject {
    static let shared = SmartMaintenanceScheduler()

    private init() {}

    /// Evaluate all maintenance intervals for a vehicle and create/update schedules
    func evaluateAndSchedule(vehicleId: Int) {
        let intervalStore = MaintenanceIntervalStore.shared
        let historyStore = MaintenanceHistoryStore.shared
        let scheduleStore = MaintenanceScheduleStore.shared
        let mileageStore = VehicleMileageStore.shared

        intervalStore.seedDefaultsIfNeeded()

        let intervals = intervalStore.intervals(for: vehicleId)
        let history = historyStore.entries(for: vehicleId)
        let currentKm = mileageStore.mileage(for: vehicleId)
        let avgKmPerMonth = mileageStore.averageKmPerMonth(for: vehicleId)

        // Get already-scheduled types to avoid duplicates
        let existingSchedules = scheduleStore.schedules(for: vehicleId)
        let scheduledTypes = Set(existingSchedules.map(\.type))

        for interval in intervals {
            // Skip if already scheduled
            guard !scheduledTypes.contains(interval.maintenanceType) else { continue }

            // Find last completion of this type
            let lastEntry = history
                .filter { $0.maintenanceType == interval.maintenanceType }
                .sorted { $0.date > $1.date }
                .first

            let (nextDate, trigger) = calculateNextDue(
                interval: interval,
                lastDate: lastEntry?.date,
                lastMileage: lastEntry?.mileage,
                currentMileage: currentKm,
                avgKmPerMonth: avgKmPerMonth
            )

            guard let dueDate = nextDate else { continue }

            let priority = priorityForDueDate(dueDate)

            scheduleStore.addSchedule(
                vehicleId: vehicleId,
                type: interval.maintenanceType,
                title: interval.maintenanceType.localizedName,
                description: descriptionForInterval(interval, trigger: trigger),
                scheduledDate: dueDate,
                estimatedCost: estimatedCostForType(interval.maintenanceType),
                priority: priority
            )
        }
    }

    /// Calculate next due date using "whichever comes first" logic
    func calculateNextDue(
        interval: MaintenanceInterval,
        lastDate: Date?,
        lastMileage: Int?,
        currentMileage: Int?,
        avgKmPerMonth: Int?
    ) -> (date: Date?, trigger: DueTrigger) {
        var timeDueDate: Date?
        var kmDueDate: Date?

        // Time-based calculation
        if let months = interval.monthsInterval {
            let baseDate = lastDate ?? Date()
            timeDueDate = Calendar.current.date(byAdding: .month, value: months, to: baseDate)
        }

        // Km-based calculation (project when km threshold will be reached)
        if let kmInterval = interval.kmInterval,
           let currentKm = currentMileage {
            let lastKm = lastMileage ?? 0
            let kmSinceLast = currentKm - lastKm
            let kmRemaining = kmInterval - kmSinceLast

            if kmRemaining <= 0 {
                // Already overdue by km
                kmDueDate = Date()
            } else if let avgKm = avgKmPerMonth, avgKm > 0 {
                // Project future date based on average usage
                let monthsUntilDue = Double(kmRemaining) / Double(avgKm)
                let daysUntilDue = Int(monthsUntilDue * 30.44) // avg days/month
                kmDueDate = Calendar.current.date(byAdding: .day, value: daysUntilDue, to: Date())
            }
        }

        // "Whichever comes first" logic
        switch (timeDueDate, kmDueDate) {
        case (let time?, let km?):
            if km < time {
                return (km, .km)
            } else {
                return (time, .time)
            }
        case (let time?, nil):
            return (time, .time)
        case (nil, let km?):
            return (km, .km)
        case (nil, nil):
            return (nil, .none)
        }
    }

    // MARK: - Helpers

    private func priorityForDueDate(_ dueDate: Date) -> MaintenanceSchedule.Priority {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntil < 0 {
            return daysUntil < -30 ? .critical : .high
        } else if daysUntil <= 7 {
            return .medium
        } else {
            return .low
        }
    }

    private func descriptionForInterval(_ interval: MaintenanceInterval, trigger: DueTrigger) -> String {
        var parts: [String] = []

        if let km = interval.kmInterval {
            parts.append("Ogni \(km.formatted()) km")
        }
        if let months = interval.monthsInterval {
            parts.append("ogni \(months) mesi")
        }

        let base = parts.joined(separator: " o ")

        switch trigger {
        case .km:
            return "\(base). Scadenza calcolata in base ai km percorsi."
        case .time:
            return "\(base). Scadenza calcolata in base al tempo."
        case .none:
            return base.isEmpty ? "Intervento programmato automaticamente." : base + "."
        }
    }

    private func estimatedCostForType(_ type: MaintenanceSchedule.MaintenanceType) -> Double? {
        switch type {
        case .oilChange: return 80
        case .airFilter: return 25
        case .oilFilter: return 15
        case .fuelFilter: return 40
        case .cabinFilter: return 30
        case .brakePads: return 150
        case .brakeDiscs: return 300
        case .timingBelt: return 600
        case .battery: return 120
        case .shockAbsorbers: return 400
        case .brakeFluid: return 60
        case .coolant: return 50
        case .washerFluid: return 10
        case .sparkPlugs: return 80
        case .clutch: return 800
        case .generalService: return 250
        case .rotation: return 45
        case .replacement: return 380
        case .pressureCheck: return 15
        case .alignment: return 60
        case .seasonalChange: return 80
        case .inspection: return 25
        case .balancing: return 40
        }
    }
}
