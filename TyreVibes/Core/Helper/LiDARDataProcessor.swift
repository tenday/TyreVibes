//
//  LiDARDataProcessor.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import Foundation
import simd
import Accelerate

// MARK: - LiDAR Data Processor

/// Processor avanzato per elaborazione dati LiDAR con algoritmi di machine learning
class LiDARDataProcessor {
    // MARK: - Singleton

    static let shared = LiDARDataProcessor()

    private init() {}

    // MARK: - RANSAC Algorithm

    /// Esegue RANSAC (Random Sample Consensus) per identificare il piano della superficie
    /// - Parameters:
    ///   - points: Nuvola di punti 3D
    ///   - iterations: Numero di iterazioni (default 100)
    ///   - threshold: Soglia di distanza per inliers in metri (default 0.005 = 5mm)
    /// - Returns: Parametri del piano miglior fit (a, b, c, d) per ax + by + cz + d = 0
    func ransacPlaneDetection(points: [simd_float3],
                             iterations: Int = 100,
                             threshold: Float = 0.005) -> (plane: simd_float4, inliers: [simd_float3])? {
        guard points.count >= 3 else { return nil }

        var bestPlane: simd_float4?
        var bestInliers: [simd_float3] = []
        var maxInlierCount = 0

        for _ in 0..<iterations {
            // 1. Seleziona 3 punti random
            guard let sample = randomSample(from: points, count: 3) else { continue }

            // 2. Calcola il piano dai 3 punti
            guard let plane = computePlane(from: sample) else { continue }

            // 3. Conta gli inliers
            var inliers: [simd_float3] = []
            for point in points {
                let distance = abs(distanceToPlane(point: point, plane: plane))
                if distance < threshold {
                    inliers.append(point)
                }
            }

            // 4. Aggiorna il miglior piano se necessario
            if inliers.count > maxInlierCount {
                maxInlierCount = inliers.count
                bestPlane = plane
                bestInliers = inliers
            }
        }

        guard let plane = bestPlane else { return nil }
        return (plane, bestInliers)
    }

    /// Calcola il piano da 3 punti
    private func computePlane(from points: [simd_float3]) -> simd_float4? {
        guard points.count == 3 else { return nil }

        let p1 = points[0]
        let p2 = points[1]
        let p3 = points[2]

        // Vettori del piano
        let v1 = p2 - p1
        let v2 = p3 - p1

        // Normale al piano (prodotto vettoriale)
        let normal = simd_cross(v1, v2)
        let normalLength = simd_length(normal)

        guard normalLength > 1e-6 else { return nil } // Punti collineari

        let normalizedNormal = simd_normalize(normal)

        // ax + by + cz + d = 0
        // d = -normal · p1
        let d = -simd_dot(normalizedNormal, p1)

        return simd_float4(normalizedNormal.x, normalizedNormal.y, normalizedNormal.z, d)
    }

    /// Calcola la distanza di un punto da un piano
    private func distanceToPlane(point: simd_float3, plane: simd_float4) -> Float {
        let normal = simd_float3(plane.x, plane.y, plane.z)
        return simd_dot(normal, point) + plane.w
    }

    // MARK: - Clustering (K-Means)

    /// Esegue clustering K-Means sui punti
    /// - Parameters:
    ///   - points: Nuvola di punti
    ///   - k: Numero di cluster
    ///   - maxIterations: Numero massimo di iterazioni
    /// - Returns: Array di cluster (ogni cluster è un array di punti)
    func kMeansClustering(points: [simd_float3],
                         k: Int,
                         maxIterations: Int = 50) -> [[simd_float3]] {
        guard points.count >= k else {
            return [points]
        }

        // 1. Inizializza centroids random
        var centroids = randomSample(from: points, count: k) ?? Array(points.prefix(k))
        var clusters: [[simd_float3]] = Array(repeating: [], count: k)

        for _ in 0..<maxIterations {
            // 2. Assegna ogni punto al centroid più vicino
            clusters = Array(repeating: [], count: k)

            for point in points {
                var minDistance: Float = .infinity
                var closestCluster = 0

                for (i, centroid) in centroids.enumerated() {
                    let distance = simd_distance(point, centroid)
                    if distance < minDistance {
                        minDistance = distance
                        closestCluster = i
                    }
                }

                clusters[closestCluster].append(point)
            }

            // 3. Ricalcola centroids
            var converged = true
            for (i, cluster) in clusters.enumerated() {
                guard !cluster.isEmpty else { continue }

                let newCentroid = computeCentroid(of: cluster)
                if simd_distance(newCentroid, centroids[i]) > 0.001 {
                    converged = false
                }
                centroids[i] = newCentroid
            }

            if converged { break }
        }

        return clusters.filter { !$0.isEmpty }
    }

