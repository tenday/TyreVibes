import Foundation

@MainActor
final class MaintenanceIntervalStore: ObservableObject {
    static let shared = MaintenanceIntervalStore()

    @Published private(set) var intervals: [MaintenanceInterval] = []

    private let storageKey = "maintenance_intervals"

    private init() {
        load()
    }

    func intervals(for vehicleId: Int) -> [MaintenanceInterval] {
        let vehicleSpecific = intervals.filter { $0.vehicleId == vehicleId }
        let globalDefaults = intervals.filter { $0.vehicleId == nil }

        // For each type, prefer vehicle-specific over global
        var result: [MaintenanceSchedule.MaintenanceType: MaintenanceInterval] = [:]
        for interval in globalDefaults {
            result[interval.maintenanceType] = interval
        }
        for interval in vehicleSpecific {
            result[interval.maintenanceType] = interval
        }
        return Array(result.values)
    }

    func interval(for type: MaintenanceSchedule.MaintenanceType, vehicleId: Int) -> MaintenanceInterval? {
        intervals.first(where: { $0.maintenanceType == type && $0.vehicleId == vehicleId })
        ?? intervals.first(where: { $0.maintenanceType == type && $0.vehicleId == nil })
    }

    func setInterval(_ interval: MaintenanceInterval) {
        // Remove existing for same type + vehicleId
        intervals.removeAll {
            $0.maintenanceType == interval.maintenanceType && $0.vehicleId == interval.vehicleId
        }
        intervals.append(interval)
        save()
    }

    func removeInterval(for type: MaintenanceSchedule.MaintenanceType, vehicleId: Int) {
        intervals.removeAll {
            $0.maintenanceType == type && $0.vehicleId == vehicleId
        }
        save()
    }

    func resetToDefaults(for vehicleId: Int) {
        intervals.removeAll { $0.vehicleId == vehicleId }
        save()
    }

    // MARK: - OEM Intervals

    /// Whether there are any OEM (non-custom) vehicle-specific intervals for this vehicle.
    func hasOEMIntervals(for vehicleId: Int) -> Bool {
        intervals.contains { $0.vehicleId == vehicleId && !$0.isCustom }
    }

    /// Sets an OEM-sourced interval for a specific vehicle and maintenance type.
    /// Overwrites any existing interval of the same type for the same vehicle.
    func setOEMInterval(
        type: MaintenanceSchedule.MaintenanceType,
        kmInterval: Int?,
        monthsInterval: Int?,
        vehicleId: Int
    ) {
        let interval = MaintenanceInterval(
            maintenanceType: type,
            kmInterval: kmInterval,
            monthsInterval: monthsInterval,
            isCustom: false,
            vehicleId: vehicleId
        )
        setInterval(interval)
    }

    func seedDefaultsIfNeeded() {
        let hasGlobalDefaults = intervals.contains { $0.vehicleId == nil }
        guard !hasGlobalDefaults else { return }

        intervals.append(contentsOf: MaintenanceInterval.defaults)
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(intervals)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("❌ [MaintenanceIntervalStore] Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            intervals = []
            seedDefaultsIfNeeded()
            return
        }

        do {
            intervals = try JSONDecoder().decode([MaintenanceInterval].self, from: data)
        } catch {
            print("⚠️ [MaintenanceIntervalStore] Load error: \(error.localizedDescription)")
            intervals = []
            seedDefaultsIfNeeded()
        }
    }
}
