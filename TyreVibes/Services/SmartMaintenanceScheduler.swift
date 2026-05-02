import Foundation

enum DueTrigger: String {
    case km
    case time
    case none
}

@MainActor
class SmartMaintenanceScheduler: ObservableObject {
    static let shared = SmartMaintenanceScheduler()

    private let fallbackKmPerMonth = 1_000

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

        guard currentKm != nil || !history.isEmpty else {
            return
        }

        // Get already-scheduled types to avoid duplicate manual plans.
        let existingSchedules = scheduleStore.schedules(for: vehicleId)

        for interval in intervals {
            if let existing = existingSchedules.first(where: { $0.type == interval.maintenanceType }),
               !scheduleStore.canReplaceWithAutomaticSchedule(existing) {
                continue
            }

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

            let targetMileage = targetMileageForInterval(
                interval,
                lastMileage: lastEntry?.mileage,
                currentMileage: currentKm
            )
            let dueInKm = targetMileage.flatMap { target -> Int? in
                guard let currentKm else { return nil }
                return target - currentKm
            }

            let priority = priorityForDueDate(dueDate, dueInKm: dueInKm)

            scheduleStore.upsertAutomaticSchedule(
                vehicleId: vehicleId,
                type: interval.maintenanceType,
                title: interval.maintenanceType.localizedName,
                description: descriptionForInterval(
                    interval,
                    trigger: trigger,
                    currentMileage: currentKm,
                    targetMileage: targetMileage,
                    usedFallbackAverage: avgKmPerMonth == nil && trigger == .km
                ),
                scheduledDate: dueDate,
                estimatedCost: estimatedCostForType(interval.maintenanceType),
                priority: priority,
                currentMileage: currentKm,
                targetMileage: targetMileage,
                lastServiceDate: lastEntry?.date,
                dueInKm: dueInKm
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

        // Time-based calculation is meaningful only after a known service date.
        if let months = interval.monthsInterval,
           let baseDate = lastDate {
            timeDueDate = Calendar.current.date(byAdding: .month, value: months, to: baseDate)
        }

        // Km-based calculation uses the user's current mileage and the real service interval.
        if let kmInterval = interval.kmInterval,
           let currentKm = currentMileage {
            let targetKm: Int

            if let lastMileage {
                targetKm = lastMileage + kmInterval
            } else {
                targetKm = nextMileageMilestone(currentMileage: currentKm, interval: kmInterval)
            }

            let kmRemaining = targetKm - currentKm

            if kmRemaining <= 0 {
                // Already overdue by km
                kmDueDate = Date()
            } else {
                // Project future date based on average usage
                let monthlyKm = max(avgKmPerMonth ?? fallbackKmPerMonth, 1)
                let monthsUntilDue = Double(kmRemaining) / Double(monthlyKm)
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

    private func priorityForDueDate(_ dueDate: Date, dueInKm: Int?) -> MaintenanceSchedule.Priority {
        if let dueInKm {
            if dueInKm <= 0 { return .critical }
            if dueInKm <= 500 { return .high }
            if dueInKm <= 2_000 { return .medium }
        }

        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntil < 0 {
            return daysUntil < -30 ? .critical : .high
        } else if daysUntil <= 7 {
            return .medium
        } else {
            return .low
        }
    }

    private func descriptionForInterval(
        _ interval: MaintenanceInterval,
        trigger: DueTrigger,
        currentMileage: Int?,
        targetMileage: Int?,
        usedFallbackAverage: Bool
    ) -> String {
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
            var reason = "\(base). Scadenza stimata sui km inseriti"
            if let currentMileage, let targetMileage {
                reason += ": \(currentMileage.formatted())/\(targetMileage.formatted()) km"
            }
            if usedFallbackAverage {
                reason += ". Inserisci più letture km per affinare la data."
            }
            return reason + "."
        case .time:
            return "\(base). Scadenza calcolata in base al tempo."
        case .none:
            return base.isEmpty ? "Intervento programmato automaticamente." : base + "."
        }
    }

    private func targetMileageForInterval(
        _ interval: MaintenanceInterval,
        lastMileage: Int?,
        currentMileage: Int?
    ) -> Int? {
        guard let kmInterval = interval.kmInterval,
              let currentMileage else { return nil }

        if let lastMileage {
            return lastMileage + kmInterval
        }

        return nextMileageMilestone(currentMileage: currentMileage, interval: kmInterval)
    }

    private func nextMileageMilestone(currentMileage: Int, interval: Int) -> Int {
        guard interval > 0 else { return currentMileage }
        let completedIntervals = currentMileage / interval
        let nextInterval = currentMileage.isMultiple(of: interval) ? completedIntervals : completedIntervals + 1
        return max(nextInterval, 1) * interval
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
