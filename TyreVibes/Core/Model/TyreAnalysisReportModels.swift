//
//  TyreAnalysisReportModels.swift
//  TyreVibes
//
//  Advanced tyre analysis report data models
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Main Report Model
struct TyreAnalysisReport: Codable, Identifiable {
    let id: UUID
    let metadata: ReportMetadata
    let depthAnalysis: DepthAnalysis
    let wearAnalysis: WearAnalysis
    let heatMap: DepthHeatMap
    let remainingLife: RemainingLifeEstimate
    let recommendations: [Recommendation]
    let safetyScore: SafetyScore
    let comparison: ComparisonData?

    var createdAt: Date {
        metadata.timestamp
    }

    init(
        id: UUID = UUID(),
        metadata: ReportMetadata,
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        heatMap: DepthHeatMap,
        remainingLife: RemainingLifeEstimate,
        recommendations: [Recommendation] = [],
        safetyScore: SafetyScore,
        comparison: ComparisonData? = nil
    ) {
        self.id = id
        self.metadata = metadata
        self.depthAnalysis = depthAnalysis
        self.wearAnalysis = wearAnalysis
        self.heatMap = heatMap
        self.remainingLife = remainingLife
        self.recommendations = recommendations
        self.safetyScore = safetyScore
        self.comparison = comparison
    }
}

// MARK: - Report Metadata
struct ReportMetadata: Codable {
    let reportId: String
    let timestamp: Date
    let vehicle: VehicleInfo
    let tyre: TyreInfo
    let location: LocationInfo?
    let weather: WeatherInfo?
    let analysisType: AnalysisType

    enum AnalysisType: String, Codable {
        case quick = "Quick Scan"
        case standard = "Standard Analysis"
        case comprehensive = "Comprehensive Analysis"
        case comparison = "Comparison Analysis"
    }
}

struct VehicleInfo: Codable {
    let make: String
    let model: String
    let year: Int?
    let plateNumber: String
    let vin: String?
}

struct TyreInfo: Codable {
    let brand: String
    let model: String
    let size: String
    let dot: String
    let position: TyrePosition
    let season: String
    let loadIndex: String
    let speedRating: String

    enum TyrePosition: String, Codable {
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"

        var shortCode: String {
            switch self {
            case .frontLeft: return "FL"
            case .frontRight: return "FR"
            case .rearLeft: return "RL"
            case .rearRight: return "RR"
            }
        }
    }
}

struct LocationInfo: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
}

struct WeatherInfo: Codable {
    let temperature: Double
    let humidity: Double
    let conditions: String
}

// MARK: - Depth Analysis
struct DepthAnalysis: Codable {
    let measurements: [DepthMeasurementPoint]
    let average: Double
    let minimum: Double
    let maximum: Double
    let standardDeviation: Double
    let legalStatus: LegalStatus
    let depthDistribution: DepthDistribution

    enum LegalStatus: String, Codable {
        case legal = "Legal"
        case nearLimit = "Near Legal Limit"
        case illegal = "Below Legal Limit"

        var color: Color {
            switch self {
            case .legal: return .green
            case .nearLimit: return .orange
            case .illegal: return .red
            }
        }

        var description: String {
            switch self {
            case .legal: return "Profondità battistrada legale (>1.6mm)"
            case .nearLimit: return "Vicino al limite legale (1.6-2.5mm)"
            case .illegal: return "Sotto il limite legale (<1.6mm)"
            }
        }
    }

    struct DepthDistribution: Codable {
        let excellent: Int  // > 6mm
        let good: Int       // 4-6mm
        let fair: Int       // 2.5-4mm
        let poor: Int       // 1.6-2.5mm
        let critical: Int   // < 1.6mm

        var total: Int {
            excellent + good + fair + poor + critical
        }
    }
}

struct DepthMeasurementPoint: Codable, Identifiable {
    let id: UUID
    let x: Double  // Normalized 0-1
    let y: Double  // Normalized 0-1
    let depth: Double  // mm
    let confidence: Double  // 0-1
    let zone: TyreZone

    enum TyreZone: String, Codable {
        case center = "Center"
        case innerEdge = "Inner Edge"
        case outerEdge = "Outer Edge"
        case shoulder = "Shoulder"
    }

    init(id: UUID = UUID(), x: Double, y: Double, depth: Double, confidence: Double, zone: TyreZone) {
        self.id = id
        self.x = x
        self.y = y
        self.depth = depth
        self.confidence = confidence
        self.zone = zone
    }
}

