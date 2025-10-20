//
//  ReportChartsView.swift
//  TyreVibes
//
//  Advanced charts for tyre analysis reports
//

import SwiftUI
import Charts

// MARK: - Depth Projection Chart
struct DepthProjectionChart: View {
    let projections: [DepthProjection]
    let legalMinimum: Double = 1.6

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected Depth Over Distance")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart {
                // Legal minimum line
                RuleMark(y: .value("Legal Minimum", legalMinimum))
                    .foregroundStyle(.red.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Legal Min")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }

                // Projection line
                ForEach(projections) { projection in
                    LineMark(
                        x: .value("Distance (km)", projection.kilometersFromNow / 1000),
                        y: .value("Depth (mm)", projection.projectedDepth)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    // Confidence area
                    AreaMark(
                        x: .value("Distance (km)", projection.kilometersFromNow / 1000),
                        yStart: .value("Lower", projection.projectedDepth * (1 - (1 - projection.confidence) * 0.2)),
                        yEnd: .value("Upper", projection.projectedDepth * (1 + (1 - projection.confidence) * 0.2))
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Depth Distribution Chart
struct DepthDistributionChart: View {
    let distribution: DepthAnalysis.DepthDistribution

    private var chartData: [(String, Int, Color)] {
        [
            ("Excellent\n>6mm", distribution.excellent, .green),
            ("Good\n4-6mm", distribution.good, .blue),
            ("Fair\n2.5-4mm", distribution.fair, .yellow),
            ("Poor\n1.6-2.5mm", distribution.poor, .orange),
            ("Critical\n<1.6mm", distribution.critical, .red)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Depth Distribution")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(chartData, id: \.0) { item in
                BarMark(
                    x: .value("Category", item.0),
                    y: .value("Count", item.1)
                )
                .foregroundStyle(item.2.gradient)
                .cornerRadius(8)
                .annotation(position: .top) {
                    if item.1 > 0 {
                        Text("\(item.1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Safety Score Gauge
struct SafetyScoreGauge: View {
    let safetyScore: SafetyScore
    @State private var animatedScore: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Safety Score")
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress circle
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        LinearGradient(
                            colors: gradientColors(for: safetyScore.overall),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", animatedScore))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text(safetyScore.rating.rawValue)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(safetyScore.rating.color)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animatedScore = safetyScore.overall
                }
            }

            Text(safetyScore.rating.description)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
        .padding(.horizontal, 20)
    }

    private func gradientColors(for score: Double) -> [Color] {
        switch score {
        case 90...100: return [.green, .mint]
        case 75..<90: return [.blue, .cyan]
        case 60..<75: return [.yellow, .orange]
        case 40..<60: return [.orange, .red]
        default: return [.red, .pink]
        }
    }
}

// MARK: - Zone Wear Comparison
struct ZoneWearComparisonChart: View {
    let zoneAnalysis: [WearAnalysis.ZoneWearInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wear by Zone")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(zoneAnalysis, id: \.zone.rawValue) { zone in
                BarMark(
                    x: .value("Zone", zone.zone.rawValue),
                    y: .value("Depth", zone.averageDepth)
                )
                .foregroundStyle(colorForDepth(zone.averageDepth).gradient)
                .cornerRadius(8)
                .annotation(position: .top) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f mm", zone.averageDepth))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%.0f%%", zone.wearPercentage * 100))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel()
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }

    private func colorForDepth(_ depth: Double) -> Color {
        switch depth {
        case 6...: return .green
        case 4..<6: return .blue
        case 2.5..<4: return .yellow
        case 1.6..<2.5: return .orange
        default: return .red
        }
    }
}

// MARK: - Score Components Breakdown
struct ScoreComponentsChart: View {
    let components: SafetyScore.ScoreComponents

    private var chartData: [(String, Double, Color)] {
        [
            ("Depth", components.depthScore, .green),
            ("Wear Pattern", components.wearPatternScore, .blue),
            ("Uniformity", components.uniformityScore, .purple),
            ("Legal", components.legalComplianceScore, .orange),
            ("Condition", components.conditionScore, .cyan)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                ForEach(chartData, id: \.0) { item in
                    HStack(spacing: 12) {
                        Text(item.0)
                            .font(.customFont(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 24)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(item.2.gradient)
                                    .frame(width: geometry.size.width * item.1, height: 24)
                            }
                        }
                        .frame(height: 24)

                        Text(String(format: "%.0f%%", item.1 * 100))
                            .font(.customFont(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Comparison Chart (Multiple Reports)
struct ComparisonChart: View {
    let comparisonData: ComparisonData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison with Previous Report")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                ForEach(comparisonData.changes, id: \.parameter) { change in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.parameter)
                                .font(.customFont(size: 13, weight: .medium))
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Text(String(format: "%.2f", change.previousValue))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))

                                Text(String(format: "%.2f", change.currentValue))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: arrowIcon(for: change.direction))
                                .font(.system(size: 14))
                                .foregroundColor(change.direction.color)

                            Text(String(format: "%.1f%%", abs(change.percentageChange)))
                                .font(.customFont(size: 13, weight: .bold))
                                .foregroundColor(change.direction.color)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }

    private func arrowIcon(for direction: ComparisonData.ChangeDirection) -> String {
        switch direction {
        case .improved: return "arrow.up.circle.fill"
        case .worsened: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
}

// MARK: - Life Factors Chart
struct LifeFactorsChart: View {
    let factors: [LifeFactor]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life Impact Factors")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(factors.sorted { abs($0.impact) > abs($1.impact) }) { factor in
                BarMark(
                    x: .value("Impact", factor.impact),
                    y: .value("Factor", factor.name)
                )
                .foregroundStyle(factor.impact > 0 ? Color.green.gradient : Color.red.gradient)
                .cornerRadius(6)
            }
            .frame(height: CGFloat(factors.count * 40))
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }
}