    /// Calcola il centroid (punto medio) di un cluster
    private func computeCentroid(of points: [simd_float3]) -> simd_float3 {
        guard !points.isEmpty else { return simd_float3(0, 0, 0) }

        var sum = simd_float3(0, 0, 0)
        for point in points {
            sum += point
        }

        return sum / Float(points.count)
    }

    // MARK: - Density-Based Clustering (DBSCAN)

    /// Esegue DBSCAN (Density-Based Spatial Clustering of Applications with Noise)
    /// - Parameters:
    ///   - points: Nuvola di punti
    ///   - epsilon: Raggio del vicinato in metri (default 0.01 = 1cm)
    ///   - minPoints: Numero minimo di punti per formare un cluster (default 5)
    /// - Returns: Array di cluster
    func dbscan(points: [simd_float3],
                epsilon: Float = 0.01,
                minPoints: Int = 5) -> [[simd_float3]] {
        var clusters: [[simd_float3]] = []
        var visited = Set<Int>()
        var clustered = Set<Int>()

        for (index, point) in points.enumerated() {
            guard !visited.contains(index) else { continue }
            visited.insert(index)

            // Trova i vicini
            let neighbors = findNeighbors(of: point, in: points, epsilon: epsilon)

            if neighbors.count < minPoints {
                // Punto di rumore
                continue
            }

            // Inizia un nuovo cluster
            var cluster: [simd_float3] = []
            var queue = neighbors

            while !queue.isEmpty {
                let neighborIndex = queue.removeFirst()
                guard !clustered.contains(neighborIndex) else { continue }

                clustered.insert(neighborIndex)
                cluster.append(points[neighborIndex])

                if !visited.contains(neighborIndex) {
                    visited.insert(neighborIndex)
                    let newNeighbors = findNeighbors(of: points[neighborIndex],
                                                     in: points,
                                                     epsilon: epsilon)
                    if newNeighbors.count >= minPoints {
                        queue.append(contentsOf: newNeighbors)
                    }
                }
            }

            if !cluster.isEmpty {
                clusters.append(cluster)
            }
        }

        return clusters
    }

    /// Trova i vicini di un punto entro epsilon
    private func findNeighbors(of point: simd_float3,
                               in points: [simd_float3],
                               epsilon: Float) -> [Int] {
        var neighbors: [Int] = []

        for (index, otherPoint) in points.enumerated() {
            if simd_distance(point, otherPoint) <= epsilon {
                neighbors.append(index)
            }
        }

        return neighbors
    }

    // MARK: - Median Filter

    /// Applica un filtro mediano sui dati di profondità
    /// - Parameters:
    ///   - values: Valori di profondità
    ///   - windowSize: Dimensione finestra (deve essere dispari)
    /// - Returns: Valori filtrati
    func medianFilter(values: [Double], windowSize: Int = 5) -> [Double] {
        guard windowSize > 0 && windowSize % 2 == 1 else {
            print("⚠️ [LiDARDataProcessor] Window size deve essere dispari")
            return values
        }

        guard values.count >= windowSize else { return values }

        let halfWindow = windowSize / 2
        var filtered: [Double] = []

        for i in 0..<values.count {
            let start = max(0, i - halfWindow)
            let end = min(values.count - 1, i + halfWindow)

            let window = Array(values[start...end])
            let median = window.sorted()[window.count / 2]
            filtered.append(median)
        }

        return filtered
    }

    // MARK: - Moving Average Filter

    /// Applica un filtro a media mobile
    /// - Parameters:
    ///   - values: Valori da filtrare
    ///   - windowSize: Dimensione finestra
    /// - Returns: Valori filtrati
    func movingAverage(values: [Double], windowSize: Int = 5) -> [Double] {
        guard windowSize > 0 else { return values }
        guard values.count >= windowSize else { return values }

        var filtered: [Double] = []

        for i in 0..<values.count {
            let start = max(0, i - windowSize + 1)
            let end = i + 1

            let window = Array(values[start..<end])
            let average = window.reduce(0.0, +) / Double(window.count)
            filtered.append(average)
        }

        return filtered
    }

    // MARK: - Savitzky-Golay Filter

