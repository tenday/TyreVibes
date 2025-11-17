//
//  TreadDepthMeasurement.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import Foundation
import ARKit
import simd

// MARK: - Tread Depth Measurement Result

/// Risultato di una misurazione della profondità del battistrada
struct TreadDepthMeasurement: Codable, Identifiable {
    let id: UUID
    let tyreId: UUID?
    let timestamp: Date

    /// Profondità media del battistrada in millimetri
    let averageDepth: Double

    /// Profondità minima rilevata in millimetri
    let minDepth: Double

    /// Profondità massima rilevata in millimetri
    let maxDepth: Double

    /// Deviazione standard delle misurazioni
    let standardDeviation: Double

    /// Confidence score (0-100) basato sulla qualità dei dati
    let confidenceScore: Double

    /// Numero di punti campionati
    let samplePoints: Int

    /// Mappa di profondità per diverse zone del battistrada
    let depthMap: [TreadZone: Double]

    /// Stato del battistrada basato sulla misurazione
    let treadStatus: TreadStatus

    /// Metadati della misurazione
    let metadata: MeasurementMetadata

    init(id: UUID = UUID(),
         tyreId: UUID? = nil,
         timestamp: Date = Date(),
         averageDepth: Double,
         minDepth: Double,
         maxDepth: Double,
         standardDeviation: Double,
         confidenceScore: Double,
         samplePoints: Int,
         depthMap: [TreadZone: Double],
         treadStatus: TreadStatus,
         metadata: MeasurementMetadata) {
        self.id = id
        self.tyreId = tyreId
        self.timestamp = timestamp
        self.averageDepth = averageDepth
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.standardDeviation = standardDeviation
        self.confidenceScore = confidenceScore
        self.samplePoints = samplePoints
        self.depthMap = depthMap
        self.treadStatus = treadStatus
        self.metadata = metadata
    }
}

// MARK: - Tread Zone

/// Zone del battistrada per mappatura dettagliata
enum TreadZone: String, Codable, CaseIterable {
    case centerLeft = "center_left"
    case centerRight = "center_right"
    case shoulderLeft = "shoulder_left"
    case shoulderRight = "shoulder_right"
    case innerEdge = "inner_edge"
    case outerEdge = "outer_edge"

    var displayName: String {
        switch self {
        case .centerLeft: return "Centro Sinistro"
        case .centerRight: return "Centro Destro"
        case .shoulderLeft: return "Spalla Sinistra"
        case .shoulderRight: return "Spalla Destra"
        case .innerEdge: return "Bordo Interno"
        case .outerEdge: return "Bordo Esterno"
        }
    }
}

// MARK: - Tread Status

/// Stato del battistrada basato sulla profondità misurata
enum TreadStatus: String, Codable {
    case excellent = "excellent"      // > 6mm
    case good = "good"                // 4-6mm
    case fair = "fair"                // 2-4mm
    case poor = "poor"                // 1.6-2mm (limite legale in Italia: 1.6mm)
    case critical = "critical"        // < 1.6mm
    case uneven = "uneven"            // Usura irregolare

    var displayName: String {
        switch self {
        case .excellent: return "Eccellente"
        case .good: return "Buono"
        case .fair: return "Discreto"
        case .poor: return "Insufficiente"
        case .critical: return "Critico"
        case .uneven: return "Usura Irregolare"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical, .uneven: return "red"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .uneven: return "chart.bar.fill"
        }
    }

    /// Determina lo stato basato sulla profondità media e deviazione standard
    static func from(averageDepth: Double, standardDeviation: Double) -> TreadStatus {
        // Usura irregolare se la deviazione standard è alta (> 1.5mm)
        if standardDeviation > 1.5 {
            return .uneven
        }

        switch averageDepth {
        case 6...:
            return .excellent
        case 4..<6:
            return .good
        case 2..<4:
            return .fair
        case 1.6..<2:
            return .poor
        case ..<1.6:
            return .critical
        default:
            return .critical
        }
    }
}

// MARK: - Measurement Metadata

/// Metadati sulla misurazione
struct MeasurementMetadata: Codable {
    /// Tipo di dispositivo utilizzato
    let deviceModel: String

    /// Versione iOS
    let osVersion: String

    /// Supporto LiDAR disponibile
    let hasLiDAR: Bool

    /// Condizioni di illuminazione (lux stimati)
    let lightingConditions: LightingCondition

    /// Distanza media dal pneumatico in centimetri
    let averageDistance: Double

    /// Durata della scansione in secondi
    let scanDuration: TimeInterval

    /// Qualità della mesh 3D generata
    let meshQuality: MeshQuality

    init(deviceModel: String,
         osVersion: String,
         hasLiDAR: Bool,
         lightingConditions: LightingCondition,
         averageDistance: Double,
         scanDuration: TimeInterval,
         meshQuality: MeshQuality) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.hasLiDAR = hasLiDAR
        self.lightingConditions = lightingConditions
        self.averageDistance = averageDistance
        self.scanDuration = scanDuration
        self.meshQuality = meshQuality
    }
}

// MARK: - Lighting Condition

enum LightingCondition: String, Codable {
    case excellent = "excellent"    // > 1000 lux
    case good = "good"              // 500-1000 lux
    case fair = "fair"              // 200-500 lux
    case poor = "poor"              // < 200 lux

    var displayName: String {
        switch self {
        case .excellent: return "Ottima"
        case .good: return "Buona"
        case .fair: return "Discreta"
        case .poor: return "Scarsa"
        }
    }
}

// MARK: - Mesh Quality

enum MeshQuality: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Bassa"
        }
    }
}

// MARK: - LiDAR Point Cloud Data

/// Punto della nuvola di punti LiDAR
struct LiDARPoint {
    let position: simd_float3    // Posizione 3D in metri
    let confidence: Float        // Confidenza della misurazione (0-1)
    let timestamp: TimeInterval

    /// Distanza dall'origine
    var distance: Float {
        return simd_length(position)
    }
}

// MARK: - Measurement Session

/// Sessione di misurazione attiva
class MeasurementSession {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var rawPoints: [LiDARPoint] = []
    var filteredPoints: [LiDARPoint] = []
    var isProcessing: Bool = false

    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    func addPoint(_ point: LiDARPoint) {
        rawPoints.append(point)
    }

    func finalize() {
        endTime = Date()
    }
}

// MARK: - Calibration Data

/// Dati di calibrazione per la misurazione
struct CalibrationData: Codable {
    /// Offset di calibrazione in millimetri
    let offset: Double

    /// Fattore di scala
    let scaleFactor: Double

    /// Data ultima calibrazione
    let lastCalibration: Date

    /// Validità della calibrazione
    var isValid: Bool {
        let daysSinceCalibration = Date().timeIntervalSince(lastCalibration) / 86400
        return daysSinceCalibration < 30 // Valida per 30 giorni
    }

    static var `default`: CalibrationData {
        CalibrationData(
            offset: 0.0,
            scaleFactor: 1.0,
            lastCalibration: Date()
        )
    }
}
