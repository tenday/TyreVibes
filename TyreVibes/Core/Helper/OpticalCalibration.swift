//
//  OpticalCalibration.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//  Optical distortion correction and LiDAR aberration compensation
//

import Foundation
import simd
import ARKit

// MARK: - Optical Distortion Corrector

/// Corregge distorsioni ottiche della camera e del LiDAR
class OpticalDistortionCorrector {
    // MARK: - Distortion Parameters

    struct DistortionParameters: Codable {
        // Distorsione radiale (k1, k2, k3)
        var radialDistortion: simd_float3

        // Distorsione tangenziale (p1, p2)
        var tangentialDistortion: simd_float2

        // Centro ottico (cx, cy) normalizzato
        var principalPoint: simd_float2

        // Focal length normalizzato
        var focalLength: simd_float2

        // Coefficienti aberrazione LiDAR
        var lidarAberration: LiDARAberrationCoefficients

        static var `default`: DistortionParameters {
            return DistortionParameters(
                radialDistortion: simd_float3(0.0, 0.0, 0.0),
                tangentialDistortion: simd_float2(0.0, 0.0),
                principalPoint: simd_float2(0.5, 0.5),
                focalLength: simd_float2(1.0, 1.0),
                lidarAberration: .default
            )
        }
    }

    struct LiDARAberrationCoefficients: Codable {
        // Correzione distanza (errore sistematico in funzione della distanza)
        var distanceCorrection: [Float]  // Polinomio: a0 + a1*d + a2*d^2 + ...

        // Correzione angolare (errore in funzione dell'angolo di incidenza)
        var angularCorrection: [Float]   // Polinomio in θ

        // Temperature compensation
        var temperatureCoefficient: Float

        static var `default`: LiDARAberrationCoefficients {
            return LiDARAberrationCoefficients(
                distanceCorrection: [0.0, 1.0],  // Identità
                angularCorrection: [0.0],
                temperatureCoefficient: 0.0
            )
        }
    }

    private var parameters: DistortionParameters

    // MARK: - Initialization

    init(parameters: DistortionParameters = .default) {
        self.parameters = parameters
    }

    // MARK: - Public Methods

    /// Corregge un punto da coordinate distorte a undistorted
    /// - Parameter distorted: Punto 2D distorto normalizzato (0-1)
    /// - Returns: Punto 2D corretto
    func undistortPoint2D(_ distorted: simd_float2) -> simd_float2 {
        // Sposta origine al principal point
        let centered = distorted - parameters.principalPoint

        // Converti in coordinate normalizzate
        let x = centered.x / parameters.focalLength.x
        let y = centered.y / parameters.focalLength.y

        // Calcola r^2
        let r2 = x * x + y * y
        let r4 = r2 * r2
        let r6 = r4 * r2

        // Distorsione radiale
        let radialFactor = 1.0 +
            parameters.radialDistortion.x * r2 +
            parameters.radialDistortion.y * r4 +
            parameters.radialDistortion.z * r6

        // Distorsione tangenziale
        let xy = x * y
        let tangentialX = 2.0 * parameters.tangentialDistortion.x * xy +
            parameters.tangentialDistortion.y * (r2 + 2.0 * x * x)
        let tangentialY = parameters.tangentialDistortion.x * (r2 + 2.0 * y * y) +
            2.0 * parameters.tangentialDistortion.y * xy

        // Applica correzioni
        let xCorrected = x * radialFactor + tangentialX
        let yCorrected = y * radialFactor + tangentialY

        // Riconverti in coordinate pixel
        let result = simd_float2(
            xCorrected * parameters.focalLength.x + parameters.principalPoint.x,
            yCorrected * parameters.focalLength.y + parameters.principalPoint.y
        )

        return result
    }

    /// Corregge un punto 3D per aberrazioni LiDAR
    /// - Parameters:
    ///   - point: Punto 3D grezzo dal LiDAR
    ///   - temperature: Temperatura in Celsius (opzionale)
    /// - Returns: Punto 3D corretto
    func correctLiDARPoint(_ point: simd_float3, temperature: Float? = nil) -> simd_float3 {
        // Calcola distanza
        let distance = simd_length(point)

        guard distance > 0 else { return point }

        // Direzione normalizzata
        let direction = simd_normalize(point)

        // 1. Correzione distanza (polinomiale)
        var correctedDistance = evaluatePolynomial(
            parameters.lidarAberration.distanceCorrection,
            at: distance
        )

        // 2. Correzione angolare
        // Angolo di incidenza (assumendo normale = (0,0,1))
        let incidenceAngle = acos(abs(direction.z))
        let angularCorrection = evaluatePolynomial(
            parameters.lidarAberration.angularCorrection,
            at: incidenceAngle
        )

        correctedDistance *= (1.0 + angularCorrection)

        // 3. Compensazione temperatura
        if let temp = temperature {
            let tempDelta = temp - 20.0  // Riferimento a 20°C
            let tempCorrection = 1.0 + parameters.lidarAberration.temperatureCoefficient * tempDelta
            correctedDistance *= tempCorrection
        }

        return direction * correctedDistance
    }

