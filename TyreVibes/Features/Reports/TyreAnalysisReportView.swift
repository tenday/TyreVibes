//
//  TyreAnalysisReportView.swift
//  TyreVibes
//
//  View for displaying and sharing comprehensive tyre analysis reports
//

import SwiftUI
import PDFKit

struct TyreAnalysisReportView: View {
    let report: TyreAnalysisReport
    @StateObject private var reportGenerator = TyreAnalysisReportGenerator()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var selectedExportFormat: ReportExportFormat = .pdf

    private let tabs = ["Overview", "Heat Map", "Charts", "Recommendations"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with vehicle info
                    headerView

                    // Tab selector
                    tabSelector

                    // Content
                    TabView(selection: $selectedTab) {
                        overviewTab.tag(0)
                        heatMapTab.tag(1)
                        chartsTab.tag(2)
                        recommendationsTab.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text("Analysis Report")
                    .font(.customFont(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Menu {
                    Button(action: { exportReport(.pdf) }) {
                        Label("Export PDF", systemImage: "doc.fill")
                    }
                    Button(action: { exportReport(.json) }) {
                        Label("Export JSON", systemImage: "doc.text.fill")
                    }
                    Button(action: { exportReport(.image(format: .png)) }) {
                        Label("Export Image", systemImage: "photo.fill")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Vehicle info
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(report.metadata.vehicle.make) \(report.metadata.vehicle.model)")
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(report.metadata.tyre.brand) \(report.metadata.tyre.model) • \(report.metadata.tyre.size)")
                        .font(.customFont(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Safety score badge
                ZStack {
                    Circle()
                        .fill(report.safetyScore.rating.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    VStack(spacing: 2) {
                        Text("\(Int(report.safetyScore.overall))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(report.safetyScore.rating.color)

                        Text("SCORE")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }) {
                        Text(tab)
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTab == index ? Color(hex: "FF6B6B") : Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Safety status card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Safety Status")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.safetyScore.rating.rawValue)
                                .font(.customFont(size: 24, weight: .bold))
                                .foregroundColor(report.safetyScore.rating.color)

                            Text(report.safetyScore.rating.description)
                                .font(.customFont(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: report.safetyScore.rating == .excellent ? "checkmark.seal.fill" :
                                report.safetyScore.rating == .critical ? "exclamationmark.triangle.fill" :
                                "info.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(report.safetyScore.rating.color)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )

                // Key metrics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Metrics")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    metricRow(label: "Average Depth", value: String(format: "%.2f mm", report.depthAnalysis.average))
                    metricRow(label: "Min Depth", value: String(format: "%.2f mm", report.depthAnalysis.minimum))
                    metricRow(label: "Max Depth", value: String(format: "%.2f mm", report.depthAnalysis.maximum))
                    metricRow(label: "Legal Status", value: report.depthAnalysis.legalStatus.rawValue)
                    metricRow(label: "Wear Pattern", value: report.wearAnalysis.pattern.rawValue)
                    metricRow(label: "Remaining Life", value: report.remainingLife.formattedDistance)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )

                // Life estimate
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remaining Life Estimate")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.remainingLife.formattedDistance)
                                .font(.customFont(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("or approximately \(report.remainingLife.estimatedMonths) months")
                                .font(.customFont(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text("Confidence")
                                .font(.customFont(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Text("\(Int(report.remainingLife.confidence * 100))%")
                                .font(.customFont(size: 20, weight: .bold))
                                .foregroundColor(report.remainingLife.status.color)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Heat Map Tab
    private var heatMapTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeatMapView(
                    heatMap: report.heatMap,
                    minDepth: report.depthAnalysis.minimum,
                    maxDepth: report.depthAnalysis.maximum
                )

                HeatMapStatisticsPanel(
                    heatMap: report.heatMap,
                    depthAnalysis: report.depthAnalysis
                )
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Charts Tab
    private var chartsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                SafetyScoreGauge(safetyScore: report.safetyScore)

                DepthDistributionChart(distribution: report.depthAnalysis.depthDistribution)

                ZoneWearComparisonChart(zoneAnalysis: report.wearAnalysis.zoneAnalysis)

                DepthProjectionChart(projections: report.remainingLife.projectedDepthCurve)

                if !report.remainingLife.factors.isEmpty {
                    LifeFactorsChart(factors: report.remainingLife.factors)
                }

                ScoreComponentsChart(components: report.safetyScore.components)
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Recommendations Tab
    private var recommendationsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(report.recommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Helper Views
    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Export Functions
    private func exportReport(_ format: ReportExportFormat) {
        selectedExportFormat = format

        if let url = reportGenerator.shareReport(report, format: format) {
            shareURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Recommendation Card
struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Priority badge
                HStack(spacing: 6) {
                    Image(systemName: recommendation.priority.icon)
                        .font(.system(size: 12))
                    Text(recommendation.priority.rawValue)
                        .font(.customFont(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(recommendation.priority.color)
                )

                Spacer()

                // Category
                Text(recommendation.category.rawValue)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Text(recommendation.title)
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(recommendation.description)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FF6B6B"))

                Text(recommendation.action)
                    .font(.customFont(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "FF6B6B"))
            }
            .padding(.top, 4)

            // Urgency indicator
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Text(recommendation.urgency.rawValue)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(recommendation.priority.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#if DEBUG
struct TyreAnalysisReportView_Previews: PreviewProvider {
    static var previews: some View {
        TyreAnalysisReportView(report: mockReport)
    }

    static var mockReport: TyreAnalysisReport {
        TyreAnalysisReport(
            metadata: ReportMetadata(
                reportId: "ABC123",
                timestamp: Date(),
                vehicle: VehicleInfo(
                    make: "Tesla",
                    model: "Model 3",
                    year: 2021,
                    plateNumber: "AB123CD",
                    vin: "5YJ3E1EA1LF000001"
                ),
                tyre: TyreInfo(
                    brand: "Pirelli",
                    model: "P Zero",
                    size: "245/35 R19",
                    dot: "3522",
                    position: .frontLeft,
                    season: "Summer",
                    loadIndex: "96",
                    speedRating: "Y"
                ),
                location: nil,
                weather: nil,
                analysisType: .comprehensive
            ),
            depthAnalysis: DepthAnalysis(
                average: 5.5,
                minimum: 4.2,
                maximum: 6.8,
                standardDeviation: 0.8,
                measurements: [],
                legalStatus: .legal,
                depthDistribution: DepthAnalysis.DepthDistribution(
                    excellent: 10,
                    good: 25,
                    fair: 15,
                    poor: 0,
                    critical: 0
                )
            ),
            wearAnalysis: WearAnalysis(
                pattern: .uniform,
                severity: .moderate,
                unevenWearIndex: 0.15,
                zoneAnalysis: [],
                causes: []
            ),
            heatMap: DepthHeatMap(
                gridSize: DepthHeatMap.GridSize(rows: 20, columns: 20),
                dataPoints: Array(repeating: Array(repeating: 5.5, count: 20), count: 20),
                colorScheme: .thermal,
                interpolated: true
            ),
            remainingLife: RemainingLifeEstimate(
                estimatedKilometers: 15000,
                estimatedMonths: 12,
                confidence: 0.85,
                calculationMethod: .exponential,
                factors: [],
                projectedDepthCurve: []
            ),
            recommendations: [],
            safetyScore: SafetyScore(
                overall: 82,
                rating: .good,
                components: SafetyScore.ScoreComponents(
                    depthScore: 0.85,
                    wearPatternScore: 0.90,
                    uniformityScore: 0.88,
                    legalComplianceScore: 1.0,
                    conditionScore: 0.75
                )
            )
        )
    }
}
#endif
