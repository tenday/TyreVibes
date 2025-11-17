//
//  TyreDetailViewModel.swift
//  TyreVibes
//
//  ViewModel per gestire i dati dinamici del dettaglio pneumatici
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TyreDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var treadDepthData: TreadDepthData?
    @Published var remainingLifePercentage: Double = 0.0
    @Published var remainingLifeEstimate: RemainingLifeEstimate?
    @Published var tireConditionData: TireConditionData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let tyre: TyreRegistered
    private let analysisService = TyreAnalysisService.shared
    private var currentAnalysisId: UUID?

    // MARK: - Initialization

    init(tyre: TyreRegistered) {
        self.tyre = tyre
    }

    // MARK: - Data Loading

    func loadTyreData(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            // Prova a caricare l'ultima analisi dal database
            if !forceRefresh, let savedAnalysis = try await analysisService.getLatestAnalysis(forTyreId: tyre.id) {
                print("📦 [TyreDetailViewModel] Caricamento dati salvati per pneumatico \(tyre.id)")
                await loadFromSavedAnalysis(savedAnalysis)
            } else {
                print("🔄 [TyreDetailViewModel] Generazione nuovi dati per pneumatico \(tyre.id)")
                // Genera dati basati sull'età del pneumatico (DOT)
                let tyreAgeYears = calculateTyreAge(dot: tyre.dot)
                await generateAndSaveNewAnalysis(tyreAge: tyreAgeYears)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [TyreDetailViewModel] Errore caricamento dati: \(error)")

            // Fallback: genera dati localmente senza salvare
            let tyreAgeYears = calculateTyreAge(dot: tyre.dot)
            await generateLocalData(tyreAge: tyreAgeYears)

            isLoading = false
        }
    }

    // MARK: - Load from Database

    private func loadFromSavedAnalysis(_ analysis: TyreAnalysisRecord) async {
        // Carica dati profondità battistrada
        if let fl = analysis.depthFrontLeft,
           let fr = analysis.depthFrontRight,
           let rl = analysis.depthRearLeft,
           let rr = analysis.depthRearRight {
            treadDepthData = TreadDepthData(
                frontLeft: TreadMeasurement(depth: fl, position: "FL"),
                frontRight: TreadMeasurement(depth: fr, position: "FR"),
                rearLeft: TreadMeasurement(depth: rl, position: "RL"),
                rearRight: TreadMeasurement(depth: rr, position: "RR")
            )
        }

        // Carica vita rimanente
        if let percentage = analysis.remainingLifePercentage {
            remainingLifePercentage = percentage / 100.0 // Converti da percentuale
        }

        // Carica stima vita rimanente con proiezioni dal database
        if let km = analysis.remainingLifeKm,
           let months = analysis.remainingLifeMonths,
           let confidence = analysis.confidenceScore {

            // Carica proiezioni salvate
            var projections: [DepthProjection] = []
            if let savedProjections = try? await analysisService.getLifecycleProjections(forAnalysisId: analysis.id) {
                projections = savedProjections.map { proj in
                    DepthProjection(
                        kilometersFromNow: Double(proj.kilometersFromNow),
                        projectedDepth: proj.projectedDepth,
                        confidence: proj.confidence ?? 0.8
                    )
                }
            }

            remainingLifeEstimate = RemainingLifeEstimate(
                estimatedKilometers: Double(km),
                estimatedMonths: months,
                confidence: confidence,
                calculationMethod: .linear,
                factors: [],
                projectedDepthCurve: projections
            )
        }

        // Carica condizioni pneumatici
        if let fl = analysis.conditionFrontLeft,
           let fr = analysis.conditionFrontRight,
           let rl = analysis.conditionRearLeft,
           let rr = analysis.conditionRearRight {
            tireConditionData = TireConditionData(
                frontLeft: fl,
                frontRight: fr,
                rearLeft: rl,
                rearRight: rr
            )
        }

        currentAnalysisId = analysis.id
        print("✅ [TyreDetailViewModel] Dati caricati dal database")
    }

    // MARK: - Generate and Save New Analysis

    private func generateAndSaveNewAnalysis(tyreAge: Double) async {
        // Genera dati localmente
        await generateLocalData(tyreAge: tyreAge)

        // Salva nel database
        do {
            guard let userId = try? await SupabaseManager.client.auth.session.user.id else {
                print("⚠️ [TyreDetailViewModel] No user ID, skip saving")
                return
            }

            guard let treadData = treadDepthData,
                  let lifeEstimate = remainingLifeEstimate,
                  let conditionData = tireConditionData else {
                print("⚠️ [TyreDetailViewModel] Missing data, skip saving")
                return
            }

            // Prepara input per il database
            let input = TyreAnalysisInput(
                tyreId: tyre.id,
                userId: userId,
                vehicleId: tyre.vehicleId,
                analysisType: "automatic",
                depthFrontLeft: treadData.frontLeft.depth,
                depthFrontRight: treadData.frontRight.depth,
                depthRearLeft: treadData.rearLeft.depth,
                depthRearRight: treadData.rearRight.depth,
                depthAverage: treadData.averageDepth,
                depthMinimum: treadData.minDepth,
                remainingLifePercentage: remainingLifePercentage * 100, // Converti a percentuale
                remainingLifeKm: Int(lifeEstimate.estimatedKilometers),
                remainingLifeMonths: lifeEstimate.estimatedMonths,
                confidenceScore: lifeEstimate.confidence,
                conditionFrontLeft: conditionData.frontLeft,
                conditionFrontRight: conditionData.frontRight,
                conditionRearLeft: conditionData.rearLeft,
                conditionRearRight: conditionData.rearRight,
                wearPattern: determineWearPattern(treadData: treadData),
                wearSeverity: determineWearSeverity(averageDepth: treadData.averageDepth),
                notes: "Analisi automatica generata dall'app",
                technicianName: nil
            )

            // Salva l'analisi
            let savedAnalysis = try await analysisService.saveAnalysis(input)
            currentAnalysisId = savedAnalysis.id
            print("✅ [TyreDetailViewModel] Analisi salvata con ID: \(savedAnalysis.id)")

            // Salva le proiezioni lifecycle
            let projectionData = lifeEstimate.projectedDepthCurve.map { proj in
                (
                    km: Int(proj.kilometersFromNow),
                    depth: proj.projectedDepth,
                    confidence: proj.confidence,
                    isProjected: proj.kilometersFromNow >= 0
                )
            }

            try await analysisService.saveLifecycleProjections(
                analysisId: savedAnalysis.id,
                projections: projectionData
            )

            print("✅ [TyreDetailViewModel] Dati completi salvati nel database")

        } catch {
            print("❌ [TyreDetailViewModel] Errore salvataggio: \(error)")
            // Non blocchiamo l'app, i dati sono già generati localmente
        }
    }

    // MARK: - Generate Local Data (Fallback)

    private func generateLocalData(tyreAge: Double) async {
        let tyreAgeYears = tyreAge

        // Genera dati di profondità battistrada
        treadDepthData = generateTreadDepthData(tyreAge: tyreAgeYears)

        // Calcola vita rimanente
        remainingLifeEstimate = generateRemainingLifeEstimate(
            averageDepth: treadDepthData?.averageDepth ?? 7.2,
                tyreAge: tyreAgeYears
            )
            remainingLifePercentage = calculateRemainingLifePercentage(
                averageDepth: treadDepthData?.averageDepth ?? 7.2
            )

            // Genera dati condizione pneumatici
            tireConditionData = generateTireConditionData(tyreAge: tyreAgeYears)

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Private Helpers

    /// Calcola l'età del pneumatico dal codice DOT
    private func calculateTyreAge(dot: String) -> Double {
        // DOT format: WWYY (settimana/anno)
        guard dot.count >= 4 else { return 0 }

        let yearStr = String(dot.suffix(2))
        guard let year = Int(yearStr) else { return 0 }

        // Converti anno a 4 cifre (assumendo 2000+)
        let fullYear = year >= 0 && year <= 30 ? 2000 + year : 1900 + year
        let currentYear = Calendar.current.component(.year, from: Date())

        return Double(currentYear - fullYear)
    }

    /// Genera dati realistici di profondità battistrada basati sull'età
    private func generateTreadDepthData(tyreAge: Double) -> TreadDepthData {
        // Pneumatico nuovo: ~8mm
        // Usura tipica: ~0.8-1.2mm per anno (dipende dall'uso)
        let baseWear = tyreAge * 0.9 // mm

        // Aggiungi variazione realistica tra le posizioni
        let flDepth = max(1.6, 8.0 - baseWear - Double.random(in: 0...0.3))
        let frDepth = max(1.6, 8.0 - baseWear - Double.random(in: 0...0.3))
        let rlDepth = max(1.6, 8.0 - baseWear - Double.random(in: 0.2...0.8)) // Posteriori più usurati
        let rrDepth = max(1.6, 8.0 - baseWear - Double.random(in: 0.2...0.8))

        return TreadDepthData(
            frontLeft: TreadMeasurement(depth: flDepth, position: "FL"),
            frontRight: TreadMeasurement(depth: frDepth, position: "FR"),
            rearLeft: TreadMeasurement(depth: rlDepth, position: "RL"),
            rearRight: TreadMeasurement(depth: rrDepth, position: "RR")
        )
    }

    /// Genera stima vita rimanente
    private func generateRemainingLifeEstimate(averageDepth: Double, tyreAge: Double) -> RemainingLifeEstimate {
        let legalMinimum = 1.6
        let depthRemaining = averageDepth - legalMinimum

        // Stima km rimanenti (assumendo 0.00015 mm/km di usura)
        let wearRate = 0.00015 * (1.0 + (tyreAge * 0.1)) // Usura aumenta con l'età
        let estimatedKm = depthRemaining / wearRate

        // Stima mesi (assumendo 15000 km/anno)
        let estimatedMonths = Int((estimatedKm / 15000.0) * 12.0)

        // Confidence basato sulla profondità e età
        var confidence = 0.85
        if tyreAge > 5 { confidence -= 0.2 }
        if averageDepth < 3.0 { confidence -= 0.15 }

        // Genera proiezioni per il grafico
        let projections = generateProjections(
            currentDepth: averageDepth,
            estimatedKm: estimatedKm
        )

        return RemainingLifeEstimate(
            estimatedKilometers: max(0, estimatedKm),
            estimatedMonths: max(0, estimatedMonths),
            confidence: max(0.3, confidence),
            calculationMethod: .linear,
            factors: [],
            projectedDepthCurve: projections
        )
    }

    /// Genera proiezioni per il grafico lifecycle
    private func generateProjections(currentDepth: Double, estimatedKm: Double) -> [DepthProjection] {
        var projections: [DepthProjection] = []
        let legalMinimum = 1.6
        let wearRate = (currentDepth - legalMinimum) / estimatedKm

        // Punti storici (simulati basati sulla profondità attuale)
        let historicalPoints = [0.0, 5000.0, 10000.0, 15000.0, 20000.0]
        for km in historicalPoints {
            let depth = min(8.0, currentDepth + (wearRate * (estimatedKm - km)))
            projections.append(DepthProjection(
                kilometersFromNow: -km,
                projectedDepth: depth,
                confidence: 0.9
            ))
        }

        // Punto corrente
        projections.append(DepthProjection(
            kilometersFromNow: 0,
            projectedDepth: currentDepth,
            confidence: 1.0
        ))

        // Proiezioni future
        let futurePoints = [5000.0, 10000.0, estimatedKm * 0.75, estimatedKm]
        for km in futurePoints {
            let depth = max(legalMinimum, currentDepth - (wearRate * km))
            let confidenceLoss = (km / estimatedKm) * 0.4
            projections.append(DepthProjection(
                kilometersFromNow: km,
                projectedDepth: depth,
                confidence: max(0.4, 1.0 - confidenceLoss)
            ))
        }

        return projections.sorted { $0.kilometersFromNow < $1.kilometersFromNow }
    }

    /// Calcola percentuale vita rimanente
    private func calculateRemainingLifePercentage(averageDepth: Double) -> Double {
        let newTyreDepth = 8.0
        let legalMinimum = 1.6
        let usableDepth = newTyreDepth - legalMinimum
        let remainingDepth = averageDepth - legalMinimum

        return max(0, min(1.0, remainingDepth / usableDepth))
    }

    /// Genera dati condizione pneumatici per le barre
    private func generateTireConditionData(tyreAge: Double) -> TireConditionData {
        let baseCondition = max(20, 100 - Int(tyreAge * 12)) // Decade con l'età

        return TireConditionData(
            frontLeft: max(20, baseCondition - Int.random(in: 0...10)),
            frontRight: max(20, baseCondition - Int.random(in: 0...10)),
            rearLeft: max(20, baseCondition - Int.random(in: 10...25)), // Posteriori più usurati
            rearRight: max(20, baseCondition - Int.random(in: 10...25))
        )
    }

    /// Determina il pattern di usura in base ai dati
    private func determineWearPattern(treadData: TreadDepthData) -> String {
        let frontAvg = (treadData.frontLeft.depth + treadData.frontRight.depth) / 2.0
        let rearAvg = (treadData.rearLeft.depth + treadData.rearRight.depth) / 2.0
        let leftAvg = (treadData.frontLeft.depth + treadData.rearLeft.depth) / 2.0
        let rightAvg = (treadData.frontRight.depth + treadData.rearRight.depth) / 2.0

        let stdDev = calculateStandardDeviation([
            treadData.frontLeft.depth,
            treadData.frontRight.depth,
            treadData.rearLeft.depth,
            treadData.rearRight.depth
        ])

        // Pattern uniforme se variazione bassa
        if stdDev < 0.5 {
            return "uniform"
        }

        // Usura laterale se c'è differenza sinistra/destra
        if abs(leftAvg - rightAvg) > 1.0 {
            return "edge_wear"
        }

        // Usura anteriore/posteriore
        if abs(frontAvg - rearAvg) > 1.0 {
            return "center_wear"
        }

        return "patchy_wear"
    }

    /// Determina la severità dell'usura
    private func determineWearSeverity(averageDepth: Double) -> String {
        if averageDepth >= 6.0 {
            return "minimal"
        } else if averageDepth >= 4.0 {
            return "moderate"
        } else if averageDepth >= 2.5 {
            return "significant"
        } else if averageDepth >= 1.6 {
            return "severe"
        } else {
            return "critical"
        }
    }

    /// Calcola deviazione standard
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }
}

