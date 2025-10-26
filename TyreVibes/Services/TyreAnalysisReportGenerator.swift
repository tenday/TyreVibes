//
//  TyreAnalysisReportGenerator.swift
//  TyreVibes
//
//  Main class for generating comprehensive tyre analysis reports
//

import Foundation
import UIKit
import PDFKit
import CoreLocation
import SwiftUI

@MainActor
class TyreAnalysisReportGenerator: ObservableObject {

    // MARK: - Published Properties
    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentReport: TyreAnalysisReport?
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let treadDepthAnalyzer = TreadDepthAnalyzer()
    private let lifeCalculator = RemainingLifeCalculator()
    private let pdfBuilder = PDFReportBuilder()

    // MARK: - Report Generation

    /// Generate comprehensive report from analysis result
    func generateReport(
        from analysisResult: TreadDepthAnalyzer.AnalysisResult,
        vehicle: VehicleResponse,
        tyre: TyreRegistered,
        position: TyreInfo.TyrePosition,
        analysisType: ReportMetadata.AnalysisType = .comprehensive,
        location: CLLocation? = nil
    ) async -> TyreAnalysisReport? {

        isGenerating = true
        progress = 0.0
        errorMessage = nil

        // Step 1: Create metadata (10%)
        progress = 0.1
        let metadata = createMetadata(
            vehicle: vehicle,
            tyre: tyre,
            position: position,
            analysisType: analysisType,
            location: location
        )

        // Step 2: Process depth analysis (20%)
        progress = 0.3
        let depthAnalysis = processDepthAnalysis(from: analysisResult)

        // Step 3: Analyze wear patterns (30%)
        progress = 0.5
        let wearAnalysis = analyzeWearPatterns(from: analysisResult)

        // Step 4: Generate heat map (40%)
        progress = 0.7
        let heatMap = generateHeatMap(from: analysisResult.measurements)

        // Step 5: Calculate remaining life (50%)
        progress = 0.8
        let vehicleInfo = VehicleInfo(
            make: vehicle.vehicle.make ?? "Unknown",
            model: vehicle.vehicle.model ?? "Unknown",
            year: vehicle.plate?.year,
            plateNumber: vehicle.plate?.plateNumber ?? "N/A",
            vin: vehicle.vehicle.vin
        )

        let remainingLife = lifeCalculator.calculateRemainingLife(
            from: depthAnalysis,
            wearAnalysis: wearAnalysis,
            vehicleInfo: vehicleInfo,
            historicalData: nil
        )

        // Step 6: Calculate safety score (60%)
        progress = 0.85
        let safetyScore = calculateSafetyScore(
            depthAnalysis: depthAnalysis,
            wearAnalysis: wearAnalysis
        )

        // Step 7: Generate recommendations (70%)
        progress = 0.9
        let recommendations = generateRecommendations(
            depthAnalysis: depthAnalysis,
            wearAnalysis: wearAnalysis,
            remainingLife: remainingLife,
            safetyScore: safetyScore
        )

        // Step 8: Create final report (100%)
        progress = 1.0
        let report = TyreAnalysisReport(
            metadata: metadata,
            depthAnalysis: depthAnalysis,
            wearAnalysis: wearAnalysis,
            heatMap: heatMap,
            remainingLife: remainingLife,
            recommendations: recommendations,
            safetyScore: safetyScore
        )

        currentReport = report
        isGenerating = false

        return report
    }

    // MARK: - Export Functions

    /// Export report as PDF
    func exportToPDF(_ report: TyreAnalysisReport) -> PDFDocument? {
        return pdfBuilder.generatePDF(from: report)
    }

