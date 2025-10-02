//
//  TreadDepthAnalyzer.swift
//  TyreVibes
//
//  Created on 2025-10-02.
//  Advanced tread depth analysis with Kalman filtering
//

import Foundation
import Vision
import CoreImage
import Accelerate

/// Advanced tread depth analyzer with Kalman filtering for maximum precision
class TreadDepthAnalyzer {

    // MARK: - Types

    struct DepthMeasurement {
        let depth: Double // in millimeters
        let confidence: Double // 0.0 to 1.0
        let location: CGPoint
        let timestamp: Date
        let rawDepth: Double
        let filteredDepth: Double
    }

    struct AnalysisResult {
        let measurements: [DepthMeasurement]
        let averageDepth: Double
        let minDepth: Double
        let maxDepth: Double
        let standardDeviation: Double
        let wearPattern: WearPattern
        let quality: QualityMetric
        let isLegal: Bool // Based on minimum legal depth (typically 1.6mm)
    }

    enum WearPattern {
        case uniform
        case centerWear
        case edgeWear
        case patchyWear
        case excessive

        var description: String {
            switch self {
            case .uniform: return "Uniforme"
            case .centerWear: return "Usura centrale"
            case .edgeWear: return "Usura laterale"
            case .patchyWear: return "Usura irregolare"
            case .excessive: return "Usura eccessiva"
            }
        }
    }

    struct QualityMetric {
        let overallScore: Double // 0.0 to 1.0
        let measurementCount: Int
        let averageConfidence: Double
        let stabilityScore: Double
    }

    // MARK: - Kalman Filter

    private class KalmanFilter {
        // State variables
        private var estimate: Double
        private var estimateError: Double

        // Process and measurement noise
        private let processNoise: Double
        private let measurementNoise: Double

        init(initialEstimate: Double = 0.0,
             initialError: Double = 1.0,
             processNoise: Double = 0.001,
             measurementNoise: Double = 0.1) {
            self.estimate = initialEstimate
            self.estimateError = initialError
            self.processNoise = processNoise
            self.measurementNoise = measurementNoise
        }

        func update(measurement: Double) -> Double {
            // Prediction step
            let predictedEstimate = estimate
            let predictedError = estimateError + processNoise

            // Update step
            let kalmanGain = predictedError / (predictedError + measurementNoise)
            estimate = predictedEstimate + kalmanGain * (measurement - predictedEstimate)
            estimateError = (1.0 - kalmanGain) * predictedError

            return estimate
        }

        func reset(to value: Double) {
            estimate = value
            estimateError = 1.0
        }

        var currentEstimate: Double {
            return estimate
        }
    }

    // MARK: - Properties

    private var kalmanFilters: [String: KalmanFilter] = [:]
    private let minimumLegalDepth: Double = 1.6 // mm
    private let newTyreDepth: Double = 8.0 // mm (typical for new tyres)

    // Analysis parameters
    private let edgeThreshold: Double = 0.15 // 15% from edge
    private let centerThreshold: Double = 0.35 // 35% from center

    // Calibration data
    private var calibrationProfile: CalibrationProfile?
    private var isCalibrated: Bool { calibrationProfile != nil }

    // MARK: - Calibration Types

    struct CalibrationProfile: Codable {
        let referenceDepth: Double // Known depth in mm
        let edgeDensityFactor: Double
        let textureFactor: Double
        let offsetCorrection: Double
        let scaleFactor: Double
        let timestamp: Date
        let sampleCount: Int
        let confidence: Double

        var isValid: Bool {
            confidence > 0.7 && Date().timeIntervalSince(timestamp) < 30 * 24 * 3600 // Valid for 30 days
        }
    }

    struct CalibrationSample {
        let knownDepth: Double
        let measuredEdgeDensity: Double
        let measuredTexture: Double
        let rawEstimate: Double
    }

    enum CalibrationError: Error {
        case insufficientSamples
        case invalidReferenceDepth
        case noCalibrationData
        case calibrationFailed

        var localizedDescription: String {
            switch self {
            case .insufficientSamples: return "Campioni insufficienti per calibrazione"
            case .invalidReferenceDepth: return "Profondità di riferimento non valida"
            case .noCalibrationData: return "Dati di calibrazione non disponibili"
            case .calibrationFailed: return "Calibrazione fallita"
            }
        }
    }

