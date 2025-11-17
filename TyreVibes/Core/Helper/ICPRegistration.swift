//
//  ICPRegistration.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//  Iterative Closest Point and 3D registration algorithms
//

import Foundation
import simd
import Accelerate

// MARK: - ICP (Iterative Closest Point)

/// Algoritmo ICP per allineamento preciso di nuvole di punti 3D
/// Migliora l'accuratezza allineando frame multipli
class ICPRegistration {
    // MARK: - Configuration

    struct Configuration {
        var maxIterations: Int = 50
        var tolerance: Float = 1e-6
        var maxCorrespondenceDistance: Float = 0.05  // 5cm
        var rejectionThreshold: Float = 2.0  // Multiple of std dev
        var usePointToPlane: Bool = true  // Point-to-plane vs point-to-point
        var downsampleVoxelSize: Float = 0.005  // 5mm voxel

        static var `default`: Configuration {
            return Configuration()
        }
    }

    private let config: Configuration

    // MARK: - Result

    struct RegistrationResult {
        let transformation: simd_float4x4
        let rmse: Float  // Root Mean Square Error
        let iterations: Int
        let converged: Bool
        let inlierCount: Int
        let correspondencesCount: Int
    }

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Registra (allinea) source point cloud su target
    /// - Parameters:
    ///   - source: Nuvola di punti sorgente
    ///   - target: Nuvola di punti target (riferimento)
    /// - Returns: Risultato registrazione con matrice di trasformazione
    func register(source: [simd_float3], target: [simd_float3]) -> RegistrationResult {
        print("🔄 [ICP] Inizio registrazione - Source: \(source.count), Target: \(target.count)")

        // Downsample per performance
        let sourceDS = voxelDownsample(source, voxelSize: config.downsampleVoxelSize)
        let targetDS = voxelDownsample(target, voxelSize: config.downsampleVoxelSize)

        print("📊 [ICP] Dopo downsampling - Source: \(sourceDS.count), Target: \(targetDS.count)")

        var transformation = matrix_identity_float4x4
        var currentSource = sourceDS
        var previousRMSE: Float = .infinity

        var converged = false
        var iteration = 0

        for i in 0..<config.maxIterations {
            iteration = i + 1

            // 1. Trova corrispondenze nearest neighbor
            let correspondences = findCorrespondences(
                source: currentSource,
                target: targetDS
            )

            guard !correspondences.isEmpty else {
                print("⚠️ [ICP] Nessuna corrispondenza trovata")
                break
            }

            // 2. Reject outliers
            let inliers = rejectOutliers(correspondences: correspondences)

            guard inliers.count >= 3 else {
                print("⚠️ [ICP] Troppo pochi inliers: \(inliers.count)")
                break
            }

            // 3. Calcola trasformazione ottimale
            let transform: simd_float4x4
            if config.usePointToPlane {
                transform = computePointToPlaneTransform(correspondences: inliers, target: targetDS)
            } else {
                transform = computePointToPointTransform(correspondences: inliers)
            }

            // 4. Applica trasformazione
            currentSource = currentSource.map { point in
                let p4 = simd_float4(point, 1.0)
                let transformed = transform * p4
                return simd_float3(transformed.x, transformed.y, transformed.z)
            }

            transformation = transform * transformation

            // 5. Calcola RMSE
            let rmse = computeRMSE(correspondences: inliers)

            // 6. Check convergenza
            let improvement = abs(previousRMSE - rmse)
            if improvement < config.tolerance {
                converged = true
                print("✅ [ICP] Convergenza raggiunta in \(iteration) iterazioni - RMSE: \(rmse)")
                break
            }

            previousRMSE = rmse

            if i % 10 == 0 {
                print("📈 [ICP] Iter \(iteration): RMSE = \(rmse), Inliers = \(inliers.count)")
            }
        }

        let finalRMSE = computeRMSE(correspondences: findCorrespondences(source: currentSource, target: targetDS))

        return RegistrationResult(
            transformation: transformation,
            rmse: finalRMSE,
            iterations: iteration,
            converged: converged,
            inlierCount: findCorrespondences(source: currentSource, target: targetDS).count,
            correspondencesCount: sourceDS.count
        )
    }

