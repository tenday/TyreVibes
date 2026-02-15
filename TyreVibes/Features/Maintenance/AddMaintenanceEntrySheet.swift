import SwiftUI

struct AddMaintenanceEntrySheet: View {
    let vehicleId: Int
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var maintenanceType: MaintenanceSchedule.MaintenanceType = .generalService
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var mileageInput: String = ""
    @State private var costText: String = ""
    @State private var workshopName: String = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervento") {
                    Picker("Tipo", selection: $maintenanceType) {
                        ForEach(MaintenanceSchedule.MaintenanceType.groupedByCategory, id: \.category) { group in
                            Section(group.category.localizedName) {
                                ForEach(group.types, id: \.self) { type in
                                    Label(type.localizedName, systemImage: type.icon)
                                        .tag(type)
                                }
                            }
                        }
                    }
                    TextField("Es. Cambio gomme", text: $title)
                    TextField("Note (opzionale)", text: $note, axis: .vertical)
                }

                Section("Dettagli") {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    TextField("Km (opzionale)", text: $mileageInput)
                        .keyboardType(.numberPad)
                        .onChange(of: mileageInput) { _, newValue in
                            let filtered = newValue.filter(\.isNumber)
                            if filtered != newValue {
                                mileageInput = filtered
                            }
                        }
                    TextField("Costo (€)", text: $costText)
                        .keyboardType(.decimalPad)
                    TextField("Officina (opzionale)", text: $workshopName)
                }
            }
            .navigationTitle("Nuova manutenzione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cost = Double(costText.replacingOccurrences(of: ",", with: "."))
                        let cleanedWorkshop = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)

                        MaintenanceHistoryStore.shared.addManualEntry(
                            vehicleId: vehicleId,
                            title: cleanedTitle,
                            note: cleanedNote.isEmpty ? nil : cleanedNote,
                            date: date,
                            mileage: Int(mileageInput),
                            maintenanceType: maintenanceType,
                            cost: cost,
                            workshopName: cleanedWorkshop.isEmpty ? nil : cleanedWorkshop
                        )
                        onSave()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