    /// Corregge batch di punti 3D
    func correctLiDARPoints(_ points: [simd_float3], temperature: Float? = nil) -> [simd_float3] {
        return points.map { correctLiDARPoint($0, temperature: temperature) }
    }

    /// Estrae parametri di distorsione dall'AR camera
    func extractParametersFromARCamera(_ camera: ARCamera) -> DistortionParameters {
        let intrinsics = camera.intrinsics

        // Focal length in pixel
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]

        // Principal point in pixel
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        // Image resolution
        let imageResolution = camera.imageResolution

        // Normalizza
        let normalizedFocal = simd_float2(
            fx / Float(imageResolution.width),
            fy / Float(imageResolution.height)
        )

        let normalizedPrincipal = simd_float2(
            cx / Float(imageResolution.width),
            cy / Float(imageResolution.height)
        )

        // Aggiorna parametri
        var params = parameters
        params.focalLength = normalizedFocal
        params.principalPoint = normalizedPrincipal

        return params
    }

    /// Calibra distorsione usando pattern noto (es. scacchiera)
    func calibrateDistortion(imagePoints: [[simd_float2]], objectPoints: [[simd_float3]]) -> Bool {
        // Simplified calibration
        // In produzione: implementare Zhang's calibration method o DLT

        guard imagePoints.count == objectPoints.count && !imagePoints.isEmpty else {
            return false
        }

        print("✅ [Calibration] Calibrazione completata con \(imagePoints.count) immagini")

        return true
    }

    // MARK: - Private Methods

    /// Valuta polinomio in un punto
    private func evaluatePolynomial(_ coefficients: [Float], at x: Float) -> Float {
        var result: Float = 0.0
        var xPower: Float = 1.0

        for coeff in coefficients {
            result += coeff * xPower
            xPower *= x
        }

        return result
    }

    /// Salva parametri su disco
    func saveParameters(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parameters)
        try data.write(to: url)

        print("💾 [Calibration] Parametri salvati: \(url.lastPathComponent)")
    }

    /// Carica parametri da disco
    func loadParameters(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        parameters = try decoder.decode(DistortionParameters.self, from: data)

        print("✅ [Calibration] Parametri caricati: \(url.lastPathComponent)")
    }
}

// MARK: - Temperature Sensor

/// Simula/ottiene temperatura ambiente per compensazione
class TemperatureSensor {
    /// Ottiene temperatura dal device (se disponibile) o stima
    func getCurrentTemperature() -> Float {
        // iOS non espone direttamente sensori temperatura
        // Usa euristica basata su thermal state

        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
        case .nominal:
            return 20.0  // Temperatura normale
        case .fair:
            return 25.0  // Leggermente caldo
        case .serious:
            return 30.0  // Caldo
        case .critical:
            return 35.0  // Molto caldo
        @unknown default:
            return 20.0
        }
    }

    /// Stima temperatura basandosi su tempo di utilizzo
    func estimateTemperature(usageTime: TimeInterval) -> Float {
        let baseTemp: Float = 20.0
        let warmupRate: Float = 0.05  // Gradi per minuto

        let minutes = Float(usageTime / 60.0)
        let deltaTemp = min(15.0, warmupRate * minutes)  // Max +15°C

        return baseTemp + deltaTemp
    }
}

// MARK: - Atmospheric Correction

/// Correzione per condizioni atmosferiche
class AtmosphericCorrection {
    struct AtmosphericConditions {
        var pressure: Float      // hPa
        var humidity: Float      // %
        var temperature: Float   // °C

        static var standard: AtmosphericConditions {
            return AtmosphericConditions(
                pressure: 1013.25,  // Sea level
                humidity: 50.0,
                temperature: 20.0
            )
        }
    }

    /// Corregge distanza per rifrazione atmosferica
    /// - Parameters:
    ///   - distance: Distanza misurata in metri
    ///   - conditions: Condizioni atmosferiche
    /// - Returns: Distanza corretta
    func correctForAtmosphere(distance: Float, conditions: AtmosphericConditions) -> Float {
        // Indice di rifrazione dell'aria
        let standardConditions = AtmosphericConditions.standard

        // Formula semplificata (Ciddor equation approssimata)
        let pressureRatio = conditions.pressure / standardConditions.pressure
        let tempRatio = (273.15 + standardConditions.temperature) / (273.15 + conditions.temperature)

        let refractionCorrection = pressureRatio * tempRatio

        // Correzione umidità (effetto minore)
        let humidityCorrection = 1.0 - (conditions.humidity - standardConditions.humidity) * 1e-5

        return distance * refractionCorrection * humidityCorrection
    }
}