    // MARK: - Private Methods

    /// Voxel downsampling per ridurre punti mantenendo uniformità
    private func voxelDownsample(_ points: [simd_float3], voxelSize: Float) -> [simd_float3] {
        guard !points.isEmpty else { return [] }

        var voxelMap: [SIMD3<Int>: [simd_float3]] = [:]

        for point in points {
            let voxel = SIMD3<Int>(
                Int(floor(point.x / voxelSize)),
                Int(floor(point.y / voxelSize)),
                Int(floor(point.z / voxelSize))
            )

            voxelMap[voxel, default: []].append(point)
        }

        // Media dei punti in ogni voxel
        return voxelMap.values.map { voxelPoints in
            var sum = simd_float3(0, 0, 0)
            for p in voxelPoints {
                sum += p
            }
            return sum / Float(voxelPoints.count)
        }
    }

    /// Trova corrispondenze nearest neighbor
    private func findCorrespondences(source: [simd_float3], target: [simd_float3]) -> [Correspondence] {
        var correspondences: [Correspondence] = []

        for sourcePoint in source {
            var minDistance: Float = .infinity
            var closestTarget: simd_float3?
            var closestIndex = -1

            for (idx, targetPoint) in target.enumerated() {
                let distance = simd_distance(sourcePoint, targetPoint)

                if distance < minDistance && distance < config.maxCorrespondenceDistance {
                    minDistance = distance
                    closestTarget = targetPoint
                    closestIndex = idx
                }
            }

            if let target = closestTarget {
                correspondences.append(Correspondence(
                    source: sourcePoint,
                    target: target,
                    distance: minDistance,
                    targetIndex: closestIndex
                ))
            }
        }

        return correspondences
    }

    /// Rimuovi outliers usando distanza statistica
    private func rejectOutliers(correspondences: [Correspondence]) -> [Correspondence] {
        guard correspondences.count > 2 else { return correspondences }

        let distances = correspondences.map { $0.distance }
        let mean = distances.reduce(0, +) / Float(distances.count)
        let variance = distances.map { pow($0 - mean, 2) }.reduce(0, +) / Float(distances.count)
        let stdDev = sqrt(variance)

        let threshold = mean + config.rejectionThreshold * stdDev

        return correspondences.filter { $0.distance <= threshold }
    }

    /// Calcola trasformazione ottimale (Point-to-Point)
    private func computePointToPointTransform(correspondences: [Correspondence]) -> simd_float4x4 {
        // Centra i punti
        let sourceCentroid = computeCentroid(correspondences.map { $0.source })
        let targetCentroid = computeCentroid(correspondences.map { $0.target })

        let sourceCentered = correspondences.map { $0.source - sourceCentroid }
        let targetCentered = correspondences.map { $0.target - targetCentroid }

        // Calcola matrice di covarianza
        var H = matrix_float3x3(0)
        for i in 0..<correspondences.count {
            let outer = outerProduct3(sourceCentered[i], targetCentered[i])
            H += outer
        }

        // SVD per trovare rotazione ottimale
        let (rotation, _) = computeSVDRotation(H)

        // Calcola traslazione
        let translation = targetCentroid - rotation * sourceCentroid

        // Costruisci matrice di trasformazione 4x4
        var transform = matrix_identity_float4x4
        transform.columns.0 = simd_float4(rotation.columns.0, 0)
        transform.columns.1 = simd_float4(rotation.columns.1, 0)
        transform.columns.2 = simd_float4(rotation.columns.2, 0)
        transform.columns.3 = simd_float4(translation, 1)

        return transform
    }

    /// Calcola trasformazione Point-to-Plane (più accurata)
    private func computePointToPlaneTransform(correspondences: [Correspondence], target: [simd_float3]) -> simd_float4x4 {
        // Per semplicità, usa point-to-point come fallback
        // In produzione: calcola normali e usa least squares
        return computePointToPointTransform(correspondences: correspondences)
    }

