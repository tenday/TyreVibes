//
//  LiDARTreadMeasurementService.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import Foundation
import ARKit
import RealityKit
import Combine
import UIKit

// MARK: - LiDAR Tread Measurement Service

/// Servizio per la misurazione della profondità del battistrada usando LiDAR
class LiDARTreadMeasurementService: NSObject {
    // MARK: - Singleton

    static let shared = LiDARTreadMeasurementService()

    // MARK: - Properties

    /// AR Session per acquisizione dati LiDAR
    private var arSession: ARSession?

    /// Sessione di misurazione corrente
    private(set) var currentSession: MeasurementSession?

    /// Ultimo frame RGB acquisito durante la scansione, usato per inferenza CoreML sul pneumatico.
    private(set) var latestCapturedPixelBuffer: CVPixelBuffer?

    /// Filtro di Kalman per smoothing
    private var kalmanFilter: AdaptiveKalmanFilter?

    /// Processor per elaborazione avanzata
    private let processor = LiDARDataProcessor.shared

    /// Dati di calibrazione
    private var calibrationData: CalibrationData

    /// Publisher per aggiornamenti stato
    var measurementPublisher = PassthroughSubject<MeasurementUpdate, Never>()

    /// Verifica disponibilità LiDAR sul dispositivo
    var isLiDARAvailable: Bool {
        guard #available(iOS 13.4, *) else { return false }
        // Esplicita il tipo per evitare ambiguità di risoluzione dell'overload
        let reconstructionMode: ARWorldTrackingConfiguration.SceneReconstruction = .mesh
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(reconstructionMode)
    }

    // MARK: - Configuration

    /// Configurazione per la scansione
    struct ScanConfiguration {
        /// Durata minima scansione in secondi
        var minScanDuration: TimeInterval = 3.0

        /// Durata massima scansione in secondi
        var maxScanDuration: TimeInterval = 15.0

        /// Numero minimo di punti richiesti
        var minPointCount: Int = 1000

        /// Distanza massima valida in metri
        var maxDistance: Float = 0.5

        /// Confidenza minima dei punti (0-1)
        var minConfidence: Float = 0.5

        /// Abilita filtro Kalman
        var enableKalmanFilter: Bool = true

        /// Abilita RANSAC per plane detection
        var enableRANSAC: Bool = true

        /// Abilita rimozione outliers
        var enableOutlierRemoval: Bool = true

        static var `default`: ScanConfiguration {
            return ScanConfiguration()
        }
    }

    private var configuration: ScanConfiguration = .default

    // MARK: - Initialization

    private override init() {
        self.calibrationData = CalibrationData.default
        super.init()
        loadCalibrationData()
    }

    // MARK: - Public Methods

    /// Configura e avvia la sessione AR
    /// - Parameter arView: ARView da utilizzare
    /// - Throws: Error se LiDAR non disponibile
    func setupARSession(_ arView: ARView) throws {
        guard isLiDARAvailable else {
            throw MeasurementError.lidarNotAvailable
        }

        let configuration = ARWorldTrackingConfiguration()

        // Abilita scene reconstruction con mesh
        if #available(iOS 13.4, *) {
            let reconstructionMode: ARWorldTrackingConfiguration.SceneReconstruction = .mesh
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(reconstructionMode) {
                configuration.sceneReconstruction = reconstructionMode
            }
        }

        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Massima qualità per LiDAR
        configuration.videoFormat = ARWorldTrackingConfiguration
            .supportedVideoFormats
            .sorted { $0.imageResolution.width > $1.imageResolution.width }
            .first ?? ARWorldTrackingConfiguration.supportedVideoFormats[0]

