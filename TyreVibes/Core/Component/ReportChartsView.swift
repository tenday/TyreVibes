//
//  ReportChartsView.swift
//  TyreVibes
//
//  Advanced charts for tyre analysis reports
//

import SwiftUI
import Charts

// MARK: - Supporting Types
struct DepthProjection: Identifiable {
    let id = UUID()
    let kilometersFromNow: Double
    let projectedDepth: Double
    let confidence: Double
}

struct DepthAnalysis: Codable {
    let average: Double
    let minimum: Double
    let maximum: Double
    let standardDeviation: Double
    let measurements: [DepthMeasurementPoint]
    let legalStatus: LegalStatus
    let depthDistribution: DepthDistribution

    struct DepthDistribution: Codable {
        let excellent: Int
        let good: Int
        let fair: Int
        let poor: Int
        let critical: Int
    }

    enum LegalStatus: String, Codable {
        case legal = "Legal"
        case nearLimit = "Near Limit"
        case warning = "Warning"
        case illegal = "Illegal"
    }
}

struct SafetyScore: Codable {
    let overall: Double
    let rating: Rating
    let components: ScoreComponents

    struct ScoreComponents: Codable {
        let depthScore: Double
        let wearPatternScore: Double
        let uniformityScore: Double
        let legalComplianceScore: Double
        let conditionScore: Double
    }

    enum Rating: String, CaseIterable, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .poor: return .orange
            case .critical: return .red
            }
        }

        var description: String {
            switch self {
            case .excellent: return "Optimal condition for safety and performance"
            case .good: return "Good condition, monitor regularly"
            case .fair: return "Average condition, consider replacement"
            case .poor: return "Worn, replacement recommended soon"
            case .critical: return "Dangerous, replace immediately"
            }
        }

        static func fromScore(_ score: Double) -> Rating {
            switch score {
            case 90...100:
                return .excellent
            case 75..<90:
                return .good
            case 60..<75:
                return .fair
            case 40..<60:
                return .poor
            default:
                return .critical
            }
        }
    }
}

struct WearAnalysis: Codable {
    let pattern: WearPattern
    let severity: WearSeverity
    let unevenWearIndex: Double
    let zoneAnalysis: [ZoneWearInfo]
    let causes: [WearCause]

    enum Zone: String, CaseIterable, Codable {
        case inner = "Inner"
        case center = "Center"
        case outer = "Outer"
    }

    struct ZoneWearInfo: Codable {
        let zone: Zone
        let averageDepth: Double
        let wearPercentage: Double
    }

    enum WearPattern: String, Codable {
        case uniform = "Uniforme"
        case centerWear = "Usura centrale"
        case edgeWear = "Usura laterale"
        case innerEdgeWear = "Usura bordo interno"
        case outerEdgeWear = "Usura bordo esterno"
        case patchyWear = "Usura irregolare"
        case cuppingWear = "Usura a coppa"
        case feathering = "Usura a piuma"
        case excessive = "Usura eccessiva"

        var description: String {
            return self.rawValue
        }
    }

    enum WearSeverity: String, Codable {
        case minimal = "Minima"
        case moderate = "Moderata"
        case significant = "Significativa"
        case severe = "Severa"
        case critical = "Critica"
    }
}

struct ComparisonData: Codable {
    struct Change: Codable {
        let parameter: String
        let previousValue: Double
        let currentValue: Double
        let percentageChange: Double
        let direction: ChangeDirection
    }

    enum ChangeDirection: String, Codable {
        case improved = "Improved"
        case worsened = "Worsened"
        case stable = "Stable"
        
        var color: Color {
            switch self {
            case .improved: return .green
            case .worsened: return .red
            case .stable: return .gray
            }
        }
    }
    
    let changes: [Change]
}

struct LifeFactor: Codable, Identifiable {
    var id = UUID()
    let name: String
    let impact: Double
    let description: String
}

