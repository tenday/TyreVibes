//
//  RemainingLifeCalculator.swift
//  TyreVibes
//
//  Advanced remaining life calculation with predictive algorithms
//

import Foundation

class RemainingLifeCalculator {

    // MARK: - Constants
    private let legalMinimumDepth: Double = 1.6  // mm
    private let newTyreDepth: Double = 8.0  // mm (typical)
    private let averageWearRatePerKm: Double = 0.00015  // mm per km (typical)

    // MARK: - Life Estimate Calculation

    /// Calculate remaining life estimate from depth analysis
    func calculateRemainingLife(
        from depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        vehicleInfo: VehicleInfo?,
        historicalData: [HistoricalDataPoint]? = nil
    ) -> RemainingLifeEstimate {

        // Choose calculation method based on available data
        let method: RemainingLifeEstimate.CalculationMethod
        let estimatedKm: Double
        let confidence: Double

        if let historical = historicalData, historical.count >= 2 {
            // Use historical data for prediction
            let result = calculateFromHistoricalData(historical, currentDepth: depthAnalysis.average)
            method = .historical
            estimatedKm = result.kilometers
            confidence = result.confidence
        } else if depthAnalysis.measurements.count > 20 {
            // Use exponential model for detailed data
            let result = calculateExponentialModel(depthAnalysis: depthAnalysis, wearAnalysis: wearAnalysis)
            method = .exponential
            estimatedKm = result.kilometers
            confidence = result.confidence
        } else {
            // Fallback to linear regression
            let result = calculateLinearModel(depthAnalysis: depthAnalysis, wearAnalysis: wearAnalysis)
            method = .linear
            estimatedKm = result.kilometers
            confidence = result.confidence
        }

        // Calculate estimated months
        let estimatedMonths = estimateMonths(from: estimatedKm, wearAnalysis: wearAnalysis)

        // Identify life factors
        let factors = identifyLifeFactors(
            depthAnalysis: depthAnalysis,
            wearAnalysis: wearAnalysis,
            vehicleInfo: vehicleInfo
        )

        // Generate projection curve
        let projections = generateDepthProjections(
            currentDepth: depthAnalysis.average,
            estimatedKm: estimatedKm,
            wearAnalysis: wearAnalysis
        )

        return RemainingLifeEstimate(
            estimatedKilometers: max(0, estimatedKm),
            estimatedMonths: max(0, estimatedMonths),
            confidence: confidence,
            calculationMethod: method,
            factors: factors,
            projectedDepthCurve: projections
        )
    }

    // MARK: - Calculation Methods

    private func calculateLinearModel(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis
    ) -> (kilometers: Double, confidence: Double) {

        let currentDepth = depthAnalysis.average
        let depthRemaining = currentDepth - legalMinimumDepth

        guard depthRemaining > 0 else {
            return (0, 1.0)
        }

        // Adjust wear rate based on wear pattern
        var wearRate = averageWearRatePerKm

        switch wearAnalysis.pattern {
        case .uniform:
            wearRate *= 1.0
        case .centerWear:
            wearRate *= 1.3  // Faster wear
        case .edgeWear:
            wearRate *= 1.4
        case .innerEdgeWear, .outerEdgeWear:
            wearRate *= 1.35
        case .patchyWear:
            wearRate *= 1.5
        case .cuppingWear:
            wearRate *= 1.6
        case .feathering:
            wearRate *= 1.4
        case .excessive:
            wearRate *= 2.0
        }

        // Adjust for wear severity
        switch wearAnalysis.severity {
        case .minimal:
            wearRate *= 0.9
        case .moderate:
            wearRate *= 1.0
        case .significant:
            wearRate *= 1.2
        case .severe:
            wearRate *= 1.4
        case .critical:
            wearRate *= 1.6
        }

        let estimatedKm = depthRemaining / wearRate

        // Confidence decreases with more uneven wear
        let confidence = 1.0 - (wearAnalysis.unevenWearIndex * 0.5)

        return (estimatedKm, max(0.3, min(confidence, 1.0)))
    }

