import SwiftUI

struct TireData1 {
    let frontLeft: Int
    let frontRight: Int
    let rearLeft: Int
    let rearRight: Int
}

struct ReportItem: Identifiable {
    enum ExportKind {
        case maintenancePDF(vehicleId: Int?)
        case maintenanceCSV(vehicleId: Int?)
        case tyreTechnicalPDF(measurementId: UUID)
    }

    let id: String
    let title: String
    let description: String
    let type: String
    let date: String
    let data: TireData1
    let exportKind: ExportKind
}

struct DocumentItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let date: String
    let icon: String
    let tint: Color
    let attachment: AttachmentManager.Attachment
}

enum ReportContentFilter: String, CaseIterable, Identifiable {
    case all
    case reports
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Tutti"
        case .reports:
            return "Report"
        case .documents:
            return "Documenti"
        }
    }
}

// MARK: - Reports & Documentations View
struct ReportsDocumentationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var historyStore = MaintenanceHistoryStore.shared
    @StateObject private var attachmentManager = AttachmentManager.shared

    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var contentFilter: ReportContentFilter = .all
    @State private var shareURL: URL?
    @State private var previewURL: URL?
    @State private var previewTitle = ""
    @State private var showShareSheet = false
    @State private var showReportPreview = false
    @State private var selectedAttachment: AttachmentManager.Attachment?
    @State private var showAttachmentViewer = false
    @State private var exportErrorMessage: String?
    @State private var treadMeasurements: [TreadDepthMeasurement] = []

    private var reports: [ReportItem] {
        let entries = historyStore.entries
        let technicalReports = treadMeasurements.map(makeTyreTechnicalReport)
        guard !entries.isEmpty else { return technicalReports }

        let groupedEntries = Dictionary(grouping: entries, by: \.vehicleId)
        let vehicleReports = groupedEntries.keys.sorted().flatMap { vehicleId -> [ReportItem] in
            let vehicleEntries = groupedEntries[vehicleId, default: []]
            return [
                makeMaintenanceReport(vehicleId: vehicleId, entries: vehicleEntries, format: .pdf),
                makeMaintenanceReport(vehicleId: vehicleId, entries: vehicleEntries, format: .csv)
            ]
        }

        guard groupedEntries.count > 1 else { return technicalReports + vehicleReports }

        return technicalReports + [
            makeMaintenanceReport(vehicleId: nil, entries: entries, format: .pdf),
            makeMaintenanceReport(vehicleId: nil, entries: entries, format: .csv)
        ] + vehicleReports
    }

    private var documents: [DocumentItem] {
        let entriesById = Dictionary(uniqueKeysWithValues: historyStore.entries.map { ($0.id, $0) })

        return attachmentManager.attachments
            .sorted { $0.createdAt > $1.createdAt }
            .map { attachment in
                let entry = entriesById[attachment.entryId]
                return DocumentItem(
                    id: attachment.id,
                    title: entry?.title ?? (attachment.type == .pdf ? "Documento manutenzione" : "Foto manutenzione"),
                    subtitle: documentSubtitle(for: attachment, entry: entry),
                    date: formattedDate(attachment.createdAt),
                    icon: attachment.type == .pdf ? "doc.richtext" : "photo",
                    tint: attachment.type == .pdf ? .customAzure : .customBlue,
                    attachment: attachment
                )
            }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isFilteringActive: Bool {
        contentFilter != .all || !normalizedSearchText.isEmpty
    }

    private var filteredReports: [ReportItem] {
        guard contentFilter != .documents else { return [] }
        let search = normalizedSearchText
        return reports.filter { report in
            guard !search.isEmpty else { return true }
            return report.title.lowercased().contains(search)
                || report.description.lowercased().contains(search)
                || report.type.lowercased().contains(search)
                || report.date.lowercased().contains(search)
        }
    }

    private var filteredDocuments: [DocumentItem] {
        guard contentFilter != .reports else { return [] }
        let search = normalizedSearchText
        return documents.filter { document in
            guard !search.isEmpty else { return true }
            return document.title.lowercased().contains(search)
                || document.subtitle.lowercased().contains(search)
                || document.date.lowercased().contains(search)
        }
    }
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // App Bar
                HStack {
                    Text("Reports & Docs")
                        .font(.customFont(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                // Search + Filter
                HStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search...", text: $searchText)
                            .font(.customFont(size: 14, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hex: "212121"))
                    .cornerRadius(35)
                    
                    // Filter Button
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: isFilteringActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    .frame(width: 80, height: 48)
                    .background(Color(hex: "212121"))
                    .cornerRadius(35)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                // Scrollable Content
                if filteredReports.isEmpty && filteredDocuments.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: isFilteringActive ? "Nessun risultato" : "Nessun report disponibile",
                        subtitle: isFilteringActive ? "Prova a modificare filtri o ricerca." : "Esegui un analisi pneumatici per generare il tuo primo report."
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18, pinnedViews: []) {
                            ForEach(filteredReports) { report in
                                ReportCard(
                                    vehicleName: report.title,
                                    description: report.description,
                                    reportType: report.type,
                                    date: report.date,
                                    tireData: report.data,
                                    onPreview: { preview(report) },
                                    onShare: { export(report) },
                                    onDownload: { export(report) }
                                )
                            }
                            
                            ForEach(filteredDocuments) { doc in
                                DocumentCard(
                                    title: doc.title,
                                    subtitle: doc.subtitle,
                                    date: doc.date,
                                    iconColor: doc.tint,
                                    icon: doc.icon,
                                    onOpen: { open(doc) },
                                    onShare: { share(doc) },
                                    onDownload: { share(doc) }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 16)
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showFilterSheet) {
            ReportsFilterSheet(filter: $contentFilter)
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showReportPreview) {
            if let previewURL {
                ReportFilePreviewView(
                    title: previewTitle,
                    url: previewURL
                )
            }
        }
        .sheet(isPresented: $showAttachmentViewer) {
            if let selectedAttachment {
                AttachmentViewerView(attachment: selectedAttachment)
            }
        }
        .alert("Export non riuscito", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "Riprova tra poco.")
        }
        .onAppear {
            loadTreadMeasurements()
        }
    }

    private enum MaintenanceReportFileFormat {
        case pdf
        case csv
    }

    private func makeMaintenanceReport(
        vehicleId: Int?,
        entries: [CompletedMaintenanceEntry],
        format: MaintenanceReportFileFormat
    ) -> ReportItem {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        let totalCost = sortedEntries.compactMap(\.cost).reduce(0, +)
        let attachmentCount = sortedEntries.reduce(0) { count, entry in
            count + attachmentManager.attachments(for: entry.id).count
        }
        let recentCount = sortedEntries.filter {
            Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 <= 365
        }.count
        let dateText = sortedEntries.first.map { formattedDate($0.date) } ?? formattedDate(Date())
        let scopeTitle = vehicleId.map { "Veicolo #\($0)" } ?? "Archivio completo"
        let extensionText = format == .pdf ? "PDF" : "CSV"
        let totalCostBucket = min(Int(totalCost / 100), 100)

        return ReportItem(
            id: "\(extensionText.lowercased())-\(vehicleId.map(String.init) ?? "all")",
            title: "\(scopeTitle) - manutenzioni",
            description: "\(sortedEntries.count) interventi registrati. Totale \(currencyText(totalCost)).",
            type: "Manutenzione \(extensionText)",
            date: dateText,
            data: TireData1(
                frontLeft: min(sortedEntries.count, 100),
                frontRight: totalCostBucket,
                rearLeft: min(attachmentCount, 100),
                rearRight: min(recentCount, 100)
            ),
            exportKind: format == .pdf ? .maintenancePDF(vehicleId: vehicleId) : .maintenanceCSV(vehicleId: vehicleId)
        )
    }

    private func makeTyreTechnicalReport(_ measurement: TreadDepthMeasurement) -> ReportItem {
        let remainingPercent = estimatedRemainingPercentage(for: measurement)
        let confidence = min(Int(measurement.confidenceScore.rounded()), 100)

        return ReportItem(
            id: "tyre-analysis-\(measurement.id.uuidString)",
            title: "Analisi pneumatico",
            description: "\(measurement.treadStatus.displayName). Profondità media \(String(format: "%.2f", measurement.averageDepth)) mm, minima \(String(format: "%.2f", measurement.minDepth)) mm.",
            type: "Analisi pneumatico PDF",
            date: formattedDate(measurement.timestamp),
            data: TireData1(
                frontLeft: min(Int(measurement.averageDepth * 10), 100),
                frontRight: remainingPercent,
                rearLeft: confidence,
                rearRight: min(Int(measurement.standardDeviation * 20), 100)
            ),
            exportKind: .tyreTechnicalPDF(measurementId: measurement.id)
        )
    }

    private func export(_ report: ReportItem) {
        Task {
            guard let url = await prepareReportURL(report) else {
                exportErrorMessage = "Non sono riuscito a preparare \(report.type)."
                return
            }

            shareURL = url
            showShareSheet = true
        }
    }

    private func preview(_ report: ReportItem) {
        Task {
            guard let url = await prepareReportURL(report) else {
                exportErrorMessage = "Non sono riuscito a preparare l'anteprima di \(report.type)."
                return
            }

            previewURL = url
            previewTitle = report.title
            showReportPreview = true
        }
    }

    private func prepareReportURL(_ report: ReportItem) async -> URL? {
        switch report.exportKind {
        case .maintenancePDF(let vehicleId):
            return MaintenancePDFReportBuilder.generateReport(
                entries: maintenanceEntries(for: vehicleId),
                vehicleId: vehicleId ?? 0
            )
        case .maintenanceCSV(let vehicleId):
            return MaintenanceCSVExporter.exportToFile(entries: maintenanceEntries(for: vehicleId))
        case .tyreTechnicalPDF(let measurementId):
            guard let measurement = treadMeasurements.first(where: { $0.id == measurementId }) else {
                return nil
            }
            let snapshot = await vehicleSnapshot(for: measurement)
            return TyreTechnicalPDFReportBuilder.generateReport(measurement: measurement, vehicleSnapshot: snapshot)
        }
    }

    private func vehicleSnapshot(for measurement: TreadDepthMeasurement) async -> UIImage? {
        guard let vehicle = cachedVehicle(for: measurement),
              let make = vehicle.vehicle.make?.trimmingCharacters(in: .whitespacesAndNewlines),
              let model = vehicle.vehicle.model?.trimmingCharacters(in: .whitespacesAndNewlines),
              !make.isEmpty,
              !model.isEmpty else {
            return nil
        }

        let modelFamily = model
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .first ?? model.lowercased()
        let year = vehicle.plate?.year.map(String.init)
            ?? vehicle.vehicle.saleStart?.components(separatedBy: CharacterSet(charactersIn: "-/")).first
            ?? Calendar.current.component(.year, from: Date()).description
        let paintId = vehicle.vehicle.color?.uppercased() ?? "BLACK"

        return await withCheckedContinuation { continuation in
            VehicleImageService.fetchVehicleImage(
                make: make.lowercased(),
                modelFamily: modelFamily,
                year: year,
                paintId: paintId,
                angle: 12,
                plate: vehicle.plate?.plateNumber ?? ""
            ) { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func cachedVehicle(for measurement: TreadDepthMeasurement) -> VehicleResponse? {
        guard let data = UserDefaults.standard.data(forKey: "cachedVehicles"),
              let vehicles = try? JSONDecoder().decode([VehicleResponse].self, from: data),
              !vehicles.isEmpty else {
            return nil
        }

        // TreadDepthMeasurement currently stores tyreId as UUID, while garage tyres use Int ids.
        // Until the scan model carries vehicleId or a shared tyre identifier, use the cached primary vehicle.
        return vehicles.first
    }

    private func open(_ document: DocumentItem) {
        selectedAttachment = document.attachment
        showAttachmentViewer = true
    }

    private func share(_ document: DocumentItem) {
        shareURL = attachmentManager.fileURL(for: document.attachment)
        showShareSheet = true
    }

    private func maintenanceEntries(for vehicleId: Int?) -> [CompletedMaintenanceEntry] {
        guard let vehicleId else { return historyStore.entries }
        return historyStore.entries(for: vehicleId)
    }

    private func loadTreadMeasurements() {
        guard let data = UserDefaults.standard.data(forKey: "tread_measurement_history") else {
            treadMeasurements = []
            return
        }

        let decoder = JSONDecoder()
        treadMeasurements = (try? decoder.decode([TreadDepthMeasurement].self, from: data)) ?? []
    }

    private func estimatedRemainingPercentage(for measurement: TreadDepthMeasurement) -> Int {
        let legalLimit = 1.6
        let referenceNewDepth = 8.0
        let usableDepth = max(referenceNewDepth - legalLimit, 0.1)
        let remaining = max(min((measurement.minDepth - legalLimit) / usableDepth, 1.0), 0.0)
        return Int((remaining * 100).rounded())
    }

    private func documentSubtitle(
        for attachment: AttachmentManager.Attachment,
        entry: CompletedMaintenanceEntry?
    ) -> String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(attachment.fileSize), countStyle: .file)
        let type = attachment.type == .pdf ? "PDF" : "Foto"
        if let entry {
            return "\(type) • \(entry.maintenanceType?.localizedName ?? entry.source.label) • \(size)"
        }
        return "\(type) • \(size)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func currencyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }
}

// MARK: - Report Card Component
struct ReportCard: View {
    let vehicleName: String
    let description: String
    let reportType: String
    let date: String
    let tireData: TireData1
    var onPreview: () -> Void = {}
    var onShare: () -> Void = {}
    var onDownload: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top bar
            HStack {
                    Text(reportType.uppercased())
                    .font(.customFont(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                
                Spacer()
                
                HStack(spacing: 14) {
                    Button(action: onPreview) {
                        Image(systemName: "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: onShare) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Title & description
            VStack(alignment: .leading, spacing: 6) {
                Text(vehicleName)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.customFont(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(3)
            }
            
            // Tire Data grid
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    TireDataRow(label: "Front Left:", value: "\(tireData.frontLeft)%")
                    TireDataRow(label: "Rear Left:", value: "\(tireData.rearLeft)%")
                }
                VStack(alignment: .leading, spacing: 10) {
                    TireDataRow(label: "Front Right:", value: "\(tireData.frontRight)%")
                    TireDataRow(label: "Rear Right:", value: "\(tireData.rearRight)%")
                }
            }
            .padding(.vertical, 6)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Date row
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(date)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "212121"))
        )
    }
}

// MARK: - Tire Data Row
struct TireDataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
            
            Spacer()
            
            Text(value)
                .font(.customFont(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Report File Preview
struct ReportFilePreviewView: View {
    let title: String
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    private var isPDF: Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    private var fileText: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? "Anteprima non disponibile."
    }

    var body: some View {
        NavigationStack {
            Group {
                if isPDF {
                    PDFViewer(url: url)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(fileText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [url])
            }
        }
    }
}

// MARK: - Document Card Component
struct DocumentCard: View {
    let title: String
    let subtitle: String
    let date: String
    let iconColor: Color
    let icon: String
    var onOpen: () -> Void = {}
    var onShare: () -> Void = {}
    var onDownload: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor)
                    .frame(width: 52, height: 74)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.customFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(date)
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onShare) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "212121"))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onOpen)
    }
}