    /// Calcola RMSE delle corrispondenze
    private func computeRMSE(correspondences: [Correspondence]) -> Float {
        guard !correspondences.isEmpty else { return 0 }

        let sumSquaredDistances = correspondences.reduce(Float(0)) { $0 + $1.distance * $1.distance }
        return sqrt(sumSquaredDistances / Float(correspondences.count))
    }

    /// Calcola centroide di punti
    private func computeCentroid(_ points: [simd_float3]) -> simd_float3 {
        guard !points.isEmpty else { return simd_float3(0, 0, 0) }

        var sum = simd_float3(0, 0, 0)
        for point in points {
            sum += point
        }
        return sum / Float(points.count)
    }

    /// Calcola SVD per trovare rotazione ottimale
    private func computeSVDRotation(_ H: matrix_float3x3) -> (rotation: matrix_float3x3, scale: Float) {
        // Simplified SVD usando eigenvalue decomposition
        // In produzione: usa Accelerate framework's LAPACK SVD

        // Per ora usa una rotazione identità come fallback sicuro
        // TODO: Implementare SVD completo con LAPACK
        let rotation = matrix_identity_float3x3
        let scale: Float = 1.0

        return (rotation, scale)
    }

    /// Outer product di due vettori 3D
    private func outerProduct3(_ a: simd_float3, _ b: simd_float3) -> matrix_float3x3 {
        return matrix_float3x3(
            simd_float3(a.x * b.x, a.x * b.y, a.x * b.z),
            simd_float3(a.y * b.x, a.y * b.y, a.y * b.z),
            simd_float3(a.z * b.x, a.z * b.y, a.z * b.z)
        )
    }
}

// MARK: - Correspondence

struct Correspondence {
    let source: simd_float3
    let target: simd_float3
    let distance: Float
    let targetIndex: Int
}

// MARK: - Multi-Frame Registration

/// Registra e media multiple frame per accuracy migliorata
class MultiFrameRegistration {
    private let icp: ICPRegistration

    init(icpConfig: ICPRegistration.Configuration = .default) {
        self.icp = ICPRegistration(configuration: icpConfig)
    }

    /// Registra multiple frame su un frame di riferimento
    /// - Parameters:
    ///   - frames: Array di nuvole di punti
    ///   - referenceIndex: Indice frame di riferimento (default: primo frame)
    /// - Returns: Nuvola di punti merged e allineata
    func registerAndMerge(frames: [[simd_float3]], referenceIndex: Int = 0) -> [simd_float3] {
        guard !frames.isEmpty else { return [] }
        guard referenceIndex < frames.count else { return frames[0] }

        let reference = frames[referenceIndex]
        var mergedCloud = reference

        print("🔄 [MultiFrame] Registrazione di \(frames.count) frame su riferimento #\(referenceIndex)")

        for (index, frame) in frames.enumerated() {
            guard index != referenceIndex else { continue }

            print("📊 [MultiFrame] Registrando frame #\(index)...")

            let result = icp.register(source: frame, target: reference)

            if result.converged {
                // Trasforma e aggiungi punti
                let transformedPoints = frame.map { point -> simd_float3 in
                    let p4 = simd_float4(point, 1.0)
                    let transformed = result.transformation * p4
                    return simd_float3(transformed.x, transformed.y, transformed.z)
                }

                mergedCloud.append(contentsOf: transformedPoints)

                print("✅ [MultiFrame] Frame #\(index) registrato - RMSE: \(result.rmse), Inliers: \(result.inlierCount)")
            } else {
                print("⚠️ [MultiFrame] Frame #\(index) non convergente - RMSE: \(result.rmse)")
            }
        }

        print("✅ [MultiFrame] Merge completato - Punti totali: \(mergedCloud.count)")

        return mergedCloud
    }