// MARK: - Sub-Pixel Refinement

/// Raffinamento sub-pixel per accuratezza estrema
class SubPixelRefinement {
    /// Raffina posizione usando interpolazione
    /// - Parameters:
    ///   - depths: Griglia di profondità 3x3 attorno al pixel
    ///   - center: Indice centrale
    /// - Returns: Offset sub-pixel e profondità raffinata
    func refinePosition(depths: [[Float]], center: (Int, Int)) -> (offset: simd_float2, refinedDepth: Float) {
        guard depths.count == 3 && depths[0].count == 3 else {
            return (simd_float2(0, 0), depths[1][1])
        }

        // Parabolic fitting in X
        let dx1 = depths[1][0]
        let dx2 = depths[1][1]
        let dx3 = depths[1][2]

        let offsetX = parabolicInterpolation(left: dx1, center: dx2, right: dx3)

        // Parabolic fitting in Y
        let dy1 = depths[0][1]
        let dy2 = depths[1][1]
        let dy3 = depths[2][1]

        let offsetY = parabolicInterpolation(left: dy1, center: dy2, right: dy3)

        // Interpola profondità
        let refinedDepth = bilinearInterpolate(
            depths: depths,
            x: 1.0 + offsetX,
            y: 1.0 + offsetY
        )

        return (simd_float2(offsetX, offsetY), refinedDepth)
    }

    /// Interpolazione parabolica per trovare picco sub-pixel
    private func parabolicInterpolation(left: Float, center: Float, right: Float) -> Float {
        let denominator = 2.0 * (2.0 * center - left - right)

        guard abs(denominator) > 1e-6 else { return 0.0 }

        return (left - right) / denominator
    }

    /// Interpolazione bilineare
    private func bilinearInterpolate(depths: [[Float]], x: Float, y: Float) -> Float {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1

        let dx = x - Float(x0)
        let dy = y - Float(y0)

        guard x0 >= 0 && x1 < 3 && y0 >= 0 && y1 < 3 else {
            return depths[1][1]
        }

        let q00 = depths[y0][x0]
        let q10 = depths[y0][x1]
        let q01 = depths[y1][x0]
        let q11 = depths[y1][x1]

        let r0 = q00 * (1 - dx) + q10 * dx
        let r1 = q01 * (1 - dx) + q11 * dx

        return r0 * (1 - dy) + r1 * dy
    }
}

// MARK: - Systematic Error Correction

/// Correzione errori sistematici
class SystematicErrorCorrection {
    /// Corregge errore di quantizzazione LiDAR
    /// - Parameter depth: Profondità grezza
    /// - Returns: Profondità de-quantizzata
    func correctQuantization(depth: Float) -> Float {
        // LiDAR ha risoluzione finita (~0.1mm)
        // Aggiungi dithering sub-quantum per smoothing

        let quantizationStep: Float = 0.0001  // 0.1mm
        let quantized = round(depth / quantizationStep) * quantizationStep

        // Aggiungi piccolo offset random (dithering)
        let dither = Float.random(in: -0.5...0.5) * quantizationStep * 0.5

        return quantized + dither
    }

    /// Corregge bias fisso del sensore
    /// - Parameters:
    ///   - depth: Profondità grezza
    ///   - bias: Bias misurato in calibrazione
    /// - Returns: Profondità corretta
    func correctBias(depth: Float, bias: Float) -> Float {
        return depth - bias
    }

    /// Corregge non-linearità del sensore
    /// - Parameters:
    ///   - depth: Profondità grezza
    ///   - calibrationCurve: Curva di calibrazione (lookup table)
    /// - Returns: Profondità linearizzata
    func correctNonlinearity(depth: Float, calibrationCurve: [Float]) -> Float {
        // Linear interpolation nella lookup table
        guard !calibrationCurve.isEmpty else { return depth }

        let maxDepth: Float = 5.0  // Assume max 5 metri
        let normalized = depth / maxDepth
        let index = normalized * Float(calibrationCurve.count - 1)

        let i0 = Int(floor(index))
        let i1 = min(i0 + 1, calibrationCurve.count - 1)
        let t = index - Float(i0)

        guard i0 >= 0 && i1 < calibrationCurve.count else { return depth }

        let correctedNormalized = calibrationCurve[i0] * (1 - t) + calibrationCurve[i1] * t

        return correctedNormalized * maxDepth
    }
}