// MARK: - Depth Indicator Component
struct DepthIndicator: View {
    let measurement: TireDepthMeasurement
    let isSelected: Bool
    
    var depthColor: Color {
        if measurement.depth > 5.0 {
            return Color.green
        } else if measurement.depth > 3.0 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Lines Pattern (when not selected)
            if !isSelected {
                VStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(height: 2)
                    }
                }
                .frame(width: 42, height: 61)
                .offset(y: -4)
            }
            
            // Measurement Box
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [Color(hex: "5CEBFF"), Color(hex: "2FB8FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .frame(width: 42, height: 72)
                    .opacity(isSelected ? 1.0 : 0.6)
                
                // Depth Value Display (when selected)
                if isSelected {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", measurement.depth))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(depthColor)
                        
                        Text("mm")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Glow Effect
                if isSelected {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(depthColor, lineWidth: 3)
                        .frame(width: 44, height: 74)
                        .blur(radius: 4)
                        .opacity(0.6)
                }
            }
        }
    }
}

// MARK: - Tire Depth Measurement Model
struct TireDepthMeasurement {
    let position: TirePosition
    let depth: Double // in millimeters
    
    var status: DepthStatus {
        if depth > 5.0 {
            return .good
        } else if depth > 3.0 {
            return .medium
        } else {
            return .critical
        }
    }
}

// MARK: - Depth Status Enum
enum DepthStatus {
    case good
    case medium
    case critical
    
    var color: Color {
        switch self {
        case .good: return .green
        case .medium: return .yellow
        case .critical: return .red
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Good Condition"
        case .medium: return "Monitor Closely"
        case .critical: return "Replace Soon"
        }
    }
}

// MARK: - Reports Filter Sheet
struct ReportsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ReportContentFilter
    @State private var tempFilter: ReportContentFilter

    init(filter: Binding<ReportContentFilter>) {
        self._filter = filter
        self._tempFilter = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.customAzure, .customBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Filtra i tuoi contenuti")
                        .font(.customFont(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Mostra")
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Picker("Mostra", selection: $tempFilter) {
                        ForEach(ReportContentFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.customFieldColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                Spacer()
            }
            .padding()
            .background(Color.customBackgroundColor)
            .navigationTitle("Filtri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Applica") {
                        filter = tempFilter
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
struct TireProfileDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsDocumentationsView()
        
    }
}