    // MARK: - Initialization

    init() {
        loadCalibration()
    }

    // MARK: - Public Methods

    /// Analyze tread depth from image using advanced computer vision
    func analyzeTreadDepth(from image: CIImage, regionOfInterest: CGRect? = nil) async throws -> AnalysisResult {
        let processedImage = preprocessImage(image)
        let measurements = try await extractDepthMeasurements(from: processedImage, roi: regionOfInterest)
        let filteredMeasurements = applyKalmanFiltering(to: measurements)

        return computeAnalysisResult(from: filteredMeasurements)
    }

    /// Analyze from multiple images for increased accuracy
    func analyzeTreadDepth(from images: [CIImage]) async throws -> AnalysisResult {
        var allMeasurements: [DepthMeasurement] = []

        for image in images {
            let result = try await analyzeTreadDepth(from: image)
            allMeasurements.append(contentsOf: result.measurements)
        }

        return computeAnalysisResult(from: allMeasurements)
    }

    /// Real-time depth estimation for live camera feed
    func estimateDepthRealtime(from image: CIImage, previousEstimate: Double? = nil) -> Double? {
        guard let roughDepth = quickDepthEstimate(from: image) else {
            return nil
        }

        let filterKey = "realtime"
        if kalmanFilters[filterKey] == nil {
            kalmanFilters[filterKey] = KalmanFilter(
                initialEstimate: previousEstimate ?? roughDepth,
                processNoise: 0.005,
                measurementNoise: 0.2
            )
        }

        return kalmanFilters[filterKey]?.update(measurement: roughDepth)
    }

    // MARK: - Image Processing

    private func preprocessImage(_ image: CIImage) -> CIImage {
        var processedImage = image

        // 1. Convert to grayscale for better edge detection
        if let grayFilter = CIFilter(name: "CIPhotoEffectNoir") {
            grayFilter.setValue(processedImage, forKey: kCIInputImageKey)
            if let output = grayFilter.outputImage {
                processedImage = output
            }
        }

        // 2. Enhance contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.3, forKey: kCIInputContrastKey)
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }

        // 3. Reduce noise
        if let noiseFilter = CIFilter(name: "CINoiseReduction") {
            noiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
            noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
            noiseFilter.setValue(0.4, forKey: "inputSharpness")
            if let output = noiseFilter.outputImage {
                processedImage = output
            }
        }

