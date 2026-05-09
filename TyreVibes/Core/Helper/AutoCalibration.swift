//
//  AutoCalibration.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//  Automatic calibration system using AR markers
//

import Foundation
import ARKit
import RealityKit
import simd

// MARK: - Auto Calibration System

/// Sistema di auto-calibrazione usando marker AR
class AutoCalibrationSystem {
    // MARK: - Calibration Target

    /// Target di calibrazione (es. oggetto di spessore noto)
    struct CalibrationTarget {
        let knownDepth: Double  // Profondità nota in mm
        let tolerance: Double   // Tolleranza accettabile in mm
        let markerID: String    // ID del marker AR (opzionale)

        static var standard: CalibrationTarget {
            return CalibrationTarget(
                knownDepth: 5.0,      // Blocchetto 5mm
                tolerance: 0.1,        // ±0.1mm
                markerID: "CALIB_BLOCK_5MM"
            )
        }
    }

    // MARK: - Calibration Result

    struct CalibrationResult {
        let offset: Double              // Offset in mm
        let scaleFactor: Double         // Fattore di scala
        let rmse: Double                // Root Mean Square Error
        let measurements: [Double]      // Misurazioni grezze
        let correctedMeasurements: [Double]  // Misurazioni corrette
        let timestamp: Date
        let isValid: Bool

        var accuracy: Double {
            return 1.0 - (rmse / 10.0)  // Normalizzato 0-1
        }

        var qualityGrade: QualityGrade {
            switch rmse {
            case ..<0.05:
                return .excellent
            case 0.05..<0.1:
                return .good
            case 0.1..<0.2:
                return .fair
            default:
                return .poor
            }
        }
    }

    enum QualityGrade: String {
        case excellent = "Eccellente"
        case good = "Buona"
        case fair = "Discreta"
        case poor = "Scarsa"
    }

    // MARK: - Properties

    private let target: CalibrationTarget
    private var measurements: [Double] = []
    private var isCalibrating: Bool = false

    // MARK: - Initialization

    init(target: CalibrationTarget = .standard) {
        self.target = target
    }

    // MARK: - Public Methods

    /// Avvia procedura di calibrazione
    func startCalibration() {
        measurements.removeAll()
        isCalibrating = true

        print("🎯 [Calibration] Inizio calibrazione - Target: \(target.knownDepth)mm")
    }

    /// Aggiungi misurazione al processo di calibrazione
    /// - Parameter measurement: Misurazione grezza in mm
    func addMeasurement(_ measurement: Double) {
        guard isCalibrating else { return }

        measurements.append(measurement)

        print("📊 [Calibration] Misurazione #\(measurements.count): \(String(format: "%.3f", measurement))mm")
    }

    /// Completa calibrazione e calcola parametri
    /// - Returns: Risultato calibrazione
    func completeCalibration() -> CalibrationResult? {
        guard isCalibrating && measurements.count >= 10 else {
            print("⚠️ [Calibration] Insufficienti misurazioni: \(measurements.count)/10")
            return nil
        }

        isCalibrating = false

        print("⚙️ [Calibration] Elaborazione \(measurements.count) misurazioni...")

        // Rimuovi outliers
        let cleaned = removeOutliersIQR(measurements, multiplier: 1.5)

        guard cleaned.count >= 5 else {
            print("⚠️ [Calibration] Troppi outliers rimossi")
            return nil
        }

        // Calcola media misurata
        let measuredMean = cleaned.mean

        // Calcola offset (differenza tra noto e misurato)
        let offset = target.knownDepth - measuredMean

        // Calcola fattore di scala
        let scaleFactor = target.knownDepth / measuredMean

        // Applica correzione
        let corrected = measurements.map { ($0 + offset) * scaleFactor }

        // Calcola RMSE rispetto al target
        let errors = corrected.map { $0 - target.knownDepth }
        let squaredErrors = errors.map { $0 * $0 }
        let rmse = sqrt(squaredErrors.reduce(0, +) / Double(squaredErrors.count))

        // Valida risultato
        let isValid = rmse < target.tolerance

        let result = CalibrationResult(
            offset: offset,
            scaleFactor: scaleFactor,
            rmse: rmse,
            measurements: measurements,
            correctedMeasurements: corrected,
            timestamp: Date(),
            isValid: isValid
        )

        print("✅ [Calibration] Completata - Offset: \(String(format: "%.3f", offset))mm, Scale: \(String(format: "%.4f", scaleFactor)), RMSE: \(String(format: "%.3f", rmse))mm")

        return result
    }

    /// Annulla calibrazione
    func cancelCalibration() {
        isCalibrating = false
        measurements.removeAll()

        print("❌ [Calibration] Calibrazione annullata")
    }

    // MARK: - AR Marker Detection

    /// Rileva marker AR nel frame
    /// - Parameter frame: ARFrame corrente
    /// - Returns: Marker rilevati con posizione
    func detectMarkers(in frame: ARFrame) -> [DetectedMarker] {
        var detectedMarkers: [DetectedMarker] = []

        // Usa AR Image Tracking per rilevare marker
        // Questo richiede immagini di riferimento configurate in AR Assets

        for anchor in frame.anchors {
            if let imageAnchor = anchor as? ARImageAnchor {
                let marker = DetectedMarker(
                    id: imageAnchor.referenceImage.name ?? "Unknown",
                    position: imageAnchor.transform.translation,
                    rotation: imageAnchor.transform.rotation,
                    confidence: imageAnchor.isTracked ? 1.0 : 0.5
                )

                detectedMarkers.append(marker)
            }
        }

        return detectedMarkers
    }