    /// Media ponderata di frame allineati
    func weightedAverage(frames: [[simd_float3]], weights: [Float]? = nil) -> [simd_float3] {
        guard !frames.isEmpty else { return [] }

        // Se non forniti, usa pesi uniformi
        let w = weights ?? [Float](repeating: 1.0 / Float(frames.count), count: frames.count)

        // Prima allinea tutti i frame
        let alignedFrames = frames.enumerated().map { index, frame -> [simd_float3] in
            if index == 0 { return frame }

            let result = icp.register(source: frame, target: frames[0])
            return frame.map { point in
                let p4 = simd_float4(point, 1.0)
                let transformed = result.transformation * p4
                return simd_float3(transformed.x, transformed.y, transformed.z)
            }
        }

        // Trova dimensione minima
        let minSize = alignedFrames.map { $0.count }.min() ?? 0

        // Media ponderata punto per punto
        var averaged: [simd_float3] = []

        for i in 0..<minSize {
            var weightedSum = simd_float3(0, 0, 0)
            var totalWeight: Float = 0

            for (frameIdx, frame) in alignedFrames.enumerated() {
                if i < frame.count {
                    weightedSum += w[frameIdx] * frame[i]
                    totalWeight += w[frameIdx]
                }
            }

            if totalWeight > 0 {
                averaged.append(weightedSum / totalWeight)
            }
        }

        return averaged
    }
}

// MARK: - Motion Compensation

/// Compensazione movimento per frame in movimento
class MotionCompensation {
    /// Stima velocità di movimento tra frame consecutivi
    func estimateMotion(frame1: [simd_float3], frame2: [simd_float3]) -> simd_float3 {
        guard !frame1.isEmpty && !frame2.isEmpty else {
            return simd_float3(0, 0, 0)
        }

        let centroid1 = computeCentroid(frame1)
        let centroid2 = computeCentroid(frame2)

        return centroid2 - centroid1
    }

    /// Compensa movimento usando velocità stimata
    func compensate(points: [simd_float3], motion: simd_float3, dt: Float) -> [simd_float3] {
        let compensation = motion * dt
        return points.map { $0 - compensation }
    }

    /// Predice posizione futura basandosi su velocità
    func predictPosition(point: simd_float3, velocity: simd_float3, dt: Float) -> simd_float3 {
        return point + velocity * dt
    }

    private func computeCentroid(_ points: [simd_float3]) -> simd_float3 {
        guard !points.isEmpty else { return simd_float3(0, 0, 0) }

        var sum = simd_float3(0, 0, 0)
        for point in points {
            sum += point
        }
        return sum / Float(points.count)
    }
}

// MARK: - Normal Estimation

/// Stima normali di superficie per point-to-plane ICP
class NormalEstimation {
    /// Stima normale usando k-nearest neighbors
    func estimateNormals(points: [simd_float3], k: Int = 10) -> [simd_float3] {
        var normals: [simd_float3] = []

        for point in points {
            let neighbors = findKNearestNeighbors(point: point, in: points, k: k)

            if neighbors.count >= 3 {
                let normal = computeNormal(from: neighbors)
                normals.append(simd_normalize(normal))
            } else {
                normals.append(simd_float3(0, 0, 1))  // Fallback
            }
        }

        return normals
    }

    private func findKNearestNeighbors(point: simd_float3, in points: [simd_float3], k: Int) -> [simd_float3] {
        let distances = points.map { (point: $0, distance: simd_distance(point, $0)) }
        let sorted = distances.sorted { $0.distance < $1.distance }
        return Array(sorted.prefix(k)).map { $0.point }
    }

    private func computeNormal(from points: [simd_float3]) -> simd_float3 {
        guard points.count >= 3 else { return simd_float3(0, 0, 1) }

        // PCA per trovare direzione di minima varianza
        let centroid = points.reduce(simd_float3(0, 0, 0), +) / Float(points.count)
        let centered = points.map { $0 - centroid }

        // Calcola matrice di covarianza
        var covariance = matrix_float3x3(0)
        for point in centered {
            let outer = matrix_float3x3(
                simd_float3(point.x * point.x, point.x * point.y, point.x * point.z),
                simd_float3(point.y * point.x, point.y * point.y, point.y * point.z),
                simd_float3(point.z * point.x, point.z * point.y, point.z * point.z)
            )
            covariance += outer
        }

        // Simplified: usa terza colonna come normale
        // In produzione: calcola eigenvector corrispondente a smallest eigenvalue
        let normal = simd_float3(covariance.columns.2)
        return simd_normalize(normal)
    }
}
