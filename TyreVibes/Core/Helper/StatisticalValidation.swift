//
//  StatisticalValidation.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//  Advanced statistical validation and confidence estimation
//

import Foundation
import simd
import Accelerate

// MARK: - Bootstrap Validation

/// Validazione Bootstrap per stimare incertezza e intervalli di confidenza
class BootstrapValidation {
    /// Esegue bootstrap resampling
    /// - Parameters:
    ///   - data: Dati originali
    ///   - numBootstraps: Numero di campioni bootstrap (default 1000)
    ///   - confidence: Livello di confidenza (default 0.95 = 95%)
    /// - Returns: Risultato bootstrap con intervalli di confidenza
    func bootstrap(data: [Double],
                  numBootstraps: Int = 1000,
                  confidence: Double = 0.95) -> BootstrapResult {
        guard !data.isEmpty else {
            return BootstrapResult(
                mean: 0,
                median: 0,
                standardError: 0,
                confidenceInterval: (0, 0),
                bootstrapDistribution: []
            )
        }

        var bootstrapMeans: [Double] = []
        bootstrapMeans.reserveCapacity(numBootstraps)

        // Genera campioni bootstrap
        for _ in 0..<numBootstraps {
            let sample = resampleWithReplacement(data)
            let mean = sample.reduce(0, +) / Double(sample.count)
            bootstrapMeans.append(mean)
        }

        // Calcola statistiche
        let originalMean = data.mean
        let originalMedian = data.median
        let standardError = bootstrapMeans.standardDeviation

        // Calcola intervallo di confidenza (metodo percentile)
        let alpha = 1.0 - confidence
        let lowerPercentile = alpha / 2.0
        let upperPercentile = 1.0 - alpha / 2.0

        let sortedMeans = bootstrapMeans.sorted()
        let lowerIndex = Int(lowerPercentile * Double(sortedMeans.count))
        let upperIndex = Int(upperPercentile * Double(sortedMeans.count))

        let confidenceInterval = (
            sortedMeans[lowerIndex],
            sortedMeans[upperIndex]
        )

        return BootstrapResult(
            mean: originalMean,
            median: originalMedian,
            standardError: standardError,
            confidenceInterval: confidenceInterval,
            bootstrapDistribution: sortedMeans
        )
    }

    /// Resampling con replacement
    private func resampleWithReplacement(_ data: [Double]) -> [Double] {
        return (0..<data.count).map { _ in
            data[Int.random(in: 0..<data.count)]
        }
    }

    struct BootstrapResult {
        let mean: Double
        let median: Double
        let standardError: Double
        let confidenceInterval: (lower: Double, upper: Double)
        let bootstrapDistribution: [Double]

        /// Ampiezza intervallo di confidenza
        var intervalWidth: Double {
            return confidenceInterval.upper - confidenceInterval.lower
        }

        /// Coefficiente di variazione
        var coefficientOfVariation: Double {
            guard mean != 0 else { return 0 }
            return standardError / abs(mean)
        }
    }
}

// MARK: - Confidence Map Generator

/// Genera mappa 2D di confidenza per visualizzazione heatmap
class ConfidenceMapGenerator {
    struct ConfidenceMap {
        let width: Int
        let height: Int
        var values: [[Double]]  // Matrice width x height con confidenza 0-1

        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            self.values = [[Double]](
                repeating: [Double](repeating: 0, count: height),
                count: width
            )
        }

        /// Ottieni valore in posizione normalizzata (0-1, 0-1)
        func getValue(x: Double, y: Double) -> Double {
            let xi = Int(x * Double(width - 1))
            let yi = Int(y * Double(height - 1))

            guard xi >= 0 && xi < width && yi >= 0 && yi < height else {
                return 0
            }

            return values[xi][yi]
        }

        /// Imposta valore in posizione normalizzata
        mutating func setValue(x: Double, y: Double, value: Double) {
            let xi = Int(x * Double(width - 1))
            let yi = Int(y * Double(height - 1))

            guard xi >= 0 && xi < width && yi >= 0 && yi < height else {
                return
            }

            values[xi][yi] = value
        }

        /// Media globale della confidenza
        var averageConfidence: Double {
            var sum = 0.0
            var count = 0

            for row in values {
                for value in row {
                    sum += value
                    count += 1
                }
            }

            return count > 0 ? sum / Double(count) : 0
        }

