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
    @State private var selectedTyre = "FL"

    init(tyre: TyreRegistered? = nil, onConfirmCompletion: (() -> Void)? = nil) {
        self.tyre = tyre
        self.onConfirmCompletion = onConfirmCompletion
    }

    var tyreName: String {
        guard let tyre = tyre else { return "Tyre Name" }
        return "\(tyre.brand) \(tyre.model)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                        // Header with tyre info
                        if let tyre = tyre {
                            VStack(alignment: .leading, spacing: 16) {
                                InfoRow(label: "Make", value: tyre.brand)
                                InfoRow(label: "Model", value: tyre.model)
                                InfoRow(label: "Season", value: tyre.season)
                                InfoRow(label: "DOT", value: tyre.dot)
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

                        // Tread depth measurements
                        VStack(spacing: 20) {
                            HStack(spacing: 40) {
                                TreadDepthCard(
                                    position: "FL",
                                    depth: "7.2 mm",
                                    progress: 0.9,
                                    color: .green
                                )

                                TreadDepthCard(
                                    position: "FR",
                                    depth: "7.2 mm",
                                    progress: 0.9,
                                    color: .green
                                )
                            }

                            HStack(spacing: 40) {
                                TreadDepthCard(
                                    position: "RL",
                                    depth: "4.0 mm",
                                    progress: 0.5,
                                    color: .orange
                                )

                                TreadDepthCard(
                                    position: "RR",
                                    depth: "2.5 mm",
                                    progress: 0.25,
                                    color: .red
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)

                        // Remaining life
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
                                Text("80%")
                                    .font(.customFont(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ProgressView(value: 0.8)
                                .progressViewStyle(CustomProgressViewStyle(color: .cyan))
                                //.frame(height: 12)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.customFieldColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        
                        

                        // Tire Lifecycle Chart
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Tire Lifecycle")
                                    .font(.customFont(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top)

                            TireLifecycleChart()
                                .padding()
                        }
                        .background(Color.customFieldColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 30)

                        

                        // Tire Condition
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
                                    TireConditionBar(position: "FL", percentage: 70, color: .green)
                                    TireConditionBar(position: "FR", percentage: 80, color: .green)
                                    TireConditionBar(position: "RL", percentage: 50, color: .orange)
                                    TireConditionBar(position: "RR", percentage: 35, color: .red)
                                }

                            }
                            //.padding()
                            
                        }
                        .background(Color.customFieldColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onConfirmCompletion?()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
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
    @State private var selectedPoint: ChartDataPoint?

    let historicalData: [ChartDataPoint] = [
        ChartDataPoint(distance: 0, depth: 10.0, isProjected: false),
        ChartDataPoint(distance: 5, depth: 8.5, isProjected: false),
        ChartDataPoint(distance: 10, depth: 7.2, isProjected: false),
        ChartDataPoint(distance: 15, depth: 5.8, isProjected: false),
        ChartDataPoint(distance: 20, depth: 4.5, isProjected: false)
    ]

    let projectedData: [ChartDataPoint] = [
        ChartDataPoint(distance: 20, depth: 4.5, isProjected: true),
        ChartDataPoint(distance: 25, depth: 3.0, isProjected: true),
        ChartDataPoint(distance: 30, depth: 1.8, isProjected: true),
        ChartDataPoint(distance: 32, depth: 1.6, isProjected: true)
    ]

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
                InfoPill(icon: "calendar", text: "~12K km remaining", color: .cyan)
                InfoPill(icon: "calendar.badge.clock", text: "Replace by Mar 2026", color: .orange)
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
                    .frame(height: 80, alignment: .bottom)
                Text("\(percentage)%")
                    .font(.customFont(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(position)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TyreDetailView(tyre: TyreRegistered(id: 1, vehicleId: 1, brand: "Michelin", model: "Pilot Sport 4", size: "225/40R18", dot: "1221", loadIndex: "92", speedRating: "Y", season: "Summer"))
}
