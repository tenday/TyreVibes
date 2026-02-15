import SwiftUI

struct MaintenanceCompletionSheet: View {
    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var mileageText: String = ""
    @State private var maintenanceType: MaintenanceSchedule.MaintenanceType = .generalService
    @State private var costText: String = ""
    @State private var workshopName: String = ""
    @State private var entryId: String = UUID().uuidString

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervento effettuato") {
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
                    TextField("Titolo", text: $title)
                    TextField("Note (opzionale)", text: $note, axis: .vertical)
                }

                Section("Dettagli") {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    TextField("Km (opzionale)", text: $mileageText)
                        .keyboardType(.numberPad)
                    TextField("Costo (€)", text: $costText)
                        .keyboardType(.decimalPad)
                    TextField("Officina (opzionale)", text: $workshopName)
                }

                Section("Allegati") {
                    AttachmentGalleryView(entryId: entryId, isEditing: true)
                }
            }
            .navigationTitle("Registra manutenzione")
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
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost = Double(costText.replacingOccurrences(of: ",", with: "."))
        let cleanedWorkshop = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)

        let attachmentIds = AttachmentManager.shared.attachments(for: entryId).map(\.id)

        MaintenanceHistoryStore.shared.addManualEntry(
            vehicleId: vehicleId,
            title: cleanedTitle,
            note: cleanedNote.isEmpty ? nil : cleanedNote,
            date: date,
            mileage: Int(mileageText),
            maintenanceType: maintenanceType,
            cost: cost,
            workshopName: cleanedWorkshop.isEmpty ? nil : cleanedWorkshop,
            attachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
        )
        dismiss()
    }
}