    private func calculateExponentialModel(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis
    ) -> (kilometers: Double, confidence: Double) {

        let currentDepth = depthAnalysis.average
        let depthRemaining = currentDepth - legalMinimumDepth

        guard depthRemaining > 0 else {
            return (0, 1.0)
        }

        // Exponential wear model: depth(t) = initial * e^(-k*t)
        // Solve for t when depth = legal minimum

        let depthRatio = legalMinimumDepth / currentDepth
        let k = 0.00005  // Decay constant (typical)

        // Adjust k based on wear pattern
        var adjustedK = k

        switch wearAnalysis.severity {
        case .minimal:
            adjustedK *= 0.8
        case .moderate:
            adjustedK *= 1.0
        case .significant:
            adjustedK *= 1.3
        case .severe:
            adjustedK *= 1.6
        case .critical:
            adjustedK *= 2.0
        }

        let estimatedKm = -log(depthRatio) / adjustedK

        let confidence = 0.75 - (wearAnalysis.unevenWearIndex * 0.3)

        return (estimatedKm, max(0.4, min(confidence, 1.0)))
    }

    private func calculateFromHistoricalData(
        _ historicalData: [HistoricalDataPoint],
        currentDepth: Double
    ) -> (kilometers: Double, confidence: Double) {

        guard historicalData.count >= 2 else {
            return (0, 0.3)
        }

        // Sort by timestamp
        let sorted = historicalData.sorted { $0.timestamp < $1.timestamp }

        // Calculate wear rate from historical data
        var wearRates: [Double] = []

        for i in 1..<sorted.count {
            let timeDiff = sorted[i].timestamp.timeIntervalSince(sorted[i-1].timestamp)
            let kmDiff = sorted[i].kilometers - sorted[i-1].kilometers
            let depthDiff = sorted[i-1].depth - sorted[i].depth  // Depth decreases over time

            if kmDiff > 0 && depthDiff > 0 {
                let rate = depthDiff / kmDiff
                wearRates.append(rate)
            }
        }

        guard !wearRates.isEmpty else {
            return (0, 0.3)
        }

        // Average wear rate
        let avgWearRate = wearRates.reduce(0, +) / Double(wearRates.count)

        // Calculate standard deviation for confidence
        let mean = avgWearRate
        let variance = wearRates.map { pow($0 - mean, 2) }.reduce(0, +) / Double(wearRates.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = stdDev / mean

        let depthRemaining = currentDepth - legalMinimumDepth
        let estimatedKm = depthRemaining / avgWearRate

        // Confidence based on data consistency
        let confidence = max(0.5, 1.0 - coefficientOfVariation)

        return (estimatedKm, min(confidence, 0.95))
    }

    // MARK: - Helper Methods

    private func estimateMonths(from kilometers: Double, wearAnalysis: WearAnalysis) -> Int {
        // Assume average driving of 15,000 km/year
        var kmPerMonth = 15000.0 / 12.0

        // Adjust for driving patterns (if we had that data)
        // For now, use standard value

        let months = kilometers / kmPerMonth
        return Int(months.rounded())
    }

    private func identifyLifeFactors(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        vehicleInfo: VehicleInfo?
    ) -> [LifeFactor] {

        var factors: [LifeFactor] = []

        // Wear pattern factor
        switch wearAnalysis.pattern {
        case .uniform:
            factors.append(LifeFactor(
                name: "Usura Uniforme",
                impact: 0.15,
                description: "L'usura uniforme indica buone pratiche di manutenzione"
            ))
        case .centerWear:
            factors.append(LifeFactor(
                name: "Usura Centrale",
                impact: -0.25,
                description: "Sovra-gonfiaggio riduce la vita del pneumatico"
            ))
        case .edgeWear, .innerEdgeWear, .outerEdgeWear:
            factors.append(LifeFactor(
                name: "Usura Laterale",
                impact: -0.30,
                description: "Sotto-gonfiaggio o disallineamento accelera l'usura"
            ))
        case .patchyWear:
            factors.append(LifeFactor(
                name: "Usura Irregolare",
                impact: -0.40,
                description: "Problemi di sospensioni riducono significativamente la vita"
            ))
        case .cuppingWear:
            factors.append(LifeFactor(
                name: "Usura a Coppa",
                impact: -0.50,
                description: "Ammortizzatori difettosi causano usura prematura"
            ))
        case .feathering:
            factors.append(LifeFactor(
                name: "Usura a Piuma",
                impact: -0.35,
                description: "Convergenza errata riduce la durata"
            ))
        case .excessive:
            factors.append(LifeFactor(
                name: "Usura Eccessiva",
                impact: -0.60,
                description: "Usura eccessiva richiede sostituzione immediata"
            ))
        }

        // Depth uniformity factor
        if depthAnalysis.standardDeviation < 0.5 {
            factors.append(LifeFactor(
                name: "Profondità Uniforme",
                impact: 0.10,
                description: "Variazione minima della profondità è positiva"
            ))
        } else if depthAnalysis.standardDeviation > 1.5 {
            factors.append(LifeFactor(
                name: "Profondità Irregolare",
                impact: -0.20,
                description: "Grande variazione indica problemi di usura"
            ))
        }

        // Current depth factor
        if depthAnalysis.average > 6.0 {
            factors.append(LifeFactor(
                name: "Battistrada Profondo",
                impact: 0.20,
                description: "Profondità elevata garantisce lunga durata residua"
            ))
        } else if depthAnalysis.average < 3.0 {
            factors.append(LifeFactor(
                name: "Battistrada Ridotto",
                impact: -0.15,
                description: "Profondità limitata richiede attenzione"
            ))
        }

        // Legal compliance factor
        switch depthAnalysis.legalStatus {
        case .legal:
            factors.append(LifeFactor(
                name: "Conformità Legale",
                impact: 0.05,
                description: "Pneumatico conforme ai limiti di legge"
            ))
        case .nearLimit:
            factors.append(LifeFactor(
                name: "Vicino al Limite",
                impact: -0.10,
                description: "Prossimo al limite legale, sostituzione imminente"
            ))
        case .warning:
            factors.append(LifeFactor(
                name: "Attenzione",
                impact: -0.20,
                description: "Profondità sotto soglia di sicurezza consigliata"
            ))
        case .illegal:
            factors.append(LifeFactor(
                name: "Non Conforme",
                impact: -1.0,
                description: "Sostituzione immediata obbligatoria"
            ))
        }

        return factors
    }

    private func generateDepthProjections(
        currentDepth: Double,
        estimatedKm: Double,
        wearAnalysis: WearAnalysis
    ) -> [DepthProjection] {

        var projections: [DepthProjection] = []

        // Current state
        projections.append(DepthProjection(
            kilometersFromNow: 0,
            projectedDepth: currentDepth,
            confidence: 1.0
        ))

        // Project at intervals
        let intervals = [1000, 2500, 5000, 10000, 15000, 20000, estimatedKm]

        for km in intervals where km <= estimatedKm {
            let wearRate = (currentDepth - legalMinimumDepth) / estimatedKm
            let projectedDepth = currentDepth - (wearRate * km)

            // Confidence decreases with projection distance
            let confidenceLoss = (km / estimatedKm) * 0.5
            let confidence = max(0.3, 1.0 - confidenceLoss)

            projections.append(DepthProjection(
                kilometersFromNow: km,
                projectedDepth: max(legalMinimumDepth, projectedDepth),
                confidence: confidence
            ))
        }

        return projections
    }

    // MARK: - Historical Data

    struct HistoricalDataPoint {
        let timestamp: Date
        let depth: Double
        let kilometers: Double
    }
}