        /// Statistiche per zona
        func zoneStatistics(zone: TreadZone) -> ZoneStatistics {
            // Definisci bounds zona (normalizzati 0-1)
            let (xRange, yRange) = zoneBounds(for: zone)

            var zoneValues: [Double] = []

            for x in stride(from: xRange.lowerBound, to: xRange.upperBound, by: 0.01) {
                for y in stride(from: yRange.lowerBound, to: yRange.upperBound, by: 0.01) {
                    zoneValues.append(getValue(x: x, y: y))
                }
            }

            return ZoneStatistics(
                zone: zone,
                mean: zoneValues.mean,
                min: zoneValues.min() ?? 0,
                max: zoneValues.max() ?? 0,
                stdDev: zoneValues.standardDeviation
            )
        }

        private func zoneBounds(for zone: TreadZone) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
            let y = 0.0...1.0  // Tutta l'altezza

            switch zone {
            case .innerEdge:
                return (0.0...0.166, y)
            case .shoulderLeft:
                return (0.166...0.333, y)
            case .centerLeft:
                return (0.333...0.5, y)
            case .centerRight:
                return (0.5...0.666, y)
            case .shoulderRight:
                return (0.666...0.833, y)
            case .outerEdge:
                return (0.833...1.0, y)
            }
        }
    }

    struct ZoneStatistics {
        let zone: TreadZone
        let mean: Double
        let min: Double
        let max: Double
        let stdDev: Double
    }

    /// Genera confidence map da punti 3D
    /// - Parameters:
    ///   - points: Punti 3D con confidence
    ///   - confidences: Confidence per ogni punto (0-1)
    ///   - width: Larghezza mappa
    ///   - height: Altezza mappa
    /// - Returns: Confidence map 2D
    func generateMap(points: [simd_float3],
                    confidences: [Float],
                    width: Int = 100,
                    height: Int = 100) -> ConfidenceMap {
        guard points.count == confidences.count && !points.isEmpty else {
            return ConfidenceMap(width: width, height: height)
        }

        var map = ConfidenceMap(width: width, height: height)

        // Trova bounds dei punti
        let xValues = points.map { $0.x }
        let yValues = points.map { $0.y }

        guard let minX = xValues.min(), let maxX = xValues.max(),
              let minY = yValues.min(), let maxY = yValues.max() else {
            return map
        }

        let xRange = maxX - minX
        let yRange = maxY - minY

        guard xRange > 0 && yRange > 0 else { return map }

        // Accumula confidence in celle
        var cellCounts = [[Int]](repeating: [Int](repeating: 0, count: height), count: width)

        for (point, confidence) in zip(points, confidences) {
            // Normalizza coordinate
            let nx = Double((point.x - minX) / xRange)
            let ny = Double((point.y - minY) / yRange)

            let xi = Int(nx * Double(width - 1))
            let yi = Int(ny * Double(height - 1))

            guard xi >= 0 && xi < width && yi >= 0 && yi < height else { continue }

            // Accumula confidence
            map.values[xi][yi] += Double(confidence)
            cellCounts[xi][yi] += 1
        }

        // Media per cella
        for i in 0..<width {
            for j in 0..<height {
                if cellCounts[i][j] > 0 {
                    map.values[i][j] /= Double(cellCounts[i][j])
                }
            }
        }

        // Smooth map con filtro Gaussiano
        map = gaussianSmooth(map, sigma: 2.0)

        return map
    }

    /// Applica filtro Gaussiano per smoothing
    private func gaussianSmooth(_ map: ConfidenceMap, sigma: Double) -> ConfidenceMap {
        var smoothed = map

        let kernelSize = Int(ceil(3.0 * sigma))
        var kernel: [Double] = []

        // Genera kernel Gaussiano 1D
        for i in -kernelSize...kernelSize {
            let x = Double(i)
            let value = exp(-x * x / (2.0 * sigma * sigma))
            kernel.append(value)
        }

        // Normalizza kernel
        let sum = kernel.reduce(0, +)
        kernel = kernel.map { $0 / sum }

        // Convoluzione separabile (prima X, poi Y)
        // X direction
        for j in 0..<map.height {
            for i in 0..<map.width {
                var sum = 0.0

                for (k, weight) in kernel.enumerated() {
                    let offset = k - kernelSize
                    let xi = i + offset

                    if xi >= 0 && xi < map.width {
                        sum += map.values[xi][j] * weight
                    }
                }

                smoothed.values[i][j] = sum
            }
        }

        // Y direction
        var final = smoothed

        for i in 0..<map.width {
            for j in 0..<map.height {
                var sum = 0.0

                for (k, weight) in kernel.enumerated() {
                    let offset = k - kernelSize
                    let yj = j + offset

                    if yj >= 0 && yj < map.height {
                        sum += smoothed.values[i][yj] * weight
                    }
                }

                final.values[i][j] = sum
            }
        }

        return final
    }
}

