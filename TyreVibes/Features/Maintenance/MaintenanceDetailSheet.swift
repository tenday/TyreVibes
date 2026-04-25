import SwiftUI

struct MaintenanceDetailSheet: View {
    let entry: CompletedMaintenanceEntry
    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var mileageText: String = ""
    @FocusState private var isMileageFocused: Bool

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    private var displayIcon: String {
        if let type = entry.maintenanceType {
            return type.icon
        }
        switch entry.source {
        case .manual: return "square.and.pencil"
        case .partner: return "building.2.fill"
        case .automatic: return "gearshape.2.fill"
        }
    }

    private var displayColor: Color {
        if let type = entry.maintenanceType {
            return type.color
        }
        switch entry.source {
        case .manual: return .orange
        case .partner: return .green
        case .automatic: return .blue
        }
    }

    private var costText: String? {
        guard let cost = entry.cost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: cost))
    }

    private var canSaveMileage: Bool {
        guard let km = Int(mileageText), km > 0 else { return false }
        return km != entry.mileage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    detailRows
                    mileageSection
                    if let note = entry.note, !note.isEmpty {
                        noteSection(note)
                    }
                    if let ids = entry.attachmentIds, !ids.isEmpty {
                        attachmentSection(ids)
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "#191919"))
            .navigationTitle("Dettaglio manutenzione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .onAppear {
            if let km = entry.mileage {
                mileageText = "\(km)"
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let type = entry.maintenanceType {
                    MaintenanceTypeIconView(type: type, color: displayColor, size: 18)
                } else {
                    Image(systemName: displayIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(displayColor)
                }
            }
                .frame(width: 42, height: 42)
                .background(displayColor.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.customFont(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(entry.source.label)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if let type = entry.maintenanceType {
                Text(type.category.localizedName)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(type.color.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(type.color.opacity(0.15), in: Capsule())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Detail Rows

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", label: "Data", value: dateFormatter.string(from: entry.date))

            if let costText {
                Divider().overlay(Color.white.opacity(0.08))
                detailRow(icon: "eurosign.circle", label: "Costo", value: costText, valueColor: .green)
            }

            if let workshopName = entry.workshopName, !workshopName.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                detailRow(icon: "building.2", label: "Officina", value: workshopName)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func detailRow(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            Text(label)
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.customFont(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Mileage Section

    private var mileageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan)
                Text("Chilometraggio")
                    .font(.customFont(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            if entry.mileage == nil {
                Text("Inserisci il km al momento dell'intervento per migliorare il calcolo delle prossime scadenze.")
                    .font(.customFont(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                TextField("Km al momento dell'intervento", text: $mileageText)
                    .keyboardType(.numberPad)
                    .font(.customFont(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isMileageFocused)
                    .onChange(of: mileageText) { _, newValue in
                        mileageText = newValue.filter(\.isNumber)
                    }

                Button {
                    saveMileage()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(canSaveMileage ? .green : .white.opacity(0.2))
                }
                .disabled(!canSaveMileage)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cyan.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Note Section

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text("Note")
                    .font(.customFont(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(note)
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.78))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Attachment Section

    private func attachmentSection(_ ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text("Allegati (\(ids.count))")
                    .font(.customFont(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            AttachmentGalleryView(entryId: entry.id, isEditing: false)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Save

    private func saveMileage() {
        guard let km = Int(mileageText), km > 0, km != entry.mileage else { return }
        isMileageFocused = false

        MaintenanceHistoryStore.shared.updateMileage(entryId: entry.id, newMileage: km)

        let currentKm = VehicleMileageStore.shared.mileage(for: vehicleId)
        if km > (currentKm ?? 0) {
            VehicleMileageStore.shared.setMileage(km, for: vehicleId)
        }

        SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
    }
}
