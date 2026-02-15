import Foundation

struct MileageEntry: Codable {
    let km: Int
    let date: Date
}

@MainActor
final class VehicleMileageStore: ObservableObject {
    static let shared = VehicleMileageStore()

    private let currentKey = "vehicle_mileage_by_id"
    private let historyKey = "vehicle_mileage_history"
    private let defaults = UserDefaults.standard

    @Published private(set) var currentMileage: [String: Int] = [:]

    private init() {
        loadCurrent()
    }

    func mileage(for vehicleId: Int) -> Int? {
        currentMileage[String(vehicleId)]
    }

    func setMileage(_ mileage: Int?, for vehicleId: Int) {
        let id = String(vehicleId)

        if let mileage {
            currentMileage[id] = mileage
            addHistoryEntry(km: mileage, for: vehicleId)
        } else {
            currentMileage.removeValue(forKey: id)
        }

        saveCurrent()
    }

    func mileageHistory(for vehicleId: Int) -> [MileageEntry] {
        let all = loadHistory()
        return (all[String(vehicleId)] ?? []).sorted { $0.date < $1.date }
    }

    /// Calculate average km driven per month based on mileage history
    func averageKmPerMonth(for vehicleId: Int) -> Int? {
        let history = mileageHistory(for: vehicleId)
        guard history.count >= 2,
              let first = history.first,
              let last = history.last else { return nil }

        let months = Calendar.current.dateComponents([.month], from: first.date, to: last.date).month ?? 0
        guard months > 0 else { return nil }

        let kmDriven = last.km - first.km
        guard kmDriven > 0 else { return nil }

        return kmDriven / months
    }

    /// Returns the date of the last mileage update
    func lastUpdateDate(for vehicleId: Int) -> Date? {
        mileageHistory(for: vehicleId).last?.date
    }

    /// Check if mileage needs updating (older than given days)
    func needsUpdate(for vehicleId: Int, olderThanDays days: Int = 30) -> Bool {
        guard let lastDate = lastUpdateDate(for: vehicleId) else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSince >= days
    }

    // MARK: - Seed from Revisions

    /// If no mileage is set for this vehicle, use the latest revision km as initial value.
    func seedFromRevisions(vehicleId: Int, revisions: [VehicleRevision]) {
        guard mileage(for: vehicleId) == nil else { return }
        guard !revisions.isEmpty else { return }

        // Find revision with highest km (most recent mileage reading)
        let bestKm = revisions.compactMap { revision -> Int? in
            guard let kmStr = revision.kmRevisione, !kmStr.isEmpty else { return nil }
            let cleaned = kmStr.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: " ", with: "")
            return Int(cleaned)
        }.max()

        if let km = bestKm, km > 0 {
            setMileage(km, for: vehicleId)
            print("✅ [VehicleMileageStore] Seeded \(km) km from revision for vehicle \(vehicleId)")
        }
    }

    // MARK: - Private

    private func addHistoryEntry(km: Int, for vehicleId: Int) {
        var all = loadHistory()
        let id = String(vehicleId)
        var vehicleHistory = all[id] ?? []
        vehicleHistory.append(MileageEntry(km: km, date: Date()))
        all[id] = vehicleHistory
        saveHistory(all)
    }

    private func loadCurrent() {
        currentMileage = defaults.dictionary(forKey: currentKey) as? [String: Int] ?? [:]
    }

    private func saveCurrent() {
        defaults.set(currentMileage, forKey: currentKey)
    }

    private func loadHistory() -> [String: [MileageEntry]] {
        guard let data = defaults.data(forKey: historyKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [MileageEntry]].self, from: data)) ?? [:]
    }

    private func saveHistory(_ history: [String: [MileageEntry]]) {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }
}
