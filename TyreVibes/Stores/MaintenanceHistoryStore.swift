import Foundation

private enum MaintenanceRemoteSync {
    struct RemoteEntry: Codable {
        let id: String
        let vehicleId: Int
        let title: String
        let note: String?
        let date: Date
        let mileage: Int?
        let source: CompletedMaintenanceSource
        let maintenanceType: MaintenanceSchedule.MaintenanceType?
        let cost: Double?
        let workshopName: String?
        let workshopId: String?
        let attachmentIds: [String]?

        init(entry: CompletedMaintenanceEntry) {
            self.id = entry.id
            self.vehicleId = entry.vehicleId
            self.title = entry.title
            self.note = entry.note
            self.date = entry.date
            self.mileage = entry.mileage
            self.source = entry.source
            self.maintenanceType = entry.maintenanceType
            self.cost = entry.cost
            self.workshopName = entry.workshopName
            self.workshopId = entry.workshopId
            self.attachmentIds = entry.attachmentIds
        }

        var localEntry: CompletedMaintenanceEntry {
            CompletedMaintenanceEntry(
                id: id,
                vehicleId: vehicleId,
                title: title,
                note: note,
                date: date,
                mileage: mileage,
                source: source,
                maintenanceType: maintenanceType,
                cost: cost,
                workshopName: workshopName,
                workshopId: workshopId,
                attachmentIds: attachmentIds
            )
        }
    }

    private struct MileageUpdate: Encodable {
        let mileage: Int?
    }

    static func fetchEntries(vehicleId: Int) async throws -> [CompletedMaintenanceEntry] {
        let remoteEntries: [RemoteEntry] = try await NetworkManager.shared.get(
            endpoint: "/v1/maintenance_entries/vehicle/\(vehicleId)"
        )
        return remoteEntries.map(\.localEntry)
    }

    static func upsert(_ entry: CompletedMaintenanceEntry) async throws {
        let _: RemoteEntry = try await NetworkManager.shared.post(
            endpoint: "/v1/maintenance_entries",
            body: RemoteEntry(entry: entry)
        )
    }

    static func updateMileage(entryId: String, mileage: Int?) async throws {
        try await NetworkManager.shared.requestWithoutResponse(
            endpoint: "/v1/maintenance_entries/\(entryId)/mileage",
            method: .patch,
            body: try JSONEncoder().encode(MileageUpdate(mileage: mileage))
        )
    }
}

enum CompletedMaintenanceSource: String, Codable {
    case manual
    case partner
    case automatic

    var label: String {
        switch self {
        case .manual: return String(localized: "maintenance.source.manual")
        case .partner: return String(localized: "maintenance.source.partner")
        case .automatic: return String(localized: "maintenance.source.automatic")
        }
    }
}

struct CompletedMaintenanceEntry: Identifiable, Codable, Hashable {
    let id: String
    let vehicleId: Int
    let title: String
    let note: String?
    let date: Date
    var mileage: Int?
    let source: CompletedMaintenanceSource
    // New fields (all optional for backward compatibility)
    let maintenanceType: MaintenanceSchedule.MaintenanceType?
    let cost: Double?
    let workshopName: String?
    let workshopId: String?
    let attachmentIds: [String]?

    init(
        id: String = UUID().uuidString,
        vehicleId: Int,
        title: String,
        note: String? = nil,
        date: Date = Date(),
        mileage: Int? = nil,
        source: CompletedMaintenanceSource,
        maintenanceType: MaintenanceSchedule.MaintenanceType? = nil,
        cost: Double? = nil,
        workshopName: String? = nil,
        workshopId: String? = nil,
        attachmentIds: [String]? = nil
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.title = title
        self.note = note
        self.date = date
        self.mileage = mileage
        self.source = source
        self.maintenanceType = maintenanceType
        self.cost = cost
        self.workshopName = workshopName
        self.workshopId = workshopId
        self.attachmentIds = attachmentIds
    }
}

@MainActor
final class MaintenanceHistoryStore: ObservableObject {
    static let shared = MaintenanceHistoryStore()

    @Published private(set) var entries: [CompletedMaintenanceEntry] = []

    private let storageKey = "completed_maintenance_entries"

    private init() {
        load()
    }

    func entries(for vehicleId: Int) -> [CompletedMaintenanceEntry] {
        entries
            .filter { $0.vehicleId == vehicleId }
            .sorted { $0.date > $1.date }
    }

    func addManualEntry(
        id: String = UUID().uuidString,
        vehicleId: Int,
        title: String,
        note: String? = nil,
        date: Date = Date(),
        mileage: Int? = nil,
        maintenanceType: MaintenanceSchedule.MaintenanceType? = nil,
        cost: Double? = nil,
        workshopName: String? = nil,
        workshopId: String? = nil,
        attachmentIds: [String]? = nil
    ) {
        let entry = CompletedMaintenanceEntry(
            id: id,
            vehicleId: vehicleId,
            title: title,
            note: note,
            date: date,
            mileage: mileage,
            source: .manual,
            maintenanceType: maintenanceType,
            cost: cost,
            workshopName: workshopName,
            workshopId: workshopId,
            attachmentIds: attachmentIds
        )
        entries.insert(entry, at: 0)
        save()
        pushToRemote(entry)
    }

