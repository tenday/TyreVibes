//
//  TyreDetailScreen.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 14/09/25.
//

import SwiftUI
import Charts

struct TyreDetailView: View {
    let tyre: TyreRegistered?
    var onConfirmCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TyreDetailViewModel
    @State private var selectedTyre = "FL"
    @State private var isReady = false

    init(tyre: TyreRegistered?, onConfirmCompletion: (() -> Void)? = nil) {
        self.tyre = tyre
        self.onConfirmCompletion = onConfirmCompletion

        // Initialize ViewModel with tyre data or default
        if let tyre = tyre {
            _viewModel = StateObject(wrappedValue: TyreDetailViewModel(tyre: tyre))
        } else {
            // Default tyre for preview
            _viewModel = StateObject(wrappedValue: TyreDetailViewModel(tyre: TyreRegistered(
                id: 1,
                vehicleId: 1,
                brand: "Michelin",
                model: "Pilot Sport 4",
                size: "225/40R18",
                dot: "1221",
                loadIndex: "92",
                speedRating: "Y",
                season: "Summer"
            )))
        }
    }

    var tyreName: String {
        guard let tyre = tyre else { return "Tyre Name" }
        return "\(tyre.brand) \(tyre.model)"
    }

    var tyreSetDisplay: String {
        guard let tyre = tyre else { return "N/A" }
        if let name = tyre.setName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let setId = tyre.setId, setId > 0 {
            return "Set \(setId)"
        }
        return "N/A"
    }

    var remainingLifeColor: Color {
        let percentage = viewModel.remainingLifePercentage
        if percentage >= 0.7 {
            return .cyan
        } else if percentage >= 0.5 {
            return .green
        } else if percentage >= 0.3 {
            return .yellow
        } else {
            return .orange
        }
    }

    var tyreInsights: [TyreInsightDisplay] {
        guard let tyre else { return [] }
        return makeTyreInsights(from: [tyre])
    }

