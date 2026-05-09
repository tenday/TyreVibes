import SwiftUI

struct VehicleArchiveView: View {
    let vehicleId: Int

    @StateObject private var store = VehicleArchiveStore.shared
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var selectedCategory: VehicleArchiveDocument.Category?
    @State private var showAddSheet = false
    @State private var selectedDocument: VehicleArchiveDocument?

    private var documents: [VehicleArchiveDocument] {
        let vehicleDocuments = store.documents(for: vehicleId)
        guard let selectedCategory else { return vehicleDocuments }
        return vehicleDocuments.filter { $0.category == selectedCategory }
    }

    private var expiringDocuments: [VehicleArchiveDocument] {
        let now = Date()
        let limit = Calendar.current.date(byAdding: .day, value: 45, to: now) ?? now
        return store.documents(for: vehicleId).filter { document in
            guard let expiryDate = document.expiryDate else { return false }
            return expiryDate <= limit
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                summary
                categoryFilter

                if documents.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(documents) { document in
                            ArchiveDocumentCard(
                                document: document,
                                attachmentCount: attachmentManager.attachments(for: document.id).count
                            ) {
                                selectedDocument = document
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showAddSheet) {
            AddArchiveDocumentSheet(vehicleId: vehicleId)
        }
        .sheet(item: $selectedDocument) { document in
            ArchiveDocumentDetailSheet(document: document)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Archivio")
                    .font(.customFont(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Documenti, ricevute e garanzie del veicolo")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.62))
            }

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            ArchiveStatCard(
                title: "Documenti",
                value: "\(store.documents(for: vehicleId).count)",
                icon: "folder.fill",
                color: .cyan
            )
            ArchiveStatCard(
                title: "In scadenza",
                value: "\(expiringDocuments.count)",
                icon: "calendar.badge.exclamationmark",
                color: expiringDocuments.isEmpty ? .green : .orange
            )
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ArchiveCategoryChip(
                    title: "Tutti",
                    icon: "square.grid.2x2.fill",
                    color: .white,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedCategory = nil
                    }
                }

                ForEach(VehicleArchiveDocument.Category.allCases, id: \.self) { category in
                    ArchiveCategoryChip(
                        title: category.label,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.cyan.opacity(0.15)))

            Text(selectedCategory == nil ? "Nessun documento archiviato" : "Nessun documento in questa categoria")
                .font(.customFont(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text("Aggiungi libretto, ricevute, certificati e garanzie per tenerli collegati al veicolo.")
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("Aggiungi documento", systemImage: "plus")
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct ArchiveStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.customFont(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Text(title)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct ArchiveCategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.customFont(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : color.opacity(0.16))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : color.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ArchiveDocumentCard: View {
    let document: VehicleArchiveDocument
    let attachmentCount: Int
    let action: () -> Void

    private var isExpired: Bool {
        guard let expiryDate = document.expiryDate else { return false }
        return expiryDate < Calendar.current.startOfDay(for: Date())
    }

    private var isExpiringSoon: Bool {
        guard let expiryDate = document.expiryDate else { return false }
        let limit = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
        return expiryDate <= limit
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: document.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(document.category.color)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(document.category.color.opacity(0.15)))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(document.title)
                            .font(.customFont(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Spacer()

                        Text(document.category.label)
                            .font(.customFont(size: 10, weight: .semibold))
                            .foregroundColor(document.category.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(document.category.color.opacity(0.15)))
                    }

                    HStack(spacing: 10) {
                        metaItem(icon: "calendar", text: ArchiveFormatters.shortDate.string(from: document.documentDate))

                        if attachmentCount > 0 {
                            metaItem(icon: "paperclip", text: "\(attachmentCount)")
                        }

                        if let amount = document.amount {
                            metaItem(icon: "eurosign", text: ArchiveFormatters.currency.string(from: NSNumber(value: amount)) ?? "\(amount)")
                        }
                    }

                    if let expiryDate = document.expiryDate {
                        HStack(spacing: 6) {
                            Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(isExpired ? "Scaduto" : "Scade") \(ArchiveFormatters.shortDate.string(from: expiryDate))")
                                .font(.customFont(size: 11, weight: .semibold))
                        }
                        .foregroundColor(isExpired ? .red : (isExpiringSoon ? .orange : .white.opacity(0.58)))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(document.category.color.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.customFont(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.58))
    }
}

private struct AddArchiveDocumentSheet: View {
    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var draftId = UUID().uuidString
    @State private var category: VehicleArchiveDocument.Category = .registration
    @State private var title = ""
    @State private var note = ""
    @State private var documentDate = Date()
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var amountText = ""
    @State private var linkedMaintenanceEntryId: String?
    @State private var didSave = false

    private var maintenanceEntries: [CompletedMaintenanceEntry] {
        MaintenanceHistoryStore.shared.entries(for: vehicleId)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Documento") {
                    Picker("Categoria", selection: $category) {
                        ForEach(VehicleArchiveDocument.Category.allCases, id: \.self) { category in
                            Label(category.label, systemImage: category.icon)
                                .tag(category)
                        }
                    }

                    TextField("Titolo", text: $title)
                    TextField("Note (opzionale)", text: $note, axis: .vertical)
                }

                Section("Dettagli") {
                    DatePicker("Data documento", selection: $documentDate, displayedComponents: .date)
                    Toggle("Ha una scadenza", isOn: $hasExpiry)

                    if hasExpiry {
                        DatePicker("Data scadenza", selection: $expiryDate, displayedComponents: .date)
                    }

                    TextField("Importo (€)", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                if !maintenanceEntries.isEmpty {
                    Section("Collegamento") {
                        Picker("Manutenzione collegata", selection: $linkedMaintenanceEntryId) {
                            Text("Nessuna").tag(String?.none)
                            ForEach(maintenanceEntries) { entry in
                                Text(entry.title).tag(Optional(entry.id))
                            }
                        }
                    }
                }

                Section("File") {
                    AttachmentGalleryView(entryId: draftId, isEditing: true)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Nuovo documento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        AttachmentManager.shared.deleteAttachments(for: draftId)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onDisappear {
                if !didSave {
                    AttachmentManager.shared.deleteAttachments(for: draftId)
                }
            }
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))

        VehicleArchiveStore.shared.addDocument(
            id: draftId,
            vehicleId: vehicleId,
            category: category,
            title: cleanedTitle,
            note: cleanedNote.isEmpty ? nil : cleanedNote,
            documentDate: documentDate,
            expiryDate: hasExpiry ? expiryDate : nil,
            amount: amount,
            linkedMaintenanceEntryId: linkedMaintenanceEntryId
        )

        didSave = true
        dismiss()
    }
}

private struct ArchiveDocumentDetailSheet: View {
    let document: VehicleArchiveDocument

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: document.category.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(document.category.color)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(document.category.color.opacity(0.15)))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.customFont(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text(document.category.label)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(document.category.color)
                        }
                    }

                    detailRows

                    if let note = document.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note")
                                .font(.customFont(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.72))
                            Text(note)
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.86))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))
                    }

                    AttachmentGalleryView(entryId: document.id, isEditing: true)
                }
                .padding(16)
            }
            .background(Color.customBackgroundColor.ignoresSafeArea())
            .navigationTitle("Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("Eliminare documento?", isPresented: $showDeleteConfirmation) {
                Button("Elimina", role: .destructive) {
                    VehicleArchiveStore.shared.deleteDocument(document)
                    dismiss()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Verranno rimossi anche gli allegati collegati.")
            }
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            ArchiveDetailRow(label: "Data documento", value: ArchiveFormatters.longDate.string(from: document.documentDate))

            if let expiryDate = document.expiryDate {
                ArchiveDetailRow(label: "Scadenza", value: ArchiveFormatters.longDate.string(from: expiryDate))
            }

            if let amount = document.amount {
                ArchiveDetailRow(label: "Importo", value: ArchiveFormatters.currency.string(from: NSNumber(value: amount)) ?? "\(amount)")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct ArchiveDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.58))
            Spacer()
            Text(value)
                .font(.customFont(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private enum ArchiveFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