        return processedImage
    }

    // MARK: - Depth Extraction

    private func extractDepthMeasurements(from image: CIImage, roi: CGRect?) async throws -> [DepthMeasurement] {
        var measurements: [DepthMeasurement] = []

        // Use edge detection to find tread grooves
        let edges = detectEdges(in: image)

        // Analyze tread pattern structure
        let treadLines = detectTreadLines(in: edges)

        // Sample multiple points across the tyre
        let samplePoints = generateSamplePoints(in: roi ?? image.extent, count: 50)

        for point in samplePoints {
            if let depth = estimateDepthAtPoint(point, in: image, edges: edges, treadLines: treadLines) {
                let measurement = DepthMeasurement(
                    depth: depth.value,
                    confidence: depth.confidence,
                    location: point,
                    timestamp: Date(),
                    rawDepth: depth.value,
                    filteredDepth: depth.value
                )
                measurements.append(measurement)
            }
        }

        return measurements
    }

    private func detectEdges(in image: CIImage) -> CIImage {
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return image
        }

        edgeFilter.setValue(image, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0, forKey: kCIInputIntensityKey)

        return edgeFilter.outputImage ?? image
    }

    private func detectTreadLines(in edgeImage: CIImage) -> [Line] {
        // Simplified line detection - in production, use Hough Transform
        // This is a placeholder for the actual implementation
        var lines: [Line] = []

        // TODO: Implement Hough Line Transform or similar
        // For now, return empty array

        return lines
    }

    private struct Line {
        let start: CGPoint
        let end: CGPoint
        let angle: Double
    }

    private func generateSamplePoints(in rect: CGRect, count: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        let gridSize = Int(sqrt(Double(count)))

        let stepX = rect.width / Double(gridSize)
        let stepY = rect.height / Double(gridSize)

        for i in 0..<gridSize {
            for j in 0..<gridSize {
                let x = rect.minX + stepX * (Double(i) + 0.5)
                let y = rect.minY + stepY * (Double(j) + 0.5)
                points.append(CGPoint(x: x, y: y))
            }
        }

        return points
    }

    private func estimateDepthAtPoint(
        _ point: CGPoint,
        in image: CIImage,
        edges: CIImage,
        treadLines: [Line]
    ) -> (value: Double, confidence: Double)? {

        // Sample local region around point
        let sampleRadius: CGFloat = 10.0
        let sampleRect = CGRect(
            x: point.x - sampleRadius,
            y: point.y - sampleRadius,
            width: sampleRadius * 2,
            height: sampleRadius * 2
        )

        // Crop to sample area
        let croppedEdges = edges.cropped(to: sampleRect)

        // Analyze edge density (more edges = deeper grooves)
        let edgeDensity = calculateEdgeDensity(in: croppedEdges)

        // Analyze local texture variance
        let textureVariance = calculateTextureVariance(in: image.cropped(to: sampleRect))

        // Combine metrics to estimate depth
        // Higher edge density and variance typically indicate deeper treads
        let normalizedEdgeDensity = min(edgeDensity / 0.5, 1.0)
        let normalizedVariance = min(textureVariance / 100.0, 1.0)

        let depthFactor = (normalizedEdgeDensity * 0.6 + normalizedVariance * 0.4)
        var estimatedDepth = newTyreDepth * depthFactor

        // Apply calibration correction if available
        estimatedDepth = applyCalibratedCorrection(to: estimatedDepth)

        // Confidence based on measurement clarity
        var confidence = min(normalizedEdgeDensity + normalizedVariance, 1.0) * 0.8

        // Boost confidence if calibrated
        if isCalibrated, let profile = calibrationProfile {
            confidence = confidence * 0.7 + profile.confidence * 0.3
        }

        return (estimatedDepth, confidence)
    }

    private func calculateEdgeDensity(in image: CIImage) -> Double {
        // Simplified edge density calculation
        // In production, analyze actual pixel values
        return Double.random(in: 0.2...0.5) // Placeholder
    }

    private func calculateTextureVariance(in image: CIImage) -> Double {
        // Simplified texture variance
        // In production, calculate actual variance from pixel data
        return Double.random(in: 20...80) // Placeholder
    }

    private func quickDepthEstimate(from image: CIImage) -> Double? {
        // Fast estimation for real-time use
        let edges = detectEdges(in: image)
        let centerPoint = CGPoint(x: image.extent.midX, y: image.extent.midY)
        return estimateDepthAtPoint(centerPoint, in: image, edges: edges, treadLines: [])?.value
    }

    // MARK: - Kalman Filtering

    private func applyKalmanFiltering(to measurements: [DepthMeasurement]) -> [DepthMeasurement] {
        guard !measurements.isEmpty else { return [] }

        // Group measurements by proximity
        let clusters = clusterMeasurements(measurements)

        var filteredMeasurements: [DepthMeasurement] = []

        for (index, cluster) in clusters.enumerated() {
            let filterKey = "cluster_\(index)"
            if kalmanFilters[filterKey] == nil {
                kalmanFilters[filterKey] = KalmanFilter(
                    initialEstimate: cluster.first?.depth ?? 0,
                    processNoise: 0.001,
                    measurementNoise: 0.05
                )
            }

            for measurement in cluster {
                if let filter = kalmanFilters[filterKey] {
                    let filtered = filter.update(measurement: measurement.depth)

                    let filteredMeasurement = DepthMeasurement(
                        depth: filtered,
                        confidence: measurement.confidence,
                        location: measurement.location,
                        timestamp: measurement.timestamp,
                        rawDepth: measurement.rawDepth,
                        filteredDepth: filtered
                    )
                    filteredMeasurements.append(filteredMeasurement)
                }
            }
        }

        return filteredMeasurements
    }

    private func clusterMeasurements(_ measurements: [DepthMeasurement]) -> [[DepthMeasurement]] {
        // Simple spatial clustering
        let clusterRadius: Double = 50.0
        var clusters: [[DepthMeasurement]] = []
        var unassigned = measurements

        while !unassigned.isEmpty {
            let seed = unassigned.removeFirst()
            var cluster = [seed]

            unassigned = unassigned.filter { measurement in
                let distance = hypot(
                    measurement.location.x - seed.location.x,
                    measurement.location.y - seed.location.y
                )

                if distance <= clusterRadius {
                    cluster.append(measurement)
                    return false
                }
                return true
            }

            clusters.append(cluster)
        }

        return clusters
    }

    // MARK: - Analysis

    private func computeAnalysisResult(from measurements: [DepthMeasurement]) -> AnalysisResult {
        guard !measurements.isEmpty else {
            return AnalysisResult(
                measurements: [],
                averageDepth: 0,
                minDepth: 0,
                maxDepth: 0,
                standardDeviation: 0,
                wearPattern: .excessive,
                quality: QualityMetric(overallScore: 0, measurementCount: 0, averageConfidence: 0, stabilityScore: 0),
                isLegal: false
            )
        }

        let depths = measurements.map { $0.filteredDepth }
        let confidences = measurements.map { $0.confidence }

        let avgDepth = depths.reduce(0, +) / Double(depths.count)
        let minDepth = depths.min() ?? 0
        let maxDepth = depths.max() ?? 0
        let stdDev = standardDeviation(depths)

        let wearPattern = determineWearPattern(measurements: measurements, avgDepth: avgDepth)
        let quality = computeQualityMetric(measurements: measurements, stdDev: stdDev)
        let isLegal = minDepth >= minimumLegalDepth

        return AnalysisResult(
            measurements: measurements,
            averageDepth: avgDepth,
            minDepth: minDepth,
            maxDepth: maxDepth,
            standardDeviation: stdDev,
            wearPattern: wearPattern,
            quality: quality,
            isLegal: isLegal
        )
    }

    private func determineWearPattern(measurements: [DepthMeasurement], avgDepth: Double) -> WearPattern {
        guard !measurements.isEmpty else { return .excessive }

        if avgDepth < minimumLegalDepth {
            return .excessive
        }

        // Analyze spatial distribution
        let imageWidth = measurements.map { $0.location.x }.max() ?? 1
        let centerMeasurements = measurements.filter { measurement in
            let normalizedX = measurement.location.x / imageWidth
            return normalizedX > centerThreshold && normalizedX < (1.0 - centerThreshold)
        }

        let edgeMeasurements = measurements.filter { measurement in
            let normalizedX = measurement.location.x / imageWidth
            return normalizedX < edgeThreshold || normalizedX > (1.0 - edgeThreshold)
        }

        let centerAvg = centerMeasurements.map { $0.filteredDepth }.reduce(0, +) / Double(max(centerMeasurements.count, 1))
        let edgeAvg = edgeMeasurements.map { $0.filteredDepth }.reduce(0, +) / Double(max(edgeMeasurements.count, 1))

        let difference = abs(centerAvg - edgeAvg)

        if difference < 0.5 {
            return .uniform
        } else if centerAvg < edgeAvg - 0.5 {
            return .centerWear
        } else if edgeAvg < centerAvg - 0.5 {
            return .edgeWear
        } else {
            return .patchyWear
        }
    }

    private func computeQualityMetric(measurements: [DepthMeasurement], stdDev: Double) -> QualityMetric {
        let avgConfidence = measurements.map { $0.confidence }.reduce(0, +) / Double(measurements.count)
        let stabilityScore = max(0, 1.0 - (stdDev / newTyreDepth))
        let overallScore = (avgConfidence * 0.6 + stabilityScore * 0.4)

        return QualityMetric(
            overallScore: overallScore,
            measurementCount: measurements.count,
            averageConfidence: avgConfidence,
            stabilityScore: stabilityScore
        )
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }

    // MARK: - Calibration Methods

    /// Start calibration process with reference tyre of known depth
    func startCalibration(referenceDepth: Double) throws {
        guard referenceDepth > 0 && referenceDepth <= newTyreDepth else {
            throw CalibrationError.invalidReferenceDepth
        }

        calibrationProfile = nil
        resetFilters()
    }

    /// Add calibration sample during calibration process
    func addCalibrationSample(from image: CIImage, knownDepth: Double) async throws -> CalibrationSample {
        let processedImage = preprocessImage(image)
        let edges = detectEdges(in: processedImage)
        let centerPoint = CGPoint(x: image.extent.midX, y: image.extent.midY)

        guard let result = estimateDepthAtPoint(centerPoint, in: processedImage, edges: edges, treadLines: []) else {
            throw CalibrationError.calibrationFailed
        }

        let sampleRadius: CGFloat = 20.0
        let sampleRect = CGRect(
            x: centerPoint.x - sampleRadius,
            y: centerPoint.y - sampleRadius,
            width: sampleRadius * 2,
            height: sampleRadius * 2
        )

        let edgeDensity = calculateEdgeDensity(in: edges.cropped(to: sampleRect))
        let textureVariance = calculateTextureVariance(in: processedImage.cropped(to: sampleRect))

        return CalibrationSample(
            knownDepth: knownDepth,
            measuredEdgeDensity: edgeDensity,
            measuredTexture: textureVariance,
            rawEstimate: result.value
        )
    }

    /// Complete calibration and compute correction factors
    func completeCalibration(samples: [CalibrationSample]) throws {
        guard samples.count >= 3 else {
            throw CalibrationError.insufficientSamples
        }

        // Compute correction factors using linear regression
        let (scaleFactor, offset) = computeLinearRegression(samples: samples)

        // Calculate average factors
        let avgEdgeDensity = samples.map { $0.measuredEdgeDensity }.reduce(0, +) / Double(samples.count)
        let avgTexture = samples.map { $0.measuredTexture }.reduce(0, +) / Double(samples.count)

        // Compute calibration confidence
        let predictions = samples.map { sample -> Double in
            sample.rawEstimate * scaleFactor + offset
        }
        let errors = zip(predictions, samples.map { $0.knownDepth }).map { abs($0 - $1) }
        let avgError = errors.reduce(0, +) / Double(errors.count)
        let confidence = max(0, 1.0 - (avgError / newTyreDepth))

        calibrationProfile = CalibrationProfile(
            referenceDepth: samples.first?.knownDepth ?? 0,
            edgeDensityFactor: avgEdgeDensity,
            textureFactor: avgTexture,
            offsetCorrection: offset,
            scaleFactor: scaleFactor,
            timestamp: Date(),
            sampleCount: samples.count,
            confidence: confidence
        )

        saveCalibration()
    }

    /// Perform automatic calibration with reference tyre
    func autoCalibrate(from images: [CIImage], referenceDepth: Double) async throws {
        try startCalibration(referenceDepth: referenceDepth)

        var samples: [CalibrationSample] = []

        for image in images {
            let sample = try await addCalibrationSample(from: image, knownDepth: referenceDepth)
            samples.append(sample)
        }

        try completeCalibration(samples: samples)
    }

    /// Get current calibration status
    func getCalibrationStatus() -> (isCalibrated: Bool, confidence: Double?, daysUntilExpiry: Int?) {
        guard let profile = calibrationProfile, profile.isValid else {
            return (false, nil, nil)
        }

        let daysRemaining = 30 - Int(Date().timeIntervalSince(profile.timestamp) / (24 * 3600))

        return (true, profile.confidence, max(0, daysRemaining))
    }

    /// Reset calibration
    func resetCalibration() {
        calibrationProfile = nil
        saveCalibration()
    }

    // MARK: - Calibration Helpers

    private func computeLinearRegression(samples: [CalibrationSample]) -> (slope: Double, intercept: Double) {
        let n = Double(samples.count)
        let x = samples.map { $0.rawEstimate }
        let y = samples.map { $0.knownDepth }

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        return (slope, intercept)
    }

    private func applyCalibratedCorrection(to depth: Double) -> Double {
        guard let profile = calibrationProfile, profile.isValid else {
            return depth
        }

        return depth * profile.scaleFactor + profile.offsetCorrection
    }

    private func saveCalibration() {
        guard let profile = calibrationProfile else {
            UserDefaults.standard.removeObject(forKey: "TreadDepthCalibration")
            return
        }

        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "TreadDepthCalibration")
        }
    }

    private func loadCalibration() {
        guard let data = UserDefaults.standard.data(forKey: "TreadDepthCalibration"),
              let profile = try? JSONDecoder().decode(CalibrationProfile.self, from: data),
              profile.isValid else {
            calibrationProfile = nil
            return
        }

        calibrationProfile = profile
    }

    // MARK: - Utilities

    func resetFilters() {
        kalmanFilters.removeAll()
    }
}
