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
                        HStack {
                            Spacer()
                            TyreVisualizationView()
                                .frame(width: 200, height: 200)
                            Spacer()
                        }
                        .padding(.vertical, 20)

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

                        // Remaining life
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Remaining Life")
                                    .font(.customFont(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }

                            HStack {
                                Text("80%")
                                    .font(.customFont(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            ProgressView(value: 0.8)
                                .progressViewStyle(CustomProgressViewStyle(color: .cyan))
                                .frame(height: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)

                        // Tire Lifecycle Chart
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Tire Lifecycle")
                                    .font(.customFont(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            TireLifecycleChart()
                                .frame(height: 200)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)

                        // Compatible Tire Dimensions
                        if let tyre = tyre {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Compatible Tire Dimensions")
                                        .font(.customFont(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }

                                VStack(spacing: 12) {
                                    TireDimensionRow(
                                        label: "Standard:",
                                        dimension: tyre.size,
                                        isRecommended: true
                                    )

                                    TireDimensionRow(
                                        label: "Speed Rating:",
                                        dimension: tyre.speedRating,
                                        isRecommended: false
                                    )

                                    TireDimensionRow(
                                        label: "Load Index:",
                                        dimension: tyre.loadIndex,
                                        isRecommended: false
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                        }

                        // Tire Condition
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Tire Condition")
                                    .font(.customFont(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            HStack(spacing: 20) {
                                TireConditionIcon()

                                HStack(spacing: 25) {
                                    TireConditionBar(position: "FL", percentage: 70, color: .green)
                                    TireConditionBar(position: "FR", percentage: 80, color: .green)
                                    TireConditionBar(position: "RL", percentage: 50, color: .orange)
                                    TireConditionBar(position: "RR", percentage: 35, color: .red)
                                }

                                Spacer()
                            }
                        }
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
                        Image(systemName: "arrow.down.to.line")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
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
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Text(value)
                .font(.customFont(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tyre Visualization
struct TyreVisualizationView: View {
    var body: some View {
        ZStack {
            // Main tire circle
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 180, height: 180)

            // Inner rim
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 120, height: 120)

            // Rim spokes
            ForEach(0..<6) { spoke in
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 4, height: 40)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(spoke) * 60))
            }

            // Center hub
            Circle()
                .fill(Color.gray.opacity(0.9))
                .frame(width: 30, height: 30)
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
                    .font(.customFont(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(depth)
                .font(.customFont(size: 20, weight: .bold))
                .foregroundColor(.white)

            ProgressView(value: progress)
                .progressViewStyle(CustomProgressViewStyle(color: color))
                .frame(height: 6)
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
                    .frame(height: 6)
                    .cornerRadius(3)

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 6)
                    .cornerRadius(3)
            }
        }
    }
}

// MARK: - Tire Lifecycle Chart
struct TireLifecycleChart: View {
    let dataPoints: [ChartDataPoint] = [
        ChartDataPoint(distance: 5, depth: 10.0),
        ChartDataPoint(distance: 10, depth: 7.0),
        ChartDataPoint(distance: 15, depth: 4.5),
        ChartDataPoint(distance: 20, depth: 2.8),
        ChartDataPoint(distance: 25, depth: 1.0)
    ]

    var body: some View {
        Chart(dataPoints, id: \.distance) { point in
            LineMark(
                x: .value("Distance", point.distance),
                y: .value("Tread Depth", point.depth)
            )
            .foregroundStyle(.cyan)
            .lineStyle(StrokeStyle(lineWidth: 3))

            PointMark(
                x: .value("Distance", point.distance),
                y: .value("Tread Depth", point.depth)
            )
            .foregroundStyle(.cyan)
            .symbolSize(60)
        }
        .chartXScale(domain: 0...25)
        .chartYScale(domain: 0...12)
        .chartXAxis {
            AxisMarks(values: [5, 10, 15, 20, 25]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)K")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 2.5, 5.0, 7.5, 10]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .chartXAxisLabel("Distance (km)", alignment: .center)
        .chartYAxisLabel("Tread Depth (mm)", alignment: .center)
        .foregroundColor(.white)
        .background(Color.customBackgroundColor)
    }
}

struct ChartDataPoint {
    let distance: Int
    let depth: Double
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
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 50, height: 50)

            // Simplified tire icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 32, height: 32)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray)
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Tire Condition Bar
struct TireConditionBar: View {
    let position: String
    let percentage: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: CGFloat(percentage))
                .cornerRadius(4)
                .frame(height: 80, alignment: .bottom)

            Text("\(percentage)%")
                .font(.customFont(size: 12, weight: .bold))
                .foregroundColor(color)

            Text(position)
                .font(.customFont(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TyreDetailView()
}