// MARK: - Supporting Models

struct TreadDepthData {
    let frontLeft: TreadMeasurement
    let frontRight: TreadMeasurement
    let rearLeft: TreadMeasurement
    let rearRight: TreadMeasurement

    var averageDepth: Double {
        (frontLeft.depth + frontRight.depth + rearLeft.depth + rearRight.depth) / 4.0
    }

    var minDepth: Double {
        min(frontLeft.depth, frontRight.depth, rearLeft.depth, rearRight.depth)
    }
}

struct TreadMeasurement {
    let depth: Double // in mm
    let position: String // "FL", "FR", "RL", "RR"

    var formattedDepth: String {
        String(format: "%.1f mm", depth)
    }

    var progress: Double {
        let newTyreDepth = 8.0
        let legalMinimum = 1.6
        let usableDepth = newTyreDepth - legalMinimum
        let currentUsable = depth - legalMinimum
        return max(0, min(1.0, currentUsable / usableDepth))
    }

    var color: Color {
        if depth >= 6.0 {
            return .green
        } else if depth >= 3.0 {
            return .yellow
        } else if depth >= 2.0 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TireConditionData {
    let frontLeft: Int // percentage 0-100
    let frontRight: Int
    let rearLeft: Int
    let rearRight: Int

    func percentage(for position: String) -> Int {
        switch position {
        case "FL": return frontLeft
        case "FR": return frontRight
        case "RL": return rearLeft
        case "RR": return rearRight
        default: return 50
        }
    }

    func color(for position: String) -> Color {
        let percentage = self.percentage(for: position)
        if percentage >= 70 {
            return .green
        } else if percentage >= 50 {
            return .yellow
        } else if percentage >= 35 {
            return .orange
        } else {
            return .red
        }
    }
}