// MARK: - Spatial Frequency Analysis

/// Analisi frequenza spaziale per rilevare pattern di usura
class SpatialFrequencyAnalysis {
    /// Esegue FFT 1D su profilo di profondità
    /// - Parameter depths: Array di profondità lungo una linea
    /// - Returns: Spettro di frequenze e pattern dominanti
    func analyzeProfile(_ depths: [Double]) -> FrequencySpectrum {
        guard !depths.isEmpty else {
            return FrequencySpectrum(
                frequencies: [],
                magnitudes: [],
                dominantFrequency: 0,
                dominantMagnitude: 0
            )
        }

        // Padding a potenza di 2
        let n = depths.count
        let nPadded = nextPowerOf2(n)
        var paddedDepths = depths + [Double](repeating: depths.mean, count: nPadded - n)

        // Rimuovi DC component (media)
        let mean = paddedDepths.mean
        paddedDepths = paddedDepths.map { $0 - mean }

        // Esegui FFT usando vDSP
        var realp = [Double](repeating: 0, count: nPadded / 2)
        var imagp = [Double](repeating: 0, count: nPadded / 2)
        var magnitudes = [Double](repeating: 0, count: nPadded / 2)
        let log2n = vDSP_Length(log2(Double(nPadded)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return FrequencySpectrum(frequencies: [], magnitudes: [], dominantFrequency: 0, dominantMagnitude: 0)
        }

        realp.withUnsafeMutableBufferPointer { realBuffer in
            imagp.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )

                paddedDepths.withUnsafeBufferPointer { bufferPointer in
                    let complexBuffer = UnsafePointer<DSPDoubleComplex>(OpaquePointer(bufferPointer.baseAddress))

                    vDSP_ctozD(complexBuffer!, 2, &splitComplex, 1, vDSP_Length(nPadded / 2))
                }

                vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Calcola magnitudini
                vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(nPadded / 2))
            }
        }

        vDSP_destroy_fftsetupD(fftSetup)

        // Converti in sqrt per ottenere magnitudine (non magnitudine al quadrato)
        magnitudes = magnitudes.map { sqrt($0) }

        // Genera frequenze
        let frequencies = (0..<magnitudes.count).map { Double($0) / Double(nPadded) }

        // Trova frequenza dominante (escludendo DC)
        var maxMag = 0.0
        var maxIdx = 0

        for i in 1..<magnitudes.count {
            if magnitudes[i] > maxMag {
                maxMag = magnitudes[i]
                maxIdx = i
            }
        }

        let dominantFreq = frequencies[maxIdx]

        return FrequencySpectrum(
            frequencies: frequencies,
            magnitudes: magnitudes,
            dominantFrequency: dominantFreq,
            dominantMagnitude: maxMag
        )
    }

    struct FrequencySpectrum {
        let frequencies: [Double]
        let magnitudes: [Double]
        let dominantFrequency: Double
        let dominantMagnitude: Double

        /// Peridicità dominante (inverso della frequenza)
        var dominantPeriod: Double {
            guard dominantFrequency > 0 else { return 0 }
            return 1.0 / dominantFrequency
        }

        /// Energia totale nello spettro
        var totalEnergy: Double {
            return magnitudes.reduce(0) { $0 + $1 * $1 }
        }

        /// Classifica pattern di usura
        var wearPattern: WearPattern {
            // Bassa frequenza dominante = usura graduale uniforme
            // Alta frequenza dominante = usura a bande/irregolare

            if dominantFrequency < 0.1 {
                return .uniform
            } else if dominantFrequency < 0.3 {
                return .gradual
            } else if dominantFrequency < 0.5 {
                return .periodic
            } else {
                return .irregular
            }
        }
    }

    enum WearPattern: String {
        case uniform = "Uniforme"
        case gradual = "Graduale"
        case periodic = "Periodica"
        case irregular = "Irregolare"

        var description: String {
            switch self {
            case .uniform:
                return "Usura uniforme su tutta la superficie"
            case .gradual:
                return "Usura graduale da un lato all'altro"
            case .periodic:
                return "Usura con pattern periodico (possibile problema allineamento)"
            case .irregular:
                return "Usura irregolare (possibile danneggiamento)"
            }
        }
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }
}