        arSession = arView.session
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        print("✅ [LiDARService] AR Session configurata con successo")
    }

    /// Avvia una nuova misurazione
    /// - Parameters:
    ///   - tyreId: ID del pneumatico da misurare (opzionale)
    ///   - config: Configurazione della scansione
    func startMeasurement(tyreId: UUID? = nil,
                         configuration config: ScanConfiguration = .default) {
        self.configuration = config

        currentSession = MeasurementSession(id: UUID(), startTime: Date())
        currentSession?.isProcessing = false
        latestCapturedPixelBuffer = nil

        if config.enableKalmanFilter {
            kalmanFilter = AdaptiveKalmanFilter(
                initialEstimate: 5.0,
                initialUncertainty: 1.0,
                windowSize: 10
            )
        }

        measurementPublisher.send(.started)
        print("🔍 [LiDARService] Misurazione avviata - Session ID: \(currentSession?.id.uuidString ?? "N/A")")
    }

    /// Acquisisce un frame di dati LiDAR
    /// - Parameter frame: ARFrame corrente
    func captureFrame(_ frame: ARFrame) {
        guard let session = currentSession, !session.isProcessing else { return }
        latestCapturedPixelBuffer = frame.capturedImage

        // Estrai depth map dal frame
        guard let sceneDepth = frame.sceneDepth else {
            measurementPublisher.send(.error(.noDepthData))
            return
        }

        let depthMap = sceneDepth.depthMap
        let confidenceMap = sceneDepth.confidenceMap

        // Converti depth map in nuvola di punti
        let points = extractPointCloud(
            from: depthMap,
            confidenceMap: confidenceMap,
            cameraTransform: frame.camera.transform
        )

        // Filtra punti per distanza e confidenza
        let filteredPoints = points.filter {
            $0.distance < configuration.maxDistance &&
            $0.confidence >= configuration.minConfidence
        }

        // Aggiungi punti alla sessione
        for point in filteredPoints {
            session.addPoint(point)
        }

        // Aggiorna stato
        let progress = min(1.0, session.duration / configuration.minScanDuration)
        measurementPublisher.send(.progress(Float(progress), session.rawPoints.count))

        print("📊 [LiDARService] Frame acquisito - Punti: \(filteredPoints.count) (Tot: \(session.rawPoints.count))")
    }

    /// Finalizza la misurazione ed elabora i dati
    /// - Returns: Risultato della misurazione
    /// - Throws: Error se la misurazione fallisce
    func finalizeMeasurement() async throws -> TreadDepthMeasurement {
        guard let session = currentSession else {
            throw MeasurementError.noActiveSession
        }

        session.isProcessing = true
        session.finalize()

        measurementPublisher.send(.processing)

        print("⚙️ [LiDARService] Elaborazione misurazione - Punti totali: \(session.rawPoints.count)")

        // Verifica numero minimo di punti
        guard session.rawPoints.count >= configuration.minPointCount else {
            throw MeasurementError.insufficientData
        }

        // Converti punti in array simd_float3
        let points = session.rawPoints.map { $0.position }

        // 1. RANSAC per identificare piano di riferimento
        var referencePlane: simd_float4?
        var inlierPoints: [simd_float3] = points

        if configuration.enableRANSAC {
            if let result = processor.ransacPlaneDetection(
                points: points,
                iterations: 100,
                threshold: 0.005
            ) {
                referencePlane = result.plane
                inlierPoints = result.inliers
                print("✅ [LiDARService] Piano di riferimento identificato - Inliers: \(inlierPoints.count)")
            }
        }

        // 2. Clustering per segmentare diverse aree
        let clusters = processor.dbscan(
            points: inlierPoints,
            epsilon: 0.015,
            minPoints: 10
        )

        print("🔍 [LiDARService] Clustering completato - Cluster: \(clusters.count)")

        // Usa il cluster più grande (presumibilmente la superficie del battistrada)
        guard let mainCluster = clusters.max(by: { $0.count < $1.count }) else {
            throw MeasurementError.processingFailed
        }

        // 3. Segmenta in zone del battistrada
        let zones = processor.segmentIntoZones(points: mainCluster)

        // 4. Calcola profondità per ogni zona
        var depthMap: [TreadZone: Double] = [:]
        var allDepths: [Double] = []

        for (zone, zonePoints) in zones {
            guard !zonePoints.isEmpty else { continue }

            // Calcola distanze dal piano di riferimento
            let depths: [Double]
            if let plane = referencePlane {
                depths = processor.calculateTreadDepths(
                    points: zonePoints,
                    referencePlane: plane
                )
            } else {
                // Fallback: usa coordinate Z
                depths = zonePoints.map { Double($0.z * 1000) }
            }

            // Rimuovi outliers
            var cleanedDepths = depths
            if configuration.enableOutlierRemoval {
                cleanedDepths = processor.removeOutliersModifiedZScore(
                    values: depths,
                    threshold: 3.5
                )
            }

            // Applica filtro mediano
            cleanedDepths = processor.medianFilter(
                values: cleanedDepths,
                windowSize: 5
            )

            // Applica Kalman filter se abilitato
            if configuration.enableKalmanFilter, let filter = kalmanFilter {
                cleanedDepths = filter.updateBatch(cleanedDepths)
            }

            let avgDepth = cleanedDepths.mean
            depthMap[zone] = avgDepth
            allDepths.append(contentsOf: cleanedDepths)

            print("📍 [LiDARService] Zona \(zone.displayName): \(String(format: "%.2f", avgDepth))mm")
        }

        // 5. Statistiche globali
        guard !allDepths.isEmpty else {
            throw MeasurementError.processingFailed
        }

        let avgDepth = allDepths.mean
        let minDepth = allDepths.min() ?? 0
        let maxDepth = allDepths.max() ?? 0
        let stdDev = allDepths.standardDeviation

        // 6. Calcola confidence score basato su vari fattori
        let confidenceScore = calculateConfidenceScore(
            pointCount: session.rawPoints.count,
            stdDev: stdDev,
            clusterCount: clusters.count,
            scanDuration: session.duration
        )

        // 7. Determina stato del battistrada
        let treadStatus = TreadStatus.from(
            averageDepth: avgDepth,
            standardDeviation: stdDev
        )

        // 8. Raccogli metadati
        let metadata = collectMetadata(
            session: session,
            meshQuality: processor.assessMeshQuality(pointCount: session.rawPoints.count)
        )

        // 9. Crea risultato
        let measurement = TreadDepthMeasurement(
            tyreId: session.id,
            averageDepth: avgDepth,
            minDepth: minDepth,
            maxDepth: maxDepth,
            standardDeviation: stdDev,
            confidenceScore: confidenceScore,
            samplePoints: session.rawPoints.count,
            depthMap: depthMap,
            treadStatus: treadStatus,
            metadata: metadata
        )

        // Pulisci sessione
        currentSession = nil
        kalmanFilter = nil

        measurementPublisher.send(.completed(measurement))

        print("✅ [LiDARService] Misurazione completata - Profondità media: \(String(format: "%.2f", avgDepth))mm - Stato: \(treadStatus.displayName)")

        return measurement
    }

    /// Annulla la misurazione corrente
    func cancelMeasurement() {
        currentSession?.finalize()
        currentSession = nil
        kalmanFilter = nil

        measurementPublisher.send(.cancelled)
        print("⚠️ [LiDARService] Misurazione annullata")
    }

    /// Ferma la sessione AR
    func stopARSession() {
        arSession?.pause()
        arSession = nil
        print("🛑 [LiDARService] AR Session fermata")
    }

    // MARK: - Private Methods

    /// Estrae la nuvola di punti da depth map
    private func extractPointCloud(from depthMap: CVPixelBuffer,
                                   confidenceMap: CVPixelBuffer?,
                                   cameraTransform: simd_float4x4) -> [LiDARPoint] {
        var points: [LiDARPoint] = []

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let lockedConfidenceMap = confidenceMap
        if let confMap = lockedConfidenceMap {
            CVPixelBufferLockBaseAddress(confMap, .readOnly)
        }
        defer {
            if let confMap = lockedConfidenceMap {
                CVPixelBufferUnlockBaseAddress(confMap, .readOnly)
            }
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard let depthData = CVPixelBufferGetBaseAddress(depthMap) else {
            return points
        }

        let confData = lockedConfidenceMap.flatMap { CVPixelBufferGetBaseAddress($0) }

        let depthPointer = depthData.assumingMemoryBound(to: Float32.self)
        let confPointer = confData?.assumingMemoryBound(to: UInt8.self)

        // Campionamento (ogni N pixel per performance)
        let pixelStride = 4

        for y in stride(from: 0, to: height, by: pixelStride) {
            for x in stride(from: 0, to: width, by: pixelStride) {
                let index = y * width + x
                let depth = depthPointer[index]

                // Salta se depth non valido
                guard depth > 0 && depth.isFinite else { continue }

                // Ottieni confidenza
                let confidence: Float
                if let confPtr = confPointer {
                    let confValue = confPtr[index]
                    confidence = Float(confValue) / 255.0
                } else {
                    confidence = 1.0
                }

                // Converti coordinate pixel in 3D
                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)

                // Posizione in camera space
                let cameraPoint = simd_float3(
                    (normalizedX - 0.5) * depth,
                    (0.5 - normalizedY) * depth,
                    -depth
                )

                // Trasforma in world space
                let worldPoint = (cameraTransform * simd_float4(cameraPoint, 1.0)).xyz

                let point = LiDARPoint(
                    position: worldPoint,
                    confidence: confidence,
                    timestamp: Date().timeIntervalSince1970
                )

                points.append(point)
            }
        }

        return points
    }

    /// Calcola confidence score della misurazione
    private func calculateConfidenceScore(pointCount: Int,
                                         stdDev: Double,
                                         clusterCount: Int,
                                         scanDuration: TimeInterval) -> Double {
        var score = 0.0

        // Fattore 1: Numero di punti (max 40 punti)
        let pointScore = min(40.0, Double(pointCount) / 250.0)
        score += pointScore

        // Fattore 2: Deviazione standard bassa = alta qualità (max 30 punti)
        let stdDevScore = max(0, 30 - stdDev * 10)
        score += stdDevScore

        // Fattore 3: Pochi cluster = superficie uniforme (max 15 punti)
        let clusterScore = max(0, 15 - Double(clusterCount - 1) * 2)
        score += clusterScore

        // Fattore 4: Durata scan adeguata (max 15 punti)
        let durationScore = min(15, scanDuration / configuration.minScanDuration * 15)
        score += durationScore

        return min(100, max(0, score))
    }

    /// Raccoglie metadati sulla misurazione
    private func collectMetadata(session: MeasurementSession,
                                 meshQuality: MeshQuality) -> MeasurementMetadata {
        let device = UIDevice.current
        let avgConfidence = session.rawPoints.map { $0.confidence }.reduce(0, +) /
                           Float(max(1, session.rawPoints.count))

        let lightingConditions = processor.estimateLightingConditions(
            averageConfidence: avgConfidence
        )

        let avgDistance = session.rawPoints.map { $0.distance }.reduce(0, +) /
                         Float(max(1, session.rawPoints.count))

        return MeasurementMetadata(
            deviceModel: device.model,
            osVersion: device.systemVersion,
            hasLiDAR: isLiDARAvailable,
            lightingConditions: lightingConditions,
            averageDistance: Double(avgDistance * 100), // Converti in cm
            scanDuration: session.duration,
            meshQuality: meshQuality
        )
    }

    // MARK: - Calibration

    /// Carica dati di calibrazione
    private func loadCalibrationData() {
        if let data = UserDefaults.standard.data(forKey: "lidar_calibration"),
           let decoded = try? JSONDecoder().decode(CalibrationData.self, from: data),
           decoded.isValid {
            calibrationData = decoded
            print("✅ [LiDARService] Calibrazione caricata")
        } else {
            calibrationData = .default
            print("⚠️ [LiDARService] Calibrazione default utilizzata")
        }
    }

    /// Salva dati di calibrazione
    func saveCalibration(_ data: CalibrationData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "lidar_calibration")
            calibrationData = data
            print("✅ [LiDARService] Calibrazione salvata")
        }
    }

    /// Esegue calibrazione con un oggetto di riferimento noto
    /// - Parameter knownDepth: Profondità nota in mm
    func calibrate(knownDepth: Double) async throws -> CalibrationData {
        // Esegui misurazione
        let measurement = try await finalizeMeasurement()

        // Calcola offset
        let measuredDepth = measurement.averageDepth
        let offset = knownDepth - measuredDepth
        let scaleFactor = knownDepth / measuredDepth

        let newCalibration = CalibrationData(
            offset: offset,
            scaleFactor: scaleFactor,
            lastCalibration: Date()
        )

        saveCalibration(newCalibration)

        return newCalibration
    }
}

// MARK: - Measurement Update

enum MeasurementUpdate {
    case started
    case progress(Float, Int) // progress (0-1), point count
    case processing
    case completed(TreadDepthMeasurement)
    case error(MeasurementError)
    case cancelled
}

// MARK: - Measurement Error

enum MeasurementError: LocalizedError {
    case lidarNotAvailable
    case noActiveSession
    case insufficientData
    case noDepthData
    case processingFailed
    case calibrationRequired

    var errorDescription: String? {
        switch self {
        case .lidarNotAvailable:
            return "LiDAR non disponibile su questo dispositivo. Richiesto iPhone 12 Pro o successivo."
        case .noActiveSession:
            return "Nessuna sessione di misurazione attiva."
        case .insufficientData:
            return "Dati insufficienti. Scansiona per più tempo o avvicinati al pneumatico."
        case .noDepthData:
            return "Impossibile acquisire dati di profondità."
        case .processingFailed:
            return "Elaborazione dati fallita. Riprova."
        case .calibrationRequired:
            return "Calibrazione richiesta prima di utilizzare lo strumento."
        }
    }
}

// MARK: - simd_float4 Extension

extension simd_float4 {
    var xyz: simd_float3 {
        return simd_float3(x, y, z)
    }
}