    /// Applica un filtro Savitzky-Golay per smoothing preservando i picchi
    /// - Parameters:
    ///   - values: Valori da filtrare
    ///   - windowSize: Dimensione finestra (deve essere dispari)
    ///   - polynomialOrder: Ordine del polinomio (default 2)
    /// - Returns: Valori filtrati
    func savitzkyGolayFilter(values: [Double],
                            windowSize: Int = 5,
                            polynomialOrder: Int = 2) -> [Double] {
        guard windowSize > polynomialOrder && windowSize % 2 == 1 else {
            print("⚠️ [LiDARDataProcessor] Parametri filtro SG non validi")
            return values
        }

        // Coefficienti precomputati per windowSize=5, order=2
        let coefficients: [Double] = [-3, 12, 17, 12, -3]
        let normalizer = coefficients.reduce(0, +)

        let halfWindow = windowSize / 2
        var filtered: [Double] = []

        for i in 0..<values.count {
            var sum = 0.0

            for j in 0..<windowSize {
                let index = i - halfWindow + j

                if index >= 0 && index < values.count {
                    sum += values[index] * coefficients[j]
                }
            }

            filtered.append(sum / normalizer)
        }

        return filtered
    }

    // MARK: - Outlier Detection

    /// Rileva e rimuove outliers usando il metodo Z-score
    /// - Parameters:
    ///   - values: Valori da analizzare
    ///   - threshold: Soglia Z-score (default 3.0)
    /// - Returns: Valori senza outliers
    func removeOutliersZScore(values: [Double], threshold: Double = 3.0) -> [Double] {
        guard values.count > 2 else { return values }

        let mean = values.mean
        let stdDev = values.standardDeviation

        guard stdDev > 0 else { return values }

        return values.filter { abs($0 - mean) / stdDev <= threshold }
    }

    /// Rileva outliers usando Modified Z-Score (più robusto)
    /// - Parameters:
    ///   - values: Valori da analizzare
    ///   - threshold: Soglia (default 3.5)
    /// - Returns: Valori senza outliers
    func removeOutliersModifiedZScore(values: [Double], threshold: Double = 3.5) -> [Double] {
        guard values.count > 2 else { return values }

        let median = values.median
        let mad = values.map { abs($0 - median) }.median // Median Absolute Deviation

        guard mad > 0 else { return values }

        let modifiedZScores = values.map { 0.6745 * ($0 - median) / mad }

        return zip(values, modifiedZScores)
            .filter { abs($1) <= threshold }
            .map { $0.0 }
    }

    // MARK: - Distance Calculations

    /// Calcola la profondità del battistrada dalla nuvola di punti
    /// - Parameters:
    ///   - points: Punti 3D della superficie
    ///   - referencePlane: Piano di riferimento
    /// - Returns: Array di profondità in millimetri
    func calculateTreadDepths(points: [simd_float3],
                              referencePlane: simd_float4) -> [Double] {
        return points.map { point in
            let distance = abs(distanceToPlane(point: point, plane: referencePlane))
            return Double(distance * 1000) // Converti in millimetri
        }
    }

    // MARK: - Utility Methods

    /// Seleziona campioni random da un array
    private func randomSample<T>(from array: [T], count: Int) -> [T]? {
        guard array.count >= count else { return nil }

        var indices = Set<Int>()
        while indices.count < count {
            indices.insert(Int.random(in: 0..<array.count))
        }

        return indices.map { array[$0] }
    }

    /// Divide la nuvola di punti in zone del battistrada
    /// - Parameter points: Punti 3D
    /// - Returns: Dictionary con zone e relativi punti
    func segmentIntoZones(points: [simd_float3]) -> [TreadZone: [simd_float3]] {
        var zones: [TreadZone: [simd_float3]] = [:]

        // Trova i limiti della nuvola di punti
        guard let minX = points.map({ $0.x }).min(),
              let maxX = points.map({ $0.x }).max() else {
            return zones
        }

        let width = maxX - minX

        for point in points {
            let normalizedX = (point.x - minX) / width

            let zone: TreadZone
            switch normalizedX {
            case 0..<0.166:
                zone = .innerEdge
            case 0.166..<0.333:
                zone = .shoulderLeft
            case 0.333..<0.5:
                zone = .centerLeft
            case 0.5..<0.666:
                zone = .centerRight
            case 0.666..<0.833:
                zone = .shoulderRight
            default:
                zone = .outerEdge
            }

            zones[zone, default: []].append(point)
        }

        return zones
    }

    /// Calcola la qualità della mesh basandosi sulla densità dei punti
    /// - Parameter pointCount: Numero di punti nella mesh
    /// - Returns: Qualità della mesh
    func assessMeshQuality(pointCount: Int) -> MeshQuality {
        switch pointCount {
        case 10000...:
            return .high
        case 5000..<10000:
            return .medium
        default:
            return .low
        }
    }

    /// Stima le condizioni di illuminazione basandosi sulla confidenza dei punti
    /// - Parameter averageConfidence: Confidenza media (0-1)
    /// - Returns: Condizioni di illuminazione
    func estimateLightingConditions(averageConfidence: Float) -> LightingCondition {
        switch averageConfidence {
        case 0.8...:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        default:
            return .poor
        }
    }
}