// MARK: - Goodness of Fit Tests

/// Test statistici per validare qualità fit
class GoodnessOfFitTests {
    /// Test Chi-quadrato per validare distribuzione
    /// - Parameters:
    ///   - observed: Frequenze osservate
    ///   - expected: Frequenze attese
    /// - Returns: Chi-quadrato statistic e p-value
    func chiSquareTest(observed: [Int], expected: [Double]) -> (chiSquare: Double, pValue: Double) {
        guard observed.count == expected.count && !observed.isEmpty else {
            return (0, 1)
        }

        var chiSquare = 0.0

        for i in 0..<observed.count {
            if expected[i] > 0 {
                let diff = Double(observed[i]) - expected[i]
                chiSquare += (diff * diff) / expected[i]
            }
        }

        // Gradi di libertà
        let df = observed.count - 1

        // p-value (approssimato)
        let pValue = chiSquarePValue(chiSquare: chiSquare, degreesOfFreedom: df)

        return (chiSquare, pValue)
    }

    /// Kolmogorov-Smirnov test per confrontare distribuzioni
    /// - Parameters:
    ///   - sample1: Primo campione
    ///   - sample2: Secondo campione
    /// - Returns: KS statistic e p-value
    func kolmogorovSmirnovTest(sample1: [Double], sample2: [Double]) -> (ks: Double, pValue: Double) {
        let sorted1 = sample1.sorted()
        let sorted2 = sample2.sorted()

        let n1 = sorted1.count
        let n2 = sorted2.count

        var maxDiff = 0.0
        var i1 = 0
        var i2 = 0

        while i1 < n1 && i2 < n2 {
            let cdf1 = Double(i1) / Double(n1)
            let cdf2 = Double(i2) / Double(n2)

            maxDiff = max(maxDiff, abs(cdf1 - cdf2))

            if sorted1[i1] < sorted2[i2] {
                i1 += 1
            } else {
                i2 += 1
            }
        }

        // Approximate p-value
        let n = Double(n1 * n2) / Double(n1 + n2)
        let lambda = (sqrt(n) + 0.12 + 0.11 / sqrt(n)) * maxDiff
        let pValue = 2.0 * exp(-2.0 * lambda * lambda)

        return (maxDiff, min(1.0, pValue))
    }

    /// Anderson-Darling test per normalità
    /// - Parameter data: Campione dati
    /// - Returns: AD statistic e interpretazione
    func andersonDarlingTest(data: [Double]) -> (ad: Double, isNormal: Bool) {
        guard data.count > 1 else { return (0, false) }

        let sorted = data.sorted()
        let n = Double(sorted.count)

        let mean = data.mean
        let stdDev = data.standardDeviation

        guard stdDev > 0 else { return (0, false) }

        // Standardizza
        let standardized = sorted.map { ($0 - mean) / stdDev }

        // Calcola AD statistic
        var sum = 0.0

        for i in 0..<sorted.count {
            let cdf = normalCDF(standardized[i])
            let cdfComplement = 1.0 - normalCDF(standardized[sorted.count - 1 - i])

            if cdf > 0 && cdfComplement > 0 {
                sum += Double(2 * i + 1) * (log(cdf) + log(cdfComplement))
            }
        }

        let ad = -n - sum / n

        // Critical value per α=0.05 è circa 0.752
        let isNormal = ad < 0.752

        return (ad, isNormal)
    }

    // MARK: - Helper Functions

    private func chiSquarePValue(chiSquare: Double, degreesOfFreedom: Int) -> Double {
        // Simplified p-value calculation
        // In produzione: usa incomplete gamma function

        if chiSquare < 0 { return 1.0 }

        let x = chiSquare / 2.0
        let k = Double(degreesOfFreedom) / 2.0

        // Approssimazione molto semplificata
        let approx = exp(-x) * pow(x, k - 1)

        return max(0, min(1, 1.0 - approx))
    }

    private func normalCDF(_ x: Double) -> Double {
        // Approssimazione CDF normale standard
        return 0.5 * (1.0 + erf(x / sqrt(2.0)))
    }
}