// MARK: - Wear Analysis
struct WearAnalysis: Codable {
    let pattern: WearPattern
    let severity: WearSeverity
    let causes: [WearCause]
    let zoneAnalysis: [ZoneWearInfo]
    let unevenWearIndex: Double  // 0-1, higher = more uneven

    enum WearPattern: String, Codable {
        case uniform = "Uniform"
        case centerWear = "Center Wear"
        case edgeWear = "Edge Wear"
        case innerEdgeWear = "Inner Edge Wear"
        case outerEdgeWear = "Outer Edge Wear"
        case patchyWear = "Patchy Wear"
        case cuppingWear = "Cupping Wear"
        case feathering = "Feathering"

        var icon: String {
            switch self {
            case .uniform: return "checkmark.circle.fill"
            case .centerWear: return "arrow.down.circle"
            case .edgeWear: return "arrow.left.and.right.circle"
            case .innerEdgeWear: return "arrow.left.circle"
            case .outerEdgeWear: return "arrow.right.circle"
            case .patchyWear: return "exclamationmark.triangle"
            case .cuppingWear: return "waveform"
            case .feathering: return "wind"
            }
        }

        var description: String {
            switch self {
            case .uniform: return "Usura uniforme su tutta la superficie"
            case .centerWear: return "Usura concentrata al centro del battistrada"
            case .edgeWear: return "Usura sui bordi del battistrada"
            case .innerEdgeWear: return "Usura sul bordo interno"
            case .outerEdgeWear: return "Usura sul bordo esterno"
            case .patchyWear: return "Usura irregolare a chiazze"
            case .cuppingWear: return "Usura a coppa (ondulata)"
            case .feathering: return "Usura a piuma (dentellatura)"
            }
        }
    }

    enum WearSeverity: String, Codable {
        case minimal = "Minimal"
        case moderate = "Moderate"
        case significant = "Significant"
        case severe = "Severe"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .minimal: return .green
            case .moderate: return .blue
            case .significant: return .yellow
            case .severe: return .orange
            case .critical: return .red
            }
        }

        var percentage: Double {
            switch self {
            case .minimal: return 0.2
            case .moderate: return 0.4
            case .significant: return 0.6
            case .severe: return 0.8
            case .critical: return 1.0
            }
        }
    }

    struct ZoneWearInfo: Codable {
        let zone: DepthMeasurementPoint.TyreZone
        let averageDepth: Double
        let wearPercentage: Double
        let status: String
    }
}

struct WearCause: Codable, Identifiable {
    let id: UUID
    let type: CauseType
    let probability: Double  // 0-1
    let description: String

    enum CauseType: String, Codable {
        case overInflation = "Sovra-gonfiaggio"
        case underInflation = "Sotto-gonfiaggio"
        case misalignment = "Disallineamento"
        case improperRotation = "Mancata rotazione"
        case suspension = "Problemi sospensioni"
        case drivingStyle = "Stile di guida aggressivo"
        case braking = "Frenate brusche"
        case loading = "Carico eccessivo"
    }

    init(id: UUID = UUID(), type: CauseType, probability: Double, description: String) {
        self.id = id
        self.type = type
        self.probability = probability
        self.description = description
    }
}

// MARK: - Heat Map
struct DepthHeatMap: Codable {
    let gridSize: GridSize
    let dataPoints: [[Double]]  // 2D array of depth values
    let colorScheme: HeatMapColorScheme
    let interpolated: Bool

    struct GridSize: Codable {
        let rows: Int
        let columns: Int
    }

    enum HeatMapColorScheme: String, Codable {
        case rainbow = "Rainbow"
        case thermal = "Thermal"
        case grayscale = "Grayscale"
        case custom = "Custom"

        var colors: [Color] {
            switch self {
            case .rainbow:
                return [.red, .orange, .yellow, .green, .blue, .purple]
            case .thermal:
                return [.blue, .cyan, .green, .yellow, .orange, .red]
            case .grayscale:
                return [.black, .gray, .white]
            case .custom:
                return [Color(hex: "FF0000"), Color(hex: "FFFF00"), Color(hex: "00FF00")]
            }
        }
    }

    func colorForDepth(_ depth: Double, minDepth: Double = 0, maxDepth: Double = 8) -> Color {
        let normalized = (depth - minDepth) / (maxDepth - minDepth)
        let clampedValue = min(max(normalized, 0), 1)

        let colors = colorScheme.colors
        let index = Int(clampedValue * Double(colors.count - 1))
        return colors[min(index, colors.count - 1)]
    }
}

