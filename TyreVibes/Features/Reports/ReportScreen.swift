import SwiftUI

struct TireData1 {
    let frontLeft: Int
    let frontRight: Int
    let rearLeft: Int
    let rearRight: Int
}

struct ReportItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let type: String
    let date: String
    let data: TireData1
}

struct DocumentItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let date: String
    let icon: String
    let tint: Color
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
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var contentFilter: ReportContentFilter = .all

    private let reports: [ReportItem] = []

    private let documents: [DocumentItem] = []

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
                                    tireData: report.data
                                )
                            }
                            
                            ForEach(filteredDocuments) { doc in
                                DocumentCard(
                                    title: doc.title,
                                    subtitle: doc.subtitle,
                                    date: doc.date,
                                    iconColor: doc.tint,
                                    icon: doc.icon
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
    }
}

// MARK: - Report Card Component
struct ReportCard: View {
    let vehicleName: String
    let description: String
    let reportType: String
    let date: String
    let tireData: TireData1
    
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
                    Button(action: {}) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {}) {
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

// MARK: - Document Card Component
struct DocumentCard: View {
    let title: String
    let subtitle: String
    let date: String
    let iconColor: Color
    let icon: String
    
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
                Button(action: {}) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
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
