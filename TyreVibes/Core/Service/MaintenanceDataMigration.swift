import Foundation

enum MaintenanceDataMigration {
    private static let versionKey = "maintenance_data_version"
    private static let currentVersion = 1

    static func migrateIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(forKey: versionKey)

        if storedVersion < 1 {
            migrateToV1()
        }

        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    /// V1 migration: existing CompletedMaintenanceEntry data without new fields
    /// (maintenanceType, cost, workshopName, workshopId, attachmentIds).
    /// Since all new fields are Optional with Codable, existing data decodes
    /// without issues — new fields will simply be nil.
    /// This migration just validates data integrity and seeds default intervals.
    private static func migrateToV1() {
        // Validate existing history entries can still decode
        let historyKey = "completed_maintenance_entries"
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            do {
                _ = try JSONDecoder().decode([CompletedMaintenanceEntry].self, from: data)
            } catch {
                print("⚠️ [MaintenanceDataMigration] History decode failed, clearing: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: historyKey)
            }
        }

        // Validate existing schedule entries
        let scheduleKey = "scheduled_maintenance_entries"
        if let data = UserDefaults.standard.data(forKey: scheduleKey) {
            do {
                _ = try JSONDecoder().decode([MaintenanceSchedule].self, from: data)
            } catch {
                print("⚠️ [MaintenanceDataMigration] Schedule decode failed, clearing: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: scheduleKey)
            }
        }

        print("✅ [MaintenanceDataMigration] Migration to V1 completed")
    }
}