// MARK: - Remaining Life Estimate
struct RemainingLifeEstimate: Codable {
    let estimatedKilometers: Double
    let estimatedMonths: Int
    let confidence: Double  // 0-1
    let calculationMethod: CalculationMethod
    let factors: [LifeFactor]
    let projectedDepthCurve: [DepthProjection]

    enum CalculationMethod: String, Codable {
        case linear = "Linear Regression"
        case exponential = "Exponential Model"
        case machineLearning = "ML Prediction"
        case historical = "Historical Data"
    }

    var formattedDistance: String {
        if estimatedKilometers > 1000 {
            return String(format: "%.1f,000 km", estimatedKilometers / 1000)
        } else {
            return String(format: "%.0f km", estimatedKilometers)
        }
    }

    var status: LifeStatus {
        if estimatedKilometers > 20000 {
            return .excellent
        } else if estimatedKilometers > 10000 {
            return .good
        } else if estimatedKilometers > 5000 {
            return .fair
        } else if estimatedKilometers > 2000 {
            return .warning
        } else {
            return .critical
        }
    }

    enum LifeStatus {
        case excellent, good, fair, warning, critical

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
}

struct LifeFactor: Codable, Identifiable {
    let id: UUID
    let name: String
    let impact: Double  // -1 to 1, negative reduces life
    let description: String

    init(id: UUID = UUID(), name: String, impact: Double, description: String) {
        self.id = id
        self.name = name
        self.impact = impact
        self.description = description
    }
}

struct DepthProjection: Codable, Identifiable {
    let id: UUID
    let kilometersFromNow: Double
    let projectedDepth: Double
    let confidence: Double

    init(id: UUID = UUID(), kilometersFromNow: Double, projectedDepth: Double, confidence: Double) {
        self.id = id
        self.kilometersFromNow = kilometersFromNow
        self.projectedDepth = projectedDepth
        self.confidence = confidence
    }
}

// MARK: - Recommendations
struct Recommendation: Codable, Identifiable {
    let id: UUID
    let priority: Priority
    let category: Category
    let title: String
    let description: String
    let action: String
    let urgency: Urgency

    enum Priority: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "info.circle.fill"
            case .low: return "checkmark.circle.fill"
            }
        }
    }

    enum Category: String, Codable {
        case safety = "Safety"
        case maintenance = "Maintenance"
        case performance = "Performance"
        case cost = "Cost Optimization"
        case legal = "Legal Compliance"
    }

    enum Urgency: String, Codable {
        case immediate = "Immediate"
        case withinWeek = "Within a Week"
        case withinMonth = "Within a Month"
        case routine = "Routine Check"
    }

    init(id: UUID = UUID(), priority: Priority, category: Category, title: String, description: String, action: String, urgency: Urgency) {
        self.id = id
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.action = action
        self.urgency = urgency
    }
}

// MARK: - Safety Score
struct SafetyScore: Codable {
    let overall: Double  // 0-100
    let components: ScoreComponents
    let rating: Rating

    struct ScoreComponents: Codable {
        let depthScore: Double
        let wearPatternScore: Double
        let uniformityScore: Double
        let legalComplianceScore: Double
        let conditionScore: Double
    }

    enum Rating: String, Codable {
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
            case .excellent: return "Pneumatico in condizioni eccellenti"
            case .good: return "Pneumatico in buone condizioni"
            case .fair: return "Pneumatico in condizioni accettabili"
            case .poor: return "Pneumatico da monitorare attentamente"
            case .critical: return "Sostituzione urgente necessaria"
            }
        }
    }

    static func fromScore(_ score: Double) -> Rating {
        switch score {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        default: return .critical
        }
    }
}

// MARK: - Comparison Data
struct ComparisonData: Codable {
    let previousReport: String?  // Report ID
    let changes: [ChangeMetric]
    let trend: Trend

    struct ChangeMetric: Codable {
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

    enum Trend: String, Codable {
        case improving = "Improving"
        case stable = "Stable"
        case declining = "Declining"
        case critical = "Critical Decline"
    }
}

// MARK: - Export Format
enum ReportExportFormat {
    case pdf
    case image(format: ImageFormat)
    case json
    case html

    enum ImageFormat {
        case png
        case jpeg(quality: Double)
    }

    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .image(let format):
            switch format {
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        case .json: return "json"
        case .html: return "html"
        }
    }
}
