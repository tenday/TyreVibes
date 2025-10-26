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

    // Custom Codable to avoid requiring non-Codable element types for factors and projectedDepthCurve
    private enum CodingKeys: String, CodingKey {
        case estimatedKilometers
        case estimatedMonths
        case confidence
        case calculationMethod
        // Intentionally omit: factors, projectedDepthCurve
    }

    init(estimatedKilometers: Double,
         estimatedMonths: Int,
         confidence: Double,
         calculationMethod: CalculationMethod,
         factors: [LifeFactor],
         projectedDepthCurve: [DepthProjection]) {
        self.estimatedKilometers = estimatedKilometers
        self.estimatedMonths = estimatedMonths
        self.confidence = confidence
        self.calculationMethod = calculationMethod
        self.factors = factors
        self.projectedDepthCurve = projectedDepthCurve
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.estimatedKilometers = try container.decode(Double.self, forKey: .estimatedKilometers)
        self.estimatedMonths = try container.decode(Int.self, forKey: .estimatedMonths)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.calculationMethod = try container.decode(CalculationMethod.self, forKey: .calculationMethod)
        // Default to empty arrays when decoding since we intentionally do not decode these fields
        self.factors = []
        self.projectedDepthCurve = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(estimatedKilometers, forKey: .estimatedKilometers)
        try container.encode(estimatedMonths, forKey: .estimatedMonths)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(calculationMethod, forKey: .calculationMethod)
        // Intentionally do not encode factors or projectedDepthCurve to avoid requiring their element types to conform to Codable
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