    struct DetectedMarker {
        let id: String
        let position: simd_float3
        let rotation: simd_quatf
        let confidence: Float

        var isCalibrationTarget: Bool {
            return id.contains("CALIB")
        }
    }

    // MARK: - Guided Calibration

    /// Guida l'utente durante la calibrazione
    enum CalibrationStep {
        case placeTarget
        case adjustDistance(current: Float, target: Float)
        case holdSteady(remaining: TimeInterval)
        case processing
        case complete(result: CalibrationResult)
        case failed(reason: String)

        var instruction: String {
            switch self {
            case .placeTarget:
                return "Posiziona il blocchetto di calibrazione su una superficie piana"
            case .adjustDistance(let current, let target):
                let delta = abs(current - target)
                if current < target {
                    return "Avvicinati di \(Int(delta * 100))cm"
                } else {
                    return "Allontanati di \(Int(delta * 100))cm"
                }
            case .holdSteady(let remaining):
                return "Mantieni fermo per \(Int(remaining))s..."
            case .processing:
                return "Elaborazione dati..."
            case .complete:
                return "Calibrazione completata!"
            case .failed(let reason):
                return "Calibrazione fallita: \(reason)"
            }
        }
    }

    /// Esegue calibrazione guidata
    class GuidedCalibration {
        private let parent: AutoCalibrationSystem
        private var currentStep: CalibrationStep = .placeTarget
        private var steadyStartTime: Date?
        private let requiredSteadyTime: TimeInterval = 3.0
        private let optimalDistance: Float = 0.20  // 20cm

        init(parent: AutoCalibrationSystem) {
            self.parent = parent
        }

        func processFrame(_ frame: ARFrame, depthMeasurement: Double?) -> CalibrationStep {
            switch currentStep {
            case .placeTarget:
                // Controlla se marker rilevato
                let markers = parent.detectMarkers(in: frame)

                if let calibMarker = markers.first(where: { $0.isCalibrationTarget }) {
                    let distance = simd_length(calibMarker.position)
                    currentStep = .adjustDistance(current: distance, target: optimalDistance)
                }

            case .adjustDistance(let current, _):
                // Controlla se distanza OK
                if abs(current - optimalDistance) < 0.05 {
                    steadyStartTime = Date()
                    currentStep = .holdSteady(remaining: requiredSteadyTime)
                    parent.startCalibration()
                }

            case .holdSteady:
                // Controlla se tenuto fermo abbastanza
                guard let startTime = steadyStartTime else {
                    currentStep = .placeTarget
                    break
                }

                let elapsed = Date().timeIntervalSince(startTime)

                if let measurement = depthMeasurement {
                    parent.addMeasurement(measurement)
                }

                if elapsed >= requiredSteadyTime {
                    currentStep = .processing

                    if let result = parent.completeCalibration() {
                        currentStep = .complete(result: result)
                    } else {
                        currentStep = .failed(reason: "Dati insufficienti")
                    }
                } else {
                    currentStep = .holdSteady(remaining: requiredSteadyTime - elapsed)
                }

            default:
                break
            }

            return currentStep
        }
    }

    // MARK: - Private Methods

    private func removeOutliersIQR(_ data: [Double], multiplier: Double = 1.5) -> [Double] {
        guard data.count > 3 else { return data }

        let sorted = data.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4

        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - multiplier * iqr
        let upperBound = q3 + multiplier * iqr

        return data.filter { $0 >= lowerBound && $0 <= upperBound }
    }
}

// MARK: - Calibration Persistence

/// Gestisce persistenza dati di calibrazione
class CalibrationPersistence {
    private let userDefaults = UserDefaults.standard
    private let key = "lidar_calibration_data"

    /// Salva risultato calibrazione
    func save(_ result: AutoCalibrationSystem.CalibrationResult) {
        let data: [String: Any] = [
            "offset": result.offset,
            "scale_factor": result.scaleFactor,
            "rmse": result.rmse,
            "timestamp": result.timestamp.timeIntervalSince1970,
            "is_valid": result.isValid
        ]

        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()

        print("💾 [Calibration] Dati salvati")
    }

    /// Carica ultimo risultato calibrazione
    func load() -> (offset: Double, scaleFactor: Double)? {
        guard let data = userDefaults.dictionary(forKey: key),
              let offset = data["offset"] as? Double,
              let scaleFactor = data["scale_factor"] as? Double,
              let timestamp = data["timestamp"] as? TimeInterval,
              let isValid = data["is_valid"] as? Bool else {
            return nil
        }

        // Verifica validità (30 giorni)
        let calibrationDate = Date(timeIntervalSince1970: timestamp)
        let age = Date().timeIntervalSince(calibrationDate)

        guard isValid && age < 30 * 24 * 3600 else {
            print("⚠️ [Calibration] Calibrazione scaduta o non valida")
            return nil
        }

        print("✅ [Calibration] Dati caricati - Offset: \(offset)mm, Scale: \(scaleFactor)")

        return (offset, scaleFactor)
    }

    /// Elimina calibrazione
    func clear() {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()

        print("🗑️ [Calibration] Dati eliminati")
    }
}

// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }

    var rotation: simd_quatf {
        return simd_quatf(self)
    }
}