// MARK: - Enhanced Depth Projection Chart
struct DepthProjectionChart: View {
    let projections: [DepthProjection]
    let legalMinimum: Double = 1.6
    @State private var selectedProjection: DepthProjection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projected Depth Over Distance")
                    .font(.customFont(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let selected = selectedProjection {
                    Text("Selected: \(String(format: "%.1f", selected.projectedDepth))mm")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Chart(projections) { projection in
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
                .symbolSize(50)

                // Confidence area
                AreaMark(
                    x: .value("Distance (km)", projection.kilometersFromNow / 1000),
                    yStart: .value("Lower", projection.projectedDepth * (1 - (1 - projection.confidence) * 0.2)),
                    yEnd: .value("Upper", projection.projectedDepth * (1 + (1 - projection.confidence) * 0.2))
                )
                .foregroundStyle(.blue.opacity(0.2))
            }
            .frame(height: 250)
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
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Legal minimum line
            HStack {
                Text("Legal Minimum: \(legalMinimum)mm")
                    .font(.customFont(size: 13, weight: .medium))
                    .foregroundColor(.red)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 30, height: 2)
                    .overlay(
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 30, height: 2)
                            .rotationEffect(.degrees(90))
                    )
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Enhanced Depth Distribution Chart
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
                
                if item.1 > 0 {
                    RuleMark(y: .value("Count", Double(item.1) * 0.5))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .annotation {
                            Text(String(format: "%.0f%%", Double(item.1) / Double(totalCount) * 100))
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                        }
                }
            }
            .frame(height: 220)
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
            
            // Summary statistics
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Tyres")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(totalCount)")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Critical Tyres")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(distribution.critical)")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
    
    private var totalCount: Int {
        distribution.excellent + distribution.good + distribution.fair + distribution.poor + distribution.critical
    }
}

