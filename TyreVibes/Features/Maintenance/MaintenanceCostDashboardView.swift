import SwiftUI
import Charts

struct MaintenanceCostDashboardView: View {
    let vehicleId: Int

    @StateObject private var viewModel: MaintenanceCostViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExportSheet = false

    init(vehicleId: Int) {
        self.vehicleId = vehicleId
        _viewModel = StateObject(wrappedValue: MaintenanceCostViewModel(vehicleId: vehicleId))
    }

    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        return f
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector
                    summaryCards
                    if !viewModel.costByCategory.isEmpty {
                        categoryChart
                    }
                    if viewModel.monthlyTrend.count >= 2 {
                        trendChart
                    }
                    if viewModel.costByCategory.isEmpty && viewModel.monthlyTrend.isEmpty {
                        emptyState
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "#191919"))
            .navigationTitle("Statistiche costi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                MaintenanceExportSheet(vehicleId: vehicleId)
            }
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(MaintenanceCostViewModel.TimeRange.allCases, id: \.self) { range in
                let selected = viewModel.selectedTimeRange == range
                Button {
                    viewModel.selectedTimeRange = range
                    viewModel.onTimeRangeChanged()
                } label: {
                    Text(range.localizedLabel)
                        .font(.customFont(size: 12, weight: .semibold))
                        .foregroundColor(selected ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected ? Color.white : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 10) {
            summaryCard(
                title: "Totale speso",
                value: currencyFormatter.string(from: NSNumber(value: viewModel.totalCost)) ?? "€0",
                icon: "eurosign.circle.fill",
                color: .green
            )
            summaryCard(
                title: "Costo/Km",
                value: String(format: "€%.2f", viewModel.costPerKm),
                icon: "speedometer",
                color: .cyan
            )
            summaryCard(
                title: "Categorie",
                value: "\(viewModel.costByCategory.count)",
                icon: "tag.fill",
                color: .orange
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.customFont(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Category Chart

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spese per categoria")
                .font(.customFont(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Chart(viewModel.costByCategory, id: \.category) { item in
                BarMark(
                    x: .value("Costo", item.cost),
                    y: .value("Categoria", item.category)
                )
                .foregroundStyle(item.color)
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text(currencyFormatter.string(from: NSNumber(value: item.cost)) ?? "")
                        .font(.customFont(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.white.opacity(0.15))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(height: CGFloat(max(viewModel.costByCategory.count, 1) * 50 + 20))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Andamento mensile")
                .font(.customFont(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Chart(viewModel.monthlyTrend, id: \.month) { item in
                LineMark(
                    x: .value("Mese", item.month),
                    y: .value("Costo", item.cost)
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Mese", item.month),
                    y: .value("Costo", item.cost)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.3), .cyan.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                PointMark(
                    x: .value("Mese", item.month),
                    y: .value("Costo", item.cost)
                )
                .foregroundStyle(.cyan)
                .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.white.opacity(0.15))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.white.opacity(0.15))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(height: 200)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            VStack(spacing: 4) {
                Text("Nessun dato disponibile")
                    .font(.customFont(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Text("Registra manutenzioni con costi per vedere le statistiche.")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Export Sheet

struct MaintenanceExportSheet: View {
    let vehicleId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var exportResult: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    exportCSV()
                } label: {
                    Label("Esporta CSV", systemImage: "tablecells")
                }

                Button {
                    exportPDF()
                } label: {
                    Label("Esporta PDF", systemImage: "doc.richtext")
                }
            }
            .navigationTitle("Esporta dati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportResult {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportCSV() {
        let entries = MaintenanceHistoryStore.shared.entries(for: vehicleId)
        if let url = MaintenanceCSVExporter.exportToFile(entries: entries) {
            exportResult = url
            showShareSheet = true
        }
    }

    private func exportPDF() {
        let entries = MaintenanceHistoryStore.shared.entries(for: vehicleId)
        if let url = MaintenancePDFReportBuilder.generateReport(entries: entries, vehicleId: vehicleId) {
            exportResult = url
            showShareSheet = true
        }
    }
}