    func registerPartnerAppointmentCompleted(
        vehicleId: Int,
        serviceTitle: String,
        appointmentDate: Date,
        note: String? = nil,
        mileage: Int? = nil,
        maintenanceType: MaintenanceSchedule.MaintenanceType? = nil,
        cost: Double? = nil,
        workshopName: String? = nil,
        workshopId: String? = nil
    ) {
        let entry = CompletedMaintenanceEntry(
            vehicleId: vehicleId,
            title: serviceTitle,
            note: note,
            date: appointmentDate,
            mileage: mileage,
            source: .partner,
            maintenanceType: maintenanceType,
            cost: cost,
            workshopName: workshopName,
            workshopId: workshopId
        )
        entries.insert(entry, at: 0)
        save()
        pushToRemote(entry)
    }

    func updateMileage(entryId: String, newMileage: Int) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].mileage = newMileage
        save()
        pushMileageToRemote(entryId: entryId, mileage: newMileage)
    }

    func refreshFromRemote(vehicleId: Int) async {
        do {
            let remoteEntries = try await MaintenanceRemoteSync.fetchEntries(vehicleId: vehicleId)
            merge(remoteEntries)
        } catch {
            print("⚠️ [MaintenanceHistoryStore] Remote refresh failed: \(error.localizedDescription)")
        }
    }

    private func merge(_ remoteEntries: [CompletedMaintenanceEntry]) {
        guard !remoteEntries.isEmpty else { return }

        var entriesById: [String: CompletedMaintenanceEntry] = [:]
        for entry in entries {
            entriesById[entry.id] = entry
        }

        for remoteEntry in remoteEntries {
            entriesById[remoteEntry.id] = remoteEntry
        }

        entries = entriesById.values.sorted { $0.date > $1.date }
        save()
    }

    private func pushToRemote(_ entry: CompletedMaintenanceEntry) {
        Task {
            do {
                try await MaintenanceRemoteSync.upsert(entry)
                await MainActor.run {
                    AttachmentManager.shared.syncAttachments(for: entry.id, vehicleId: entry.vehicleId)
                }
            } catch {
                print("⚠️ [MaintenanceHistoryStore] Remote save failed: \(error.localizedDescription)")
            }
        }
    }

    private func pushMileageToRemote(entryId: String, mileage: Int?) {
        Task {
            do {
                try await MaintenanceRemoteSync.updateMileage(entryId: entryId, mileage: mileage)
            } catch {
                print("⚠️ [MaintenanceHistoryStore] Remote mileage update failed: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("❌ [MaintenanceHistoryStore] Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([CompletedMaintenanceEntry].self, from: data)
        } catch {
            print("⚠️ [MaintenanceHistoryStore] Load error: \(error.localizedDescription)")
            entries = []
        }
    }
}

@MainActor
final class MaintenanceScheduleStore: ObservableObject {
    static let shared = MaintenanceScheduleStore()

    @Published private(set) var schedules: [MaintenanceSchedule] = []

    private let storageKey = "scheduled_maintenance_entries"

    private init() {
        load()
    }

    func schedules(for vehicleId: Int) -> [MaintenanceSchedule] {
        schedules
            .filter { $0.vehicleId == String(vehicleId) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    func addSchedule(
        vehicleId: Int,
        type: MaintenanceSchedule.MaintenanceType,
        title: String,
        description: String,
        scheduledDate: Date,
        estimatedCost: Double?,
        priority: MaintenanceSchedule.Priority,
        dueMileage: Int? = nil,
        currentMileage: Int? = nil,
        targetMileage: Int? = nil,
        lastServiceDate: Date? = nil,
        dueInKm: Int? = nil
    ) {
        let metadata = MaintenanceSchedule.MaintenanceMetadata(
            currentTreadDepth: nil,
            targetTreadDepth: nil,
            currentMileage: currentMileage,
            targetMileage: targetMileage ?? dueMileage,
            lastServiceDate: lastServiceDate,
            dueInDays: nil,
            dueInKm: dueInKm ?? dueMileage
        )

        let schedule = MaintenanceSchedule(
            type: type,
            title: title,
            description: description,
            scheduledDate: scheduledDate,
            estimatedCost: estimatedCost,
            priority: priority,
            vehicleId: String(vehicleId),
            metadata: currentMileage == nil && targetMileage == nil && lastServiceDate == nil && dueInKm == nil && dueMileage == nil ? nil : metadata
        )

        schedules.append(schedule)
        schedules.sort { $0.scheduledDate < $1.scheduledDate }
        save()
    }

    func upsertAutomaticSchedule(
        vehicleId: Int,
        type: MaintenanceSchedule.MaintenanceType,
        title: String,
        description: String,
        scheduledDate: Date,
        estimatedCost: Double?,
        priority: MaintenanceSchedule.Priority,
        currentMileage: Int?,
        targetMileage: Int?,
        lastServiceDate: Date?,
        dueInKm: Int?
    ) {
        let metadata = MaintenanceSchedule.MaintenanceMetadata(
            currentTreadDepth: nil,
            targetTreadDepth: nil,
            currentMileage: currentMileage,
            targetMileage: targetMileage,
            lastServiceDate: lastServiceDate,
            dueInDays: nil,
            dueInKm: dueInKm
        )

        let schedule = MaintenanceSchedule(
            type: type,
            title: title,
            description: description,
            scheduledDate: scheduledDate,
            estimatedCost: estimatedCost,
            priority: priority,
            vehicleId: String(vehicleId),
            metadata: metadata
        )

        if let index = schedules.firstIndex(where: {
            $0.vehicleId == String(vehicleId) &&
            $0.type == type &&
            canReplaceWithAutomaticSchedule($0)
        }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }

        schedules.sort { $0.scheduledDate < $1.scheduledDate }
        save()
    }

    func canReplaceWithAutomaticSchedule(_ schedule: MaintenanceSchedule) -> Bool {
        if schedule.metadata?.currentMileage != nil ||
            schedule.metadata?.lastServiceDate != nil {
            return true
        }

        if schedule.title == schedule.type.localizedName {
            return true
        }

        return isLegacySeededSchedule(schedule)
    }

    func deleteSchedule(_ scheduleId: String) {
        schedules.removeAll { $0.id == scheduleId }
        save()
    }

    func removeLegacySeededSchedules(for vehicleId: Int) {
        let countBefore = schedules.count
        schedules.removeAll {
            $0.vehicleId == String(vehicleId) && isLegacySeededSchedule($0)
        }

        if schedules.count != countBefore {
            save()
        }
    }

    func markCompleted(
        scheduleId: String,
        vehicleId: Int,
        completionDate: Date = Date(),
        mileage: Int? = nil,
        note: String? = nil
    ) {
        guard let schedule = schedules.first(where: { $0.id == scheduleId }) else { return }

        deleteSchedule(scheduleId)

        let mergedNote: String?
        if let note, !note.isEmpty {
            mergedNote = note
        } else {
            mergedNote = schedule.description
        }

        let resolvedMileage = mileage ?? schedule.metadata?.currentMileage ?? schedule.metadata?.targetMileage

        MaintenanceHistoryStore.shared.addManualEntry(
            vehicleId: vehicleId,
            title: schedule.title,
            note: mergedNote,
            date: completionDate,
            mileage: resolvedMileage,
            maintenanceType: schedule.type
        )
    }

    func seedDefaultsIfNeeded(for vehicleId: Int) {
        if !schedules(for: vehicleId).isEmpty {
            return
        }

        let now = Date()
        let defaults: [MaintenanceSchedule] = [
            MaintenanceSchedule(
                type: .rotation,
                title: "Rotazione gomme",
                description: "Inversione pneumatici per usura uniforme.",
                scheduledDate: Calendar.current.date(byAdding: .day, value: 20, to: now) ?? now,
                estimatedCost: 45,
                priority: .medium,
                vehicleId: String(vehicleId)
            ),
            MaintenanceSchedule(
                type: .inspection,
                title: "Controllo generale",
                description: "Verifica pressione, stato valvole e consumo battistrada.",
                scheduledDate: Calendar.current.date(byAdding: .day, value: 35, to: now) ?? now,
                estimatedCost: 25,
                priority: .medium,
                vehicleId: String(vehicleId)
            ),
            MaintenanceSchedule(
                type: .replacement,
                title: "Valutazione sostituzione",
                description: "Programmare sostituzione treno gomme se necessario.",
                scheduledDate: Calendar.current.date(byAdding: .day, value: 75, to: now) ?? now,
                estimatedCost: 380,
                priority: .high,
                vehicleId: String(vehicleId)
            )
        ]

        schedules.append(contentsOf: defaults)
        schedules.sort { $0.scheduledDate < $1.scheduledDate }
        save()
    }

    private func isLegacySeededSchedule(_ schedule: MaintenanceSchedule) -> Bool {
        switch (schedule.type, schedule.title) {
        case (.rotation, "Rotazione gomme"),
             (.inspection, "Controllo generale"),
             (.replacement, "Valutazione sostituzione"):
            return schedule.metadata == nil
        default:
            return false
        }
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(schedules)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("❌ [MaintenanceScheduleStore] Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            schedules = []
            return
        }

        do {
            schedules = try JSONDecoder().decode([MaintenanceSchedule].self, from: data)
        } catch {
            print("⚠️ [MaintenanceScheduleStore] Load error: \(error.localizedDescription)")
            schedules = []
        }
    }
}
