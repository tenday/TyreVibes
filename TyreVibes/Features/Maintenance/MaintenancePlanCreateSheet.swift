import SwiftUI

struct MaintenancePlanCreateSheet: View {
    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var type: MaintenanceSchedule.MaintenanceType = .inspection
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var date: Date = Date()
    @State private var priority: MaintenanceSchedule.Priority = .medium
    @State private var costText: String = ""
    @State private var dueMileageText: String = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervento") {
                    Picker("Tipo", selection: $type) {
                        ForEach(MaintenanceSchedule.MaintenanceType.groupedByCategory, id: \.category) { group in
                            Section(group.category.localizedName) {
                                ForEach(group.types, id: \.self) { maintenanceType in
                                    HStack(spacing: 8) {
                                        MaintenanceTypeIconView(type: maintenanceType, size: 16)
                                        Text(maintenanceType.localizedName)
                                    }
                                        .tag(maintenanceType)
                                }
                            }
                        }
                    }
                    TextField("Titolo", text: $title)
                    TextField("Dettagli", text: $details, axis: .vertical)
                }

                Section("Pianificazione") {
                    DatePicker("Data prevista", selection: $date, displayedComponents: .date)
                    Picker("Priorità", selection: $priority) {
                        Text(MaintenanceSchedule.Priority.low.label).tag(MaintenanceSchedule.Priority.low)
                        Text(MaintenanceSchedule.Priority.medium.label).tag(MaintenanceSchedule.Priority.medium)
                        Text(MaintenanceSchedule.Priority.high.label).tag(MaintenanceSchedule.Priority.high)
                        Text(MaintenanceSchedule.Priority.critical.label).tag(MaintenanceSchedule.Priority.critical)
                    }
                    TextField("Costo stimato (€)", text: $costText)
                        .keyboardType(.decimalPad)
                    TextField("Km previsti (opzionale)", text: $dueMileageText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Nuova pianificazione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDescription = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost = Double(costText.replacingOccurrences(of: ",", with: "."))
        let dueMileage = Int(dueMileageText)

        MaintenanceScheduleStore.shared.addSchedule(
            vehicleId: vehicleId,
            type: type,
            title: cleanedTitle,
            description: cleanedDescription.isEmpty ? String(localized: "maintenance.planned.defaultDescription") : cleanedDescription,
            scheduledDate: date,
            estimatedCost: cost,
            priority: priority,
            dueMileage: dueMileage
        )
        NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
        dismiss()
    }
}
