import SwiftUI

struct MaintenanceCompletionSheet: View {
    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var mileageText: String = ""
    @State private var maintenanceType: MaintenanceSchedule.MaintenanceType = .generalService
    @State private var costText: String = ""
    @State private var workshopName: String = ""
    @State private var entryId: String = UUID().uuidString
    @State private var validationError: String? = nil
    @State private var isSaving = false
    @State private var didSave = false
    @State private var invalidShakeTrigger = 0

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
                                    HStack(spacing: 8) {
                                        MaintenanceTypeIconView(type: type, size: 16)
                                        Text(type.localizedName)
                                    }
                                        .tag(type)
                                }
                            }
                        }
                    }
                    TextField("Titolo", text: $title)
                        .shake(trigger: invalidShakeTrigger)
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
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else if didSave {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("Salva")
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .overlay(alignment: .bottom) {
                if didSave {
                    Label("Manutenzione registrata", systemImage: "checkmark.circle.fill")
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.88))
                        )
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : AppMotion.smooth, value: didSave)
            .alert("Errore", isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button("OK", role: .cancel) {
                    validationError = nil
                }
            } message: {
                Text(validationError ?? "Dati non validi")
            }
        }
    }

    private func save() {
        guard !isSaving else { return }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            showValidationError("Inserisci un titolo prima di salvare.")
            return
        }

        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost: Double?
        if costText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cost = nil
        } else if let parsedCost = parseLocalizedDecimal(costText) {
            cost = parsedCost
        } else {
            showValidationError("Inserisci un costo valido.")
            return
        }

        let mileage: Int?
        if mileageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mileage = nil
        } else if let parsedMileage = parseLocalizedInt(mileageText) {
            mileage = parsedMileage
        } else {
            showValidationError("Inserisci una distanza in chilometri valida.")
            return
        }
        let cleanedWorkshop = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)

        withAnimation(reduceMotion ? nil : AppMotion.quick) {
            isSaving = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.28)) {
            let attachmentIds = AttachmentManager.shared.attachments(for: entryId).map(\.id)

            MaintenanceHistoryStore.shared.addManualEntry(
                id: entryId,
                vehicleId: vehicleId,
                title: cleanedTitle,
                note: cleanedNote.isEmpty ? nil : cleanedNote,
                date: date,
                mileage: mileage,
                maintenanceType: maintenanceType,
                cost: cost,
                workshopName: cleanedWorkshop.isEmpty ? nil : cleanedWorkshop,
                attachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
            )
            SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
            NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
            AppHaptics.success()

            withAnimation(reduceMotion ? nil : AppMotion.emphasized) {
                isSaving = false
                didSave = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.5)) {
                dismiss()
            }
        }
    }

    private func showValidationError(_ message: String) {
        AppHaptics.warning()
        validationError = message
        withAnimation(reduceMotion ? nil : AppMotion.quick) {
            invalidShakeTrigger += 1
        }
    }

    private func parseLocalizedInt(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")

        let allowed = trimmed.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
        guard allowed == trimmed else { return nil }
        guard !sanitized.isEmpty else { return nil }
        return Int(sanitized)
    }

    private func parseLocalizedDecimal(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let removedWhitespace = trimmed.replacingOccurrences(of: " ", with: "")
        let allowed = removedWhitespace.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !allowed.isEmpty else { return nil }
        guard allowed.count == removedWhitespace.count else { return nil }

        let separatorsCount = allowed.filter { $0 == "." || $0 == "," }.count
        let normalized: String
        if separatorsCount == 0 {
            normalized = allowed
        } else {
            let decimalIndex = allowed.lastIndex(of: ".") ?? allowed.lastIndex(of: ",")
            if let decimalIndex {
                let integerPart = String(allowed[..<decimalIndex]).filter(\.isNumber)
                let decimalPart = String(allowed[allowed.index(after: decimalIndex)...]).filter(\.isNumber)

                if integerPart.isEmpty && decimalPart.isEmpty { return nil }
                normalized = "\(integerPart).\(decimalPart)"
            } else {
                return nil
            }
        }

        return Double(normalized)
    }
}