    /// Export report as JSON
    func exportToJSON(_ report: TyreAnalysisReport) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(report)
    }

    /// Export heat map as image
    func exportHeatMapImage(_ report: TyreAnalysisReport) -> UIImage? {
        let renderer = ImageRenderer(content: HeatMapView(
            heatMap: report.heatMap,
            minDepth: report.depthAnalysis.minimum,
            maxDepth: report.depthAnalysis.maximum
        ))

        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    /// Share report
    func shareReport(_ report: TyreAnalysisReport, format: ReportExportFormat) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "TyreAnalysis_\(report.metadata.reportId).\(format.fileExtension)"
        let fileURL = tempDir.appendingPathComponent(filename)

        switch format {
        case .pdf:
            guard let pdf = exportToPDF(report) else { return nil }
            pdf.write(to: fileURL)
            return fileURL

        case .json:
            guard let data = exportToJSON(report) else { return nil }
            try? data.write(to: fileURL)
            return fileURL

        case .image(let imageFormat):
            guard let image = exportHeatMapImage(report) else { return nil }
            switch imageFormat {
            case .png:
                try? image.pngData()?.write(to: fileURL)
            case .jpeg(let quality):
                try? image.jpegData(compressionQuality: quality)?.write(to: fileURL)
            }
            return fileURL

        case .html:
            let html = generateHTML(report)
            try? html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }

    // MARK: - Private Methods

    private func createMetadata(
        vehicle: VehicleResponse,
        tyre: TyreRegistered,
        position: TyreInfo.TyrePosition,
        analysisType: ReportMetadata.AnalysisType,
        location: CLLocation?
    ) -> ReportMetadata {

        let reportId = UUID().uuidString.prefix(8).uppercased()

        let vehicleInfo = VehicleInfo(
            make: vehicle.vehicle.make ?? "Unknown",
            model: vehicle.vehicle.model ?? "Unknown",
            year: vehicle.plate?.year,
            plateNumber: vehicle.plate?.plateNumber ?? "N/A",
            vin: vehicle.vehicle.vin
        )

        let tyreInfo = TyreInfo(
            brand: tyre.brand,
            model: tyre.model,
            size: tyre.size,
            dot: tyre.dot,
            position: position,
            season: tyre.season,
            loadIndex: tyre.loadIndex,
            speedRating: tyre.speedRating
        )

        var locationInfo: LocationInfo? = nil
        if let loc = location {
            locationInfo = LocationInfo(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                address: nil
            )
        }

        return ReportMetadata(
            reportId: String(reportId),
            timestamp: Date(),
            vehicle: vehicleInfo,
            tyre: tyreInfo,
            location: locationInfo,
            weather: nil,
            analysisType: analysisType
        )
    }

    private func processDepthAnalysis(from result: TreadDepthAnalyzer.AnalysisResult) -> DepthAnalysis {
        let measurements = result.measurements.map { measurement in
            DepthMeasurementPoint(
                x: measurement.location.x / 1000,  // Normalize
                y: measurement.location.y / 1000,
                depth: measurement.depth,
                confidence: measurement.confidence,
                zone: determineZone(for: measurement.location)
            )
        }

        let distribution = calculateDepthDistribution(measurements: measurements)

        let legalStatus: DepthAnalysis.LegalStatus
        if result.averageDepth < 1.6 {
            legalStatus = .illegal
        } else if result.averageDepth < 2.5 {
            legalStatus = .nearLimit
        } else {
            legalStatus = .legal
        }

        return DepthAnalysis(
            average: result.averageDepth,
            minimum: result.minDepth,
            maximum: result.maxDepth,
            standardDeviation: result.standardDeviation,
            measurements: measurements,
            legalStatus: legalStatus,
            depthDistribution: distribution
        )
    }

    private func analyzeWearPatterns(from result: TreadDepthAnalyzer.AnalysisResult) -> WearAnalysis {
        // Convert wear pattern
        let pattern: WearAnalysis.WearPattern
        switch result.wearPattern {
        case .uniform:
            pattern = .uniform
        case .centerWear:
            pattern = .centerWear
        case .edgeWear:
            pattern = .edgeWear
        case .patchyWear:
            pattern = .patchyWear
        case .excessive:
            pattern = .patchyWear
        }

        // Determine severity based on depth and pattern
        let severity = determineSeverity(
            averageDepth: result.averageDepth,
            minDepth: result.minDepth,
            stdDev: result.standardDeviation
        )

        // Identify causes
        let causes = identifyWearCauses(pattern: pattern, result: result)

        // Zone analysis
        let zoneAnalysis = analyzeZones(measurements: result.measurements)

        // Uneven wear index
        let unevenWearIndex = result.standardDeviation / result.averageDepth

        return WearAnalysis(
            pattern: pattern,
            severity: severity,
            unevenWearIndex: min(1.0, unevenWearIndex),
            zoneAnalysis: zoneAnalysis,
            causes: causes
        )
    }

    private func generateHeatMap(from measurements: [TreadDepthAnalyzer.DepthMeasurement]) -> DepthHeatMap {
        let gridSize = 20
        var grid: [[Double]] = Array(repeating: Array(repeating: 0.0, count: gridSize), count: gridSize)

        // Interpolate measurements into grid
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = Double(col) / Double(gridSize - 1)
                let y = Double(row) / Double(gridSize - 1)

                let interpolatedDepth = interpolateDepth(
                    at: CGPoint(x: x * 1000, y: y * 1000),
                    from: measurements
                )

                grid[row][col] = interpolatedDepth
            }
        }

        return DepthHeatMap(
            gridSize: DepthHeatMap.GridSize(rows: gridSize, columns: gridSize),
            dataPoints: grid,
            colorScheme: .thermal,
            interpolated: true
        )
    }

    private func calculateSafetyScore(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis
    ) -> SafetyScore {

        // Calculate component scores
        let depthScore = calculateDepthScore(depthAnalysis)
        let wearPatternScore = calculateWearPatternScore(wearAnalysis)
        let uniformityScore = calculateUniformityScore(depthAnalysis)
        let legalScore = depthAnalysis.legalStatus == .legal ? 1.0 : 0.0
        let conditionScore = (depthAnalysis.average / 8.0)

        let components = SafetyScore.ScoreComponents(
            depthScore: depthScore,
            wearPatternScore: wearPatternScore,
            uniformityScore: uniformityScore,
            legalComplianceScore: legalScore,
            conditionScore: conditionScore
        )

        // Weighted average
        let overall = (
            depthScore * 0.3 +
            wearPatternScore * 0.25 +
            uniformityScore * 0.20 +
            legalScore * 0.15 +
            conditionScore * 0.10
        ) * 100

        let rating = SafetyScore.Rating.fromScore(overall)

        return SafetyScore(
            overall: overall,
            rating: rating,
            components: components
        )
    }

    private func generateRecommendations(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        remainingLife: RemainingLifeEstimate,
        safetyScore: SafetyScore
    ) -> [Recommendation] {

        var recommendations: [Recommendation] = []

        // Critical recommendations based on legal status
        if depthAnalysis.legalStatus == .illegal {
            recommendations.append(Recommendation(
                priority: .critical,
                category: .legal,
                title: "Immediate Replacement Required",
                description: "The tyre depth is below the legal minimum of 1.6mm. Continued use is illegal and extremely dangerous.",
                action: "Replace the tyre immediately before driving",
                urgency: .immediate
            ))
        } else if depthAnalysis.legalStatus == .nearLimit {
            recommendations.append(Recommendation(
                priority: .high,
                category: .safety,
                title: "Plan Replacement Soon",
                description: "The tyre depth is approaching the legal minimum. Plan for replacement within the next 1-2 weeks.",
                action: "Schedule tyre replacement appointment",
                urgency: .withinWeek
            ))
        }

        // Wear pattern recommendations
        switch wearAnalysis.pattern {
        case .centerWear:
            recommendations.append(Recommendation(
                priority: .medium,
                category: .maintenance,
                title: "Check Tyre Pressure",
                description: "Center wear indicates possible over-inflation. This reduces tyre life and grip.",
                action: "Reduce tyre pressure to manufacturer's recommended PSI",
                urgency: .withinWeek
            ))

        case .edgeWear, .innerEdgeWear, .outerEdgeWear:
            recommendations.append(Recommendation(
                priority: .high,
                category: .maintenance,
                title: "Wheel Alignment Required",
                description: "Edge wear indicates alignment issues or under-inflation.",
                action: "Get professional wheel alignment and check tyre pressure",
                urgency: .withinWeek
            ))

        case .patchyWear, .cuppingWear:
            recommendations.append(Recommendation(
                priority: .high,
                category: .maintenance,
                title: "Suspension Check Required",
                description: "Irregular wear suggests suspension or balancing issues.",
                action: "Have suspension and wheel balance inspected by a professional",
                urgency: .withinWeek
            ))

        case .feathering:
            recommendations.append(Recommendation(
                priority: .medium,
                category: .maintenance,
                title: "Alignment Adjustment Needed",
                description: "Feathering indicates toe alignment issues.",
                action: "Get toe alignment corrected",
                urgency: .withinMonth
            ))

        case .excessive:
            recommendations.append(Recommendation(
                priority: .critical,
                category: .safety,
                title: "Immediate Replacement Required",
                description: "Excessive wear poses a serious safety risk.",
                action: "Replace tyres immediately",
                urgency: .immediate
            ))

        case .uniform:
            if depthAnalysis.average > 5.0 {
                recommendations.append(Recommendation(
                    priority: .low,
                    category: .maintenance,
                    title: "Continue Regular Maintenance",
                    description: "Tyre shows healthy, uniform wear. Keep up the good maintenance practices.",
                    action: "Continue regular rotation and pressure checks",
                    urgency: .routine
                ))
            }
        }

        // Remaining life recommendations
        if remainingLife.estimatedKilometers < 2000 {
            recommendations.append(Recommendation(
                priority: .high,
                category: .cost,
                title: "Budget for Replacement",
                description: "Based on current wear rate, replacement will be needed within \(remainingLife.formattedDistance).",
                action: "Start researching and budgeting for new tyres",
                urgency: .withinMonth
            ))
        }

        // Performance recommendations
        if safetyScore.overall < 60 {
            recommendations.append(Recommendation(
                priority: .high,
                category: .performance,
                title: "Reduced Performance",
                description: "Current tyre condition significantly impacts vehicle performance and safety.",
                action: "Limit high-speed driving and avoid wet conditions when possible",
                urgency: .immediate
            ))
        }

        return recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }

    // MARK: - Helper Methods

    private func determineZone(for location: CGPoint) -> DepthMeasurementPoint.TyreZone {
        let normalizedX = location.x / 1000

        if normalizedX < 0.25 {
            return .innerEdge
        } else if normalizedX > 0.75 {
            return .outerEdge
        } else if normalizedX > 0.4 && normalizedX < 0.6 {
            return .center
        } else {
            return .shoulder
        }
    }

    private func calculateDepthDistribution(measurements: [DepthMeasurementPoint]) -> DepthAnalysis.DepthDistribution {
        var excellent = 0
        var good = 0
        var fair = 0
        var poor = 0
        var critical = 0

        for measurement in measurements {
            switch measurement.depth {
            case 6...: excellent += 1
            case 4..<6: good += 1
            case 2.5..<4: fair += 1
            case 1.6..<2.5: poor += 1
            default: critical += 1
            }
        }

        return DepthAnalysis.DepthDistribution(
            excellent: excellent,
            good: good,
            fair: fair,
            poor: poor,
            critical: critical
        )
    }

    private func determineSeverity(averageDepth: Double, minDepth: Double, stdDev: Double) -> WearAnalysis.WearSeverity {
        if averageDepth < 2.0 || minDepth < 1.6 {
            return .critical
        } else if stdDev > 1.5 || averageDepth < 3.0 {
            return .severe
        } else if stdDev > 1.0 || averageDepth < 4.0 {
            return .significant
        } else if stdDev > 0.5 || averageDepth < 5.0 {
            return .moderate
        } else {
            return .minimal
        }
    }

    private func identifyWearCauses(pattern: WearAnalysis.WearPattern, result: TreadDepthAnalyzer.AnalysisResult) -> [WearCause] {
        var causes: [WearCause] = []

        switch pattern {
        case .centerWear:
            causes.append(WearCause(
                type: .overInflation,
                probability: 0.85,
                description: "Eccessiva pressione dei pneumatici causa usura concentrata al centro"
            ))

        case .edgeWear:
            causes.append(WearCause(
                type: .underInflation,
                probability: 0.80,
                description: "Pressione insufficiente causa usura sui bordi"
            ))

        case .innerEdgeWear, .outerEdgeWear:
            causes.append(WearCause(
                type: .misalignment,
                probability: 0.90,
                description: "Disallineamento delle ruote causa usura asimmetrica"
            ))

        case .patchyWear, .cuppingWear:
            causes.append(WearCause(
                type: .suspension,
                probability: 0.75,
                description: "Problemi alle sospensioni o bilanciamento causano usura irregolare"
            ))

        case .feathering:
            causes.append(WearCause(
                type: .misalignment,
                probability: 0.85,
                description: "Convergenza non corretta causa usura a piuma"
            ))

        case .excessive:
            causes.append(WearCause(
                type: .drivingStyle,
                probability: 0.90,
                description: "Guida aggressiva e carico eccessivo causano usura prematura"
            ))

        case .uniform:
            // No specific causes for uniform wear
            break
        }

        // Additional general causes
        if result.standardDeviation > 1.0 {
            causes.append(WearCause(
                type: .improperRotation,
                probability: 0.60,
                description: "Mancata rotazione periodica contribuisce all'usura irregolare"
            ))
        }

        return causes
    }

    private func analyzeZones(measurements: [TreadDepthAnalyzer.DepthMeasurement]) -> [WearAnalysis.ZoneWearInfo] {
        let zones: [WearAnalysis.Zone] = [.inner, .center, .outer]
        var zoneInfo: [WearAnalysis.ZoneWearInfo] = []

        for zone in zones {
            let zoneMeasurements = measurements.filter { measurement in
                mapToWearZone(determineZone(for: measurement.location)) == zone
            }

            guard !zoneMeasurements.isEmpty else { continue }

            let avgDepth = zoneMeasurements.map { $0.depth }.reduce(0, +) / Double(zoneMeasurements.count)
            let wearPercentage = 1.0 - (avgDepth / 8.0)

            zoneInfo.append(WearAnalysis.ZoneWearInfo(
                zone: zone,
                averageDepth: avgDepth,
                wearPercentage: wearPercentage
            ))
        }

        return zoneInfo
    }

    private func mapToWearZone(_ tyreZone: DepthMeasurementPoint.TyreZone) -> WearAnalysis.Zone {
        switch tyreZone {
        case .innerEdge:
            return .inner
        case .center:
            return .center
        case .outerEdge, .shoulder:
            return .outer
        }
    }

    private func interpolateDepth(at point: CGPoint, from measurements: [TreadDepthAnalyzer.DepthMeasurement]) -> Double {
        var weightedSum = 0.0
        var weightSum = 0.0

        for measurement in measurements {
            let dx = point.x - measurement.location.x
            let dy = point.y - measurement.location.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < 0.1 {
                return measurement.depth
            }

            let weight = 1.0 / pow(distance, 2.0)
            weightedSum += weight * measurement.depth
            weightSum += weight
        }

        return weightSum > 0 ? weightedSum / weightSum : 0
    }

    private func calculateDepthScore(_ analysis: DepthAnalysis) -> Double {
        return min(1.0, analysis.average / 8.0)
    }

    private func calculateWearPatternScore(_ analysis: WearAnalysis) -> Double {
        switch analysis.pattern {
        case .uniform: return 1.0
        case .centerWear, .edgeWear: return 0.7
        case .innerEdgeWear, .outerEdgeWear: return 0.6
        case .patchyWear: return 0.4
        case .cuppingWear, .feathering: return 0.3
        case .excessive: return 0.1
        }
    }

    private func calculateUniformityScore(_ analysis: DepthAnalysis) -> Double {
        let maxStdDev = 2.0
        return max(0, 1.0 - (analysis.standardDeviation / maxStdDev))
    }

    private func generateHTML(_ report: TyreAnalysisReport) -> String {
        // Basic HTML generation (can be expanded)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Tyre Analysis Report - \(report.metadata.reportId)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                h1 { color: #FF6B6B; }
                .metric { margin: 10px 0; }
                .label { font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>Tyre Analysis Report</h1>
            <div class="metric">
                <span class="label">Vehicle:</span> \(report.metadata.vehicle.make) \(report.metadata.vehicle.model)
            </div>
            <div class="metric">
                <span class="label">Average Depth:</span> \(String(format: "%.2f mm", report.depthAnalysis.average))
            </div>
            <div class="metric">
                <span class="label">Safety Score:</span> \(Int(report.safetyScore.overall))/100
            </div>
        </body>
        </html>
        """
    }
}