// MARK: - Enhanced Safety Score Gauge
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
            
            // Safety recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.customFont(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(safetyScore.rating.description)
                    .font(.customFont(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                
                if safetyScore.overall < 70 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        
                        Text("Immediate attention required")
                            .font(.customFont(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 4)
                }
            }
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

// MARK: - Enhanced Zone Wear Comparison
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
            .frame(height: 200)
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
            
            // Additional insights
            HStack(spacing: 16) {
                ForEach(zoneAnalysis, id: \.zone.rawValue) { zone in
                    VStack(alignment: .center, spacing: 6) {
                        Text(zone.zone.rawValue)
                            .font(.customFont(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(String(format: "%.1f", zone.averageDepth))
                            .font(.customFont(size: 16, weight: .bold))
                            .foregroundColor(colorForDepth(zone.averageDepth))
                        
                        Text(String(format: "%.0f%%", zone.wearPercentage * 100))
                            .font(.customFont(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
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

// MARK: - Enhanced Score Components Breakdown
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.0)
                                .font(.customFont(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text(String(format: "%.0f%%", item.1 * 100))
                                .font(.customFont(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
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

// MARK: - Enhanced Comparison Chart (Multiple Reports)
struct ComparisonChart: View {
    let comparisonData: ComparisonData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison with Previous Report")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(comparisonData.changes, id: \.parameter) { change in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(change.parameter)
                                    .font(.customFont(size: 13, weight: .medium))
                                    .foregroundColor(.white)

                                HStack(spacing: 8) {
                                    Text("Prev: \(String(format: "%.2f", change.previousValue))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))

                                    Text("Now: \(String(format: "%.2f", change.currentValue))")
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
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
            .frame(height: 200)
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

// MARK: - Enhanced Life Factors Chart
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
            .frame(height: CGFloat(min(factors.count, 8) * 40))
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
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Top factors summary
            if factors.count > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Impact Factors")
                        .font(.customFont(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(factors.sorted { abs($0.impact) > abs($1.impact) }.prefix(3), id: \.name) { factor in
                        HStack {
                            Text(factor.name)
                                .font(.customFont(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(factor.impact > 0 ? "+" : "")
                                    .font(.customFont(size: 12, weight: .medium))
                                    .foregroundColor(factor.impact > 0 ? .green : .red)
                                
                                Text(String(format: "%.2f", factor.impact))
                                    .font(.customFont(size: 12, weight: .bold))
                                    .foregroundColor(factor.impact > 0 ? .green : .red)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Temperature Distribution Chart
struct TemperatureDistributionChart: View {
    let temperatures: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperature Distribution")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(temperatures.indices.map { index in (index, temperatures[index]) }, id: \.0) { item in
                BarMark(
                    x: .value("Index", item.0),
                    y: .value("Temperature (°C)", item.1)
                )
                .foregroundStyle(temperatureGradient(for: item.1).gradient)
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartXAxis(.hidden)
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
    
    private func temperatureGradient(for temp: Double) -> Color {
        switch temp {
        case 0..<40: return .blue
        case 40..<70: return .green
        case 70..<90: return .yellow
        case 90..<120: return .orange
        default: return .red
        }
    }
}

// MARK: - Pressure Trend Chart
struct PressureTrendChart: View {
    let pressureData: [PressureDataPoint]

    struct PressureDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let pressure: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pressure Trend")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(pressureData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Pressure (psi)", point.pressure)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Pressure (psi)", point.pressure)
                )
                .foregroundStyle(.white)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.narrow).year().month().day())
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

// MARK: - 3D Visualization Placeholder
struct ThreeDVisualization: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Tyre Visualization")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                
                VStack(spacing: 16) {
                    Text("3D View")
                        .font(.customFont(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Interactive 3D visualization of tyre condition and wear patterns")
                        .font(.customFont(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    HStack {
                        Button(action: {}) {
                            Text("Rotate")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {}) {
                            Text("Zoom In")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {}) {
                            Text("Zoom Out")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .frame(height: 250)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Export Functionality
struct ExportOptionsView: View {
    @State private var isExporting = false
    @State private var exportFormat: ExportFormat = .pdf
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case json = "JSON"
        case image = "Image"
    }
    
    var onExport: (ExportFormat) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Export Report")
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            
            Button(action: {
                isExporting = true
                onExport(exportFormat)
            }) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                    Text("Export \(exportFormat.rawValue)")
                        .font(.customFont(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isExporting)
            .padding(.horizontal, 20)
            
            Button("Cancel") {
                // Close the export options
            }
            .font(.customFont(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }
}

// MARK: - Historical Comparison Chart
struct HistoricalComparisonChart: View {
    let history: [HistoricalReport]
    
    struct HistoricalReport: Identifiable {
        let id = UUID()
        let date: Date
        let safetyScore: Double
        let averageDepth: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historical Performance")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Chart(history) { report in
                LineMark(
                    x: .value("Date", report.date),
                    y: .value("Safety Score", report.safetyScore)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("Date", report.date),
                    y: .value("Safety Score", report.safetyScore)
                )
                .foregroundStyle(.white)
                .symbolSize(60)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.narrow).month().day())
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
            
            // Summary statistics
            HStack {
                VStack(alignment: .center) {
                    Text("Best Score")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(String(format: "%.0f", history.map { $0.safetyScore }.max() ?? 0))
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Worst Score")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(String(format: "%.0f", history.map { $0.safetyScore }.min() ?? 0))
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Avg. Score")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(String(format: "%.0f", history.map { $0.safetyScore }.reduce(0, +) / Double(history.count)))
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Comprehensive Report View
struct ReportChartsView: View {
    let depthProjections: [DepthProjection]
    let depthDistribution: DepthAnalysis.DepthDistribution
    let safetyScore: SafetyScore
    let zoneAnalysis: [WearAnalysis.ZoneWearInfo]
    let scoreComponents: SafetyScore.ScoreComponents
    let comparisonData: ComparisonData
    let lifeFactors: [LifeFactor]
    let temperatureData: [Double]
    let pressureData: [PressureTrendChart.PressureDataPoint]
    let historicalData: [HistoricalComparisonChart.HistoricalReport]
    
    @State private var showingExportOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main safety score
                SafetyScoreGauge(safetyScore: safetyScore)
                
                // Depth projection chart
                DepthProjectionChart(projections: depthProjections)
                
                // Distribution and zone analysis
                HStack(spacing: 16) {
                    DepthDistributionChart(distribution: depthDistribution)
                        .frame(maxWidth: .infinity)
                    
                    ZoneWearComparisonChart(zoneAnalysis: zoneAnalysis)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                // Score components and life factors
                HStack(spacing: 16) {
                    ScoreComponentsChart(components: scoreComponents)
                        .frame(maxWidth: .infinity)
                    
                    LifeFactorsChart(factors: lifeFactors)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                // Comparison chart
                ComparisonChart(comparisonData: comparisonData)
                
                // Temperature and pressure charts
                HStack(spacing: 16) {
                    TemperatureDistributionChart(temperatures: temperatureData)
                        .frame(maxWidth: .infinity)
                    
                    PressureTrendChart(pressureData: pressureData)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                // Historical comparison
                HistoricalComparisonChart(history: historicalData)
                
                // 3D visualization
                ThreeDVisualization()
                    .padding(.vertical, 12)
            }
        }
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                showingExportOptions = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Report")
                }
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(20)
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView { format in
                    print("Exporting report as \(format.rawValue)")
                    showingExportOptions = false
                    // Here you would implement the actual export functionality
                }
            }
        }
    }
}