    @ViewBuilder
    private var analysisNotice: some View {
        switch viewModel.analysisStatus {
        case .missing:
            AnalysisNoticeCard(
                title: L10n.noAnalysisYet.localized,
                message: L10n.runScanToSeeDetails.localized,
                icon: "exclamationmark.triangle.fill",
                accentColor: .orange
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        case .error:
            AnalysisNoticeCard(
                title: L10n.analysisUnavailable.localized,
                message: L10n.unableToLoadAnalysis.localized,
                icon: "xmark.octagon.fill",
                accentColor: .red
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        default:
            EmptyView()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                        // Header with tyre info
                        if let tyre = tyre {
                            VStack(alignment: .leading, spacing: 16) {
                                InfoRow(label: String(localized: "Make"), value: tyre.brand)
                                InfoRow(label: String(localized: "Model"), value: tyre.model)
                                InfoRow(label: String(localized: "Season"), value: tyre.season)
                                InfoRow(label: String(localized: "Tyre Set"), value: tyreSetDisplay)
                                InfoRow(label: String(localized: "DOT"), value: tyre.dot)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }

                        // Tyre visual representation
                        
                            Spacer()
                            TyreVisualizationView()
                            .frame(width: 200, height: 200)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                        .padding(.bottom, 30)

                        analysisNotice

                        if !tyreInsights.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Tyre Smart Insights")
                                        .font(.customFont(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                VStack(spacing: 12) {
                                    ForEach(tyreInsights) { insight in
                                        TyreInsightRow(insight: insight)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 30)
                        }

                        // Tread depth measurements
                        if viewModel.hasAnalysis, let treadData = viewModel.treadDepthData {
                            VStack(spacing: 20) {
                                HStack(spacing: 40) {
                                    TreadDepthCard(
                                        position: treadData.frontLeft.position,
                                        depth: treadData.frontLeft.formattedDepth,
                                        progress: treadData.frontLeft.progress,
                                        color: treadData.frontLeft.color
                                    )

                                    TreadDepthCard(
                                        position: treadData.frontRight.position,
                                        depth: treadData.frontRight.formattedDepth,
                                        progress: treadData.frontRight.progress,
                                        color: treadData.frontRight.color
                                    )
                                }

                                HStack(spacing: 40) {
                                    TreadDepthCard(
                                        position: treadData.rearLeft.position,
                                        depth: treadData.rearLeft.formattedDepth,
                                        progress: treadData.rearLeft.progress,
                                        color: treadData.rearLeft.color
                                    )

                                    TreadDepthCard(
                                        position: treadData.rearRight.position,
                                        depth: treadData.rearRight.formattedDepth,
                                        progress: treadData.rearRight.progress,
                                        color: treadData.rearRight.color
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }

                        // Remaining life
                        if viewModel.hasAnalysis {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {

                                    Text("Remaining Life")
                                        .font(.customFont(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top)

                                HStack {
                                    Text("\(Int(viewModel.remainingLifePercentage * 100))%")
                                        .font(.customFont(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal)

                                ProgressView(value: viewModel.remainingLifePercentage)
                                    .progressViewStyle(CustomProgressViewStyle(color: remainingLifeColor))
                                    //.frame(height: 12)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.customFieldColor)
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                        }
                        
                        

                        // Tire Lifecycle Chart
                        if viewModel.hasAnalysis, let lifeEstimate = viewModel.remainingLifeEstimate {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Tire Lifecycle")
                                        .font(.customFont(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top)

                                TireLifecycleChart(
                                    projections: lifeEstimate.projectedDepthCurve,
                                    estimatedKm: lifeEstimate.estimatedKilometers,
                                    estimatedMonths: lifeEstimate.estimatedMonths
                                )
                                    .padding()
                            }
                            .background(Color.customFieldColor)
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                        }

                        

                        // Tire Condition
                        if viewModel.hasAnalysis, let conditionData = viewModel.tireConditionData {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Tire Condition")
                                        .font(.customFont(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()

                                HStack(spacing: 20) {
                                    TireConditionIcon()

                                    HStack(spacing: 20) {
                                        TireConditionBar(
                                            position: "FL",
                                            percentage: conditionData.frontLeft,
                                            color: conditionData.color(for: "FL")
                                        )
                                        TireConditionBar(
                                            position: "FR",
                                            percentage: conditionData.frontRight,
                                            color: conditionData.color(for: "FR")
                                        )
                                        TireConditionBar(
                                            position: "RL",
                                            percentage: conditionData.rearLeft,
                                            color: conditionData.color(for: "RL")
                                        )
                                        TireConditionBar(
                                            position: "RR",
                                            percentage: conditionData.rearRight,
                                            color: conditionData.color(for: "RR")
                                        )
                                    }

                                }
                                //.padding()
                                
                            }
                            .background(Color.customFieldColor)
                            .cornerRadius(14)
                            .padding()
                        }
                    }
                }
                .opacity(isReady ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isReady)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onConfirmCompletion?()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(tyreName)
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Export/Share functionality
                    }) {
                        Image("downloadIcon")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                
            }
            .scrollIndicators(.hidden)

        }
        .task {
            // Load tyre data
            await viewModel.loadTyreData()

            // Ensure NavigationStack and fonts are properly initialized before showing content
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            withAnimation {
                isReady = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.gray)

            Text(value)
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tyre Visualization
struct TyreVisualizationView: View {
    var body: some View {
        ZStack {
            Image("tyreElements")
                .resizable()
                .scaledToFit()
                .frame(width: 253, height: 396)
                .offset(y : -70)
            Image("tyreDetails")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 208)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                .offset(x: -60, y: 10)
        }
    }
}

// MARK: - Tread Depth Card
struct TreadDepthCard: View {
    let position: String
    let depth: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tread Depth")
                    .font(.customFont(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text(position)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(depth)
                .font(.customFont(size: 20, weight: .bold))
                .foregroundColor(.white)

            ProgressView(value: progress)
                .progressViewStyle(CustomProgressViewStyle(color: color))
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.customFieldColor)
        .cornerRadius(14)
    }
}

// MARK: - Custom Progress View Style
struct CustomProgressViewStyle: ProgressViewStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .cornerRadius(15)

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 12)
                    .cornerRadius(15)
            }
        }
    }
}

// MARK: - Tire Lifecycle Chart
struct TireLifecycleChart: View {
    let projections: [DepthProjection]
    let estimatedKm: Double
    let estimatedMonths: Int

    @State private var selectedPoint: ChartDataPoint?

    var historicalData: [ChartDataPoint] {
        projections
            .filter { $0.kilometersFromNow <= 0 }
            .map { ChartDataPoint(
                distance: Int(abs($0.kilometersFromNow / 1000)),
                depth: $0.projectedDepth,
                isProjected: false
            )}
    }

    var projectedData: [ChartDataPoint] {
        let currentPoint = projections.first { $0.kilometersFromNow == 0 }
        let futureProjections = projections.filter { $0.kilometersFromNow >= 0 }

        return futureProjections.map { ChartDataPoint(
            distance: Int($0.kilometersFromNow / 1000),
            depth: $0.projectedDepth,
            isProjected: true
        )}
    }

    let legalMinimum: Double = 1.6
    let warningThreshold: Double = 3.0
    let optimalThreshold: Double = 6.0

    var body: some View {
        VStack(spacing: 16) {
            mainChart
            legendAndInfo
        }
    }

    private var mainChart: some View {
        Chart {
            safetyZones
            legalMinimumLine
            historicalAreaMarks
            historicalLineMarks
            historicalPointMarks
            projectedAreaMarks
            projectedLineMarks
            projectedPointMarks
        }
        .chartXScale(domain: 0...35)
        .chartYScale(domain: 0...12)
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)K").foregroundColor(.gray).font(.system(size: 11))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 2, 4, 6, 8, 10, 12]) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.0f", doubleValue)).foregroundColor(.gray).font(.system(size: 11))
                    }
                }
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .cornerRadius(12)
    }

    @ChartContentBuilder
    private var safetyZones: some ChartContent {
        RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", 35), yStart: .value("Bottom", 0), yEnd: .value("Top", legalMinimum))
            .foregroundStyle(Color.red.opacity(0.15))
        RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", 35), yStart: .value("Bottom", legalMinimum), yEnd: .value("Top", warningThreshold))
            .foregroundStyle(Color.orange.opacity(0.1))
        RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", 35), yStart: .value("Bottom", warningThreshold), yEnd: .value("Top", optimalThreshold))
            .foregroundStyle(Color.yellow.opacity(0.08))
        RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", 35), yStart: .value("Bottom", optimalThreshold), yEnd: .value("Top", 12))
            .foregroundStyle(Color.green.opacity(0.1))
    }

    @ChartContentBuilder
    private var legalMinimumLine: some ChartContent {
        RuleMark(y: .value("Legal Min", legalMinimum))
            .foregroundStyle(Color.red)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
    }

    @ChartContentBuilder
    private var historicalAreaMarks: some ChartContent {
        ForEach(historicalData, id: \.distance) { point in
            AreaMark(x: .value("Distance", point.distance), yStart: .value("Min", 0), yEnd: .value("Depth", point.depth))
                .foregroundStyle(LinearGradient(colors: [depthColor(point.depth).opacity(0.5), depthColor(point.depth).opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var historicalLineMarks: some ChartContent {
        ForEach(historicalData, id: \.distance) { point in
            LineMark(x: .value("Distance", point.distance), y: .value("Tread Depth", point.depth))
                .foregroundStyle(depthColor(point.depth))
                .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var historicalPointMarks: some ChartContent {
        ForEach(historicalData, id: \.distance) { point in
            PointMark(x: .value("Distance", point.distance), y: .value("Tread Depth", point.depth))
                .foregroundStyle(depthColor(point.depth))
                .symbolSize(80)
        }
    }

    @ChartContentBuilder
    private var projectedAreaMarks: some ChartContent {
        ForEach(projectedData, id: \.distance) { point in
            AreaMark(x: .value("Distance", point.distance), yStart: .value("Min", 0), yEnd: .value("Depth", point.depth))
                .foregroundStyle(LinearGradient(colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var projectedLineMarks: some ChartContent {
        ForEach(projectedData, id: \.distance) { point in
            LineMark(x: .value("Distance", point.distance), y: .value("Tread Depth", point.depth))
                .foregroundStyle(Color.cyan.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
                .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var projectedPointMarks: some ChartContent {
        ForEach(projectedData.dropFirst(), id: \.distance) { point in
            PointMark(x: .value("Distance", point.distance), y: .value("Tread Depth", point.depth))
                .foregroundStyle(Color.cyan.opacity(0.6))
                .symbolSize(40)
        }
    }

    private var legendAndInfo: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                ChartLegendItem(color: .green, text: "Optimal (>6mm)")
                ChartLegendItem(color: .orange, text: "Warning (<3mm)")
                ChartLegendItem(color: .red, text: "Replace (<1.6mm)")
            }
            HStack(spacing: 16) {
                InfoPill(
                    icon: "calendar",
                    text: "~\(Int(estimatedKm / 1000))K km remaining",
                    color: .cyan
                )
                InfoPill(
                    icon: "calendar.badge.clock",
                    text: "Replace in ~\(estimatedMonths) months",
                    color: estimatedMonths < 6 ? .orange : .cyan
                )
            }
        }
        .padding(.top, 8)
    }

    private func depthColor(_ depth: Double) -> Color {
        if depth >= optimalThreshold {
            return .green
        } else if depth >= warningThreshold {
            return .yellow
        } else if depth >= legalMinimum {
            return .orange
        } else {
            return .red
        }
    }
}

struct ChartDataPoint: Equatable {
    let distance: Int
    let depth: Double
    let isProjected: Bool

    init(distance: Int, depth: Double, isProjected: Bool = false) {
        self.distance = distance
        self.depth = depth
        self.isProjected = isProjected
    }
}

// MARK: - Chart Legend Item
struct ChartLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Info Pill
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Analysis Notice Card
struct AnalysisNoticeCard: View {
    let title: String
    let message: String
    let icon: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.customFont(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color.customFieldColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

// MARK: - Tire Dimension Row
struct TireDimensionRow: View {
    let label: String
    let dimension: String
    let isRecommended: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.customFont(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)

            Text(dimension)
                .font(.customFont(size: 16, weight: .medium))
                .foregroundColor(.white)

            if isRecommended {
                Spacer()
                Text("Recommended")
                    .font(.customFont(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
            }

            Spacer()
        }
    }
}

// MARK: - Tire Condition Icon
struct TireConditionIcon: View {
    var body: some View {
        Image("tyreDetails")
            .resizable()
            .scaledToFit()
            .frame(height: 132)
        }
    
    
}


// MARK: - Tire Condition Bar
struct TireConditionBar: View {
    let position: String
    let percentage: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(color)
                    .frame(width: 26, height: CGFloat(percentage))
                    .cornerRadius(6)

                Text("\(percentage)%")
                    .font(.customFont(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
            .frame(height: 80, alignment: .bottom)
            
            Text(position)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TyreDetailView(tyre: TyreRegistered(id: 1, vehicleId: 1, brand: "Michelin", model: "Pilot Sport 4", size: "225/40R18", dot: "1221", loadIndex: "92", speedRating: "Y", season: "Summer"))
}
