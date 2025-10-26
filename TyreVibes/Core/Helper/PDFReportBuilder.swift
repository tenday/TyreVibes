//
//  PDFReportBuilder.swift
//  TyreVibes
//
//  PDF generation for tyre analysis reports
//

import Foundation
import UIKit
import PDFKit
import SwiftUI

class PDFReportBuilder {

    // MARK: - Properties
    private let pageSize = CGSize(width: 595, height: 842)  // A4 size in points
    private let margin: CGFloat = 40
    private var currentY: CGFloat = 0

    // MARK: - PDF Generation

    func generatePDF(from report: TyreAnalysisReport) -> PDFDocument? {
        let pdfMetaData = [
            kCGPDFContextTitle as String: "Tyre Analysis Report",
            kCGPDFContextAuthor as String: "TyreVibes",
            kCGPDFContextSubject as String: "Detailed tyre depth and wear analysis"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        let data = renderer.pdfData { context in
            // Page 1: Cover
            context.beginPage()
            currentY = margin
            drawCoverPage(context: context.cgContext, report: report)

            // Page 2: Executive Summary
            context.beginPage()
            currentY = margin
            drawExecutiveSummary(context: context.cgContext, report: report)

            // Page 3: Heat Map
            context.beginPage()
            currentY = margin
            drawHeatMapPage(context: context.cgContext, report: report)

            // Page 4: Detailed Analysis
            context.beginPage()
            currentY = margin
            drawDetailedAnalysis(context: context.cgContext, report: report)

            // Page 5: Charts & Statistics
            context.beginPage()
            currentY = margin
            drawChartsPage(context: context.cgContext, report: report)

            // Page 6: Recommendations
            context.beginPage()
            currentY = margin
            drawRecommendationsPage(context: context.cgContext, report: report)
        }

        return PDFDocument(data: data)
    }

    // MARK: - Cover Page

    private func drawCoverPage(context: CGContext, report: TyreAnalysisReport) {
        // App logo/title
        let titleText = "TYREVIBES"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor(hex: "FF6B6B")
        ]
        let titleSize = titleText.size(withAttributes: titleAttrs)
        titleText.draw(
            at: CGPoint(x: (pageSize.width - titleSize.width) / 2, y: 80),
            withAttributes: titleAttrs
        )

        currentY = 160

        // Report title
        let reportTitle = "Tyre Analysis Report"
        let reportTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let reportTitleSize = reportTitle.size(withAttributes: reportTitleAttrs)
        reportTitle.draw(
            at: CGPoint(x: (pageSize.width - reportTitleSize.width) / 2, y: currentY),
            withAttributes: reportTitleAttrs
        )

        currentY += 80

        // Vehicle info box
        let vehicleBoxRect = CGRect(
            x: margin,
            y: currentY,
            width: pageSize.width - (2 * margin),
            height: 120
        )

        // Draw box background
        context.setFillColor(UIColor(hex: "F5F5F5").cgColor)
        context.fill(vehicleBoxRect)

        // Vehicle details
        let vehicleInfo = """
        Vehicle: \(report.metadata.vehicle.make) \(report.metadata.vehicle.model)
        Plate: \(report.metadata.vehicle.plateNumber)
        Year: \(report.metadata.vehicle.year ?? 0)

        Tyre: \(report.metadata.tyre.brand) \(report.metadata.tyre.model)
        Size: \(report.metadata.tyre.size)
        Position: \(report.metadata.tyre.position.rawValue)
        """

        let vehicleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        vehicleInfo.draw(
            in: vehicleBoxRect.insetBy(dx: 20, dy: 15),
            withAttributes: vehicleAttrs
        )

        currentY += 160

        // Safety score badge
        drawSafetyScoreBadge(
            context: context,
            score: report.safetyScore,
            center: CGPoint(x: pageSize.width / 2, y: currentY + 80)
        )

        currentY += 200

        // Report metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let metadataText = """
        Report ID: \(report.metadata.reportId)
        Generated: \(dateFormatter.string(from: report.metadata.timestamp))
        Analysis Type: \(report.metadata.analysisType.rawValue)
        """

        let metadataAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.gray
        ]

        metadataText.draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: metadataAttrs
        )

        // Footer
        drawFooter(context: context, pageNumber: 1, totalPages: 6)
    }

    // MARK: - Executive Summary

    private func drawExecutiveSummary(context: CGContext, report: TyreAnalysisReport) {
        drawHeader(context: context, title: "Executive Summary")

        currentY += 20

        // Safety status
        let statusColor = report.safetyScore.rating.color.toUIColor()
        drawInfoBox(
            context: context,
            title: "Safety Status",
            content: report.safetyScore.rating.description,
            color: statusColor
        )

        currentY += 20

        // Key metrics
        let metricsTitle = "Key Metrics"
        drawSectionTitle(context: context, title: metricsTitle)

        let metrics = [
            ("Average Depth", String(format: "%.2f mm", report.depthAnalysis.average)),
            ("Minimum Depth", String(format: "%.2f mm", report.depthAnalysis.minimum)),
            ("Legal Status", report.depthAnalysis.legalStatus.rawValue),
            ("Wear Pattern", report.wearAnalysis.pattern.description),
            ("Wear Severity", report.wearAnalysis.severity.rawValue),
            ("Est. Remaining Life", report.remainingLife.formattedDistance)
        ]

        for (label, value) in metrics {
            drawMetricRow(context: context, label: label, value: value)
            currentY += 30
        }

        currentY += 20

        // Summary text
        let summaryText = generateSummaryText(report: report)
        let summaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        let summaryRect = CGRect(
            x: margin,
            y: currentY,
            width: pageSize.width - (2 * margin),
            height: 200
        )

        summaryText.draw(in: summaryRect, withAttributes: summaryAttrs)

        drawFooter(context: context, pageNumber: 2, totalPages: 6)
    }

    // MARK: - Heat Map Page

    private func drawHeatMapPage(context: CGContext, report: TyreAnalysisReport) {
        drawHeader(context: context, title: "Depth Heat Map")

        currentY += 20

        let heatMapImage = generateHeatMapImage(report.heatMap, minDepth: report.depthAnalysis.minimum, maxDepth: report.depthAnalysis.maximum)

        let imageRect = CGRect(
            x: margin,
            y: currentY,
            width: pageSize.width - (2 * margin),
            height: 300
        )

        heatMapImage.draw(in: imageRect)

        currentY += 320

        // Legend
        drawHeatMapLegend(
            context: context,
            colorScheme: report.heatMap.colorScheme,
            minValue: report.depthAnalysis.minimum,
            maxValue: report.depthAnalysis.maximum
        )

        currentY += 80

        // Zone analysis
        drawSectionTitle(context: context, title: "Zone Analysis")

        for zone in report.wearAnalysis.zoneAnalysis {
            let zoneText = "\(zone.zone.rawValue): \(String(format: "%.2f mm", zone.averageDepth)) (Wear: \(String(format: "%.1f%%", zone.wearPercentage * 100)))"
            let zoneAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black
            ]
            zoneText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: zoneAttrs)
            currentY += 25
        }

        drawFooter(context: context, pageNumber: 3, totalPages: 6)
    }

    // MARK: - Detailed Analysis

    private func drawDetailedAnalysis(context: CGContext, report: TyreAnalysisReport) {
        drawHeader(context: context, title: "Detailed Analysis")

        currentY += 20

        // Wear analysis
        drawSubHeader(context: context, title: "Wear Pattern Analysis")

        let wearInfo = """
        Pattern: \(report.wearAnalysis.pattern.description)
        Severity: \(report.wearAnalysis.severity.rawValue)
        Uneven Wear Index: \(String(format: "%.2f", report.wearAnalysis.unevenWearIndex))
        """

        let wearAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ]

        wearInfo.draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: wearAttrs
        )

        currentY += 80

        // Probable causes
        drawSubHeader(context: context, title: "Probable Causes")

        for cause in report.wearAnalysis.causes {
            let causeText = "• \(cause.type.rawValue) (\(Int(cause.probability * 100))% probability)"
            let causeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            causeText.draw(at: CGPoint(x: margin + 10, y: currentY), withAttributes: causeAttrs)
            currentY += 20

            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            cause.description.draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: descAttrs)
            currentY += 25
        }

        currentY += 20

        // Remaining life
        drawSubHeader(context: context, title: "Remaining Life Estimate")

        let lifeInfo = """
        Estimated Distance: \(report.remainingLife.formattedDistance)
        Estimated Time: \(report.remainingLife.estimatedMonths) months
        Confidence: \(Int(report.remainingLife.confidence * 100))%
        Method: \(report.remainingLife.calculationMethod.rawValue)
        """

        lifeInfo.draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: wearAttrs
        )

        drawFooter(context: context, pageNumber: 4, totalPages: 6)
    }

    // MARK: - Charts Page

    private func drawChartsPage(context: CGContext, report: TyreAnalysisReport) {
        drawHeader(context: context, title: "Statistics & Charts")

        currentY += 20

        // Depth distribution chart (simplified as text for PDF)
        drawSubHeader(context: context, title: "Depth Distribution")

        let distribution = report.depthAnalysis.depthDistribution
        let distributionData = [
            ("Excellent (>6mm)", distribution.excellent),
            ("Good (4-6mm)", distribution.good),
            ("Fair (2.5-4mm)", distribution.fair),
            ("Poor (1.6-2.5mm)", distribution.poor),
            ("Critical (<1.6mm)", distribution.critical)
        ]

        let total = distribution.excellent + distribution.good + distribution.fair + distribution.poor + distribution.critical

        for (label, count) in distributionData {
            let percentage = total > 0 ? (Double(count) / Double(total) * 100) : 0
            drawProgressBar(
                context: context,
                label: label,
                value: percentage,
                y: currentY
            )
            currentY += 35
        }

        currentY += 20

        // Score components
        drawSubHeader(context: context, title: "Score Components")

        let components = [
            ("Depth Score", report.safetyScore.components.depthScore),
            ("Wear Pattern", report.safetyScore.components.wearPatternScore),
            ("Uniformity", report.safetyScore.components.uniformityScore),
            ("Legal Compliance", report.safetyScore.components.legalComplianceScore),
            ("Condition", report.safetyScore.components.conditionScore)
        ]

        for (label, score) in components {
            drawProgressBar(
                context: context,
                label: label,
                value: score * 100,
                y: currentY
            )
            currentY += 35
        }

        drawFooter(context: context, pageNumber: 5, totalPages: 6)
    }

    // MARK: - Recommendations Page

    private func drawRecommendationsPage(context: CGContext, report: TyreAnalysisReport) {
        drawHeader(context: context, title: "Recommendations")

        currentY += 20

        let sortedRecommendations = report.recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }

        for recommendation in sortedRecommendations {
            let priorityColor = recommendation.priority.color.toUIColor()

            // Draw priority badge
            let badgeRect = CGRect(
                x: margin,
                y: currentY,
                width: 80,
                height: 25
            )

            context.setFillColor(priorityColor.cgColor)
            context.fill(badgeRect)

            let priorityAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            recommendation.priority.rawValue.draw(
                in: badgeRect.insetBy(dx: 8, dy: 5),
                withAttributes: priorityAttrs
            )

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black
            ]

            recommendation.title.draw(
                at: CGPoint(x: margin, y: currentY + 30),
                withAttributes: titleAttrs
            )

            currentY += 50

            // Description
            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let descRect = CGRect(
                x: margin,
                y: currentY,
                width: pageSize.width - (2 * margin),
                height: 60
            )

            recommendation.description.draw(in: descRect, withAttributes: descAttrs)

            currentY += 70

            // Action
            let actionText = "Action: \(recommendation.action)"
            let actionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor(hex: "FF6B6B")
            ]

            actionText.draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: actionAttrs
            )

            currentY += 35
        }

        drawFooter(context: context, pageNumber: 6, totalPages: 6)
    }

    // MARK: - Drawing Helpers

    private func drawHeader(context: CGContext, title: String) {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor(hex: "FF6B6B")
        ]

        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerAttrs)
        currentY += 35

        // Underline
        context.setStrokeColor(UIColor(hex: "FF6B6B").cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: currentY))
        context.strokePath()

        currentY += 10
    }

    private func drawSubHeader(context: CGContext, title: String) {
        let subHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: subHeaderAttrs)
        currentY += 30
    }

    private func drawSectionTitle(context: CGContext, title: String) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]

        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs)
        currentY += 25
    }

    private func drawFooter(context: CGContext, pageNumber: Int, totalPages: Int) {
        let footerY = pageSize.height - 30

        let footerText = "Page \(pageNumber) of \(totalPages) • Generated by TyreVibes"
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]

        let footerSize = footerText.size(withAttributes: footerAttrs)
        footerText.draw(
            at: CGPoint(x: (pageSize.width - footerSize.width) / 2, y: footerY),
            withAttributes: footerAttrs
        )
    }

    private func drawInfoBox(context: CGContext, title: String, content: String, color: UIColor) {
        let boxRect = CGRect(
            x: margin,
            y: currentY,
            width: pageSize.width - (2 * margin),
            height: 80
        )

        context.setFillColor(color.withAlphaComponent(0.1).cgColor)
        context.fill(boxRect)

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.stroke(boxRect)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: color
        ]

        title.draw(
            at: CGPoint(x: margin + 15, y: currentY + 15),
            withAttributes: titleAttrs
        )

        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        content.draw(
            at: CGPoint(x: margin + 15, y: currentY + 45),
            withAttributes: contentAttrs
        )

        currentY += 90
    }

    private func drawMetricRow(context: CGContext, label: String, value: String) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        label.draw(at: CGPoint(x: margin, y: currentY), withAttributes: labelAttrs)

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        let valueSize = value.size(withAttributes: valueAttrs)
        value.draw(
            at: CGPoint(x: pageSize.width - margin - valueSize.width, y: currentY),
            withAttributes: valueAttrs
        )
    }

    private func drawProgressBar(context: CGContext, label: String, value: Double, y: CGFloat) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black
        ]

        label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)

        let barWidth: CGFloat = 200
        let barHeight: CGFloat = 20
        let barX = pageSize.width - margin - barWidth - 50

        // Background
        let bgRect = CGRect(x: barX, y: y, width: barWidth, height: barHeight)
        context.setFillColor(UIColor.lightGray.withAlphaComponent(0.3).cgColor)
        context.fill(bgRect)

        // Progress
        let progressWidth = barWidth * (value / 100)
        let progressRect = CGRect(x: barX, y: y, width: progressWidth, height: barHeight)

        let progressColor = value > 75 ? UIColor.green : (value > 50 ? UIColor.orange : UIColor.red)
        context.setFillColor(progressColor.cgColor)
        context.fill(progressRect)

        // Percentage text
        let percentText = String(format: "%.0f%%", value)
        let percentAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        percentText.draw(
            at: CGPoint(x: barX + barWidth + 10, y: y + 3),
            withAttributes: percentAttrs
        )
    }

    private func drawSafetyScoreBadge(context: CGContext, score: SafetyScore, center: CGPoint) {
        let radius: CGFloat = 60

        // Circle
        context.setFillColor(score.rating.color.toUIColor().cgColor)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()

        // Score text
        let scoreText = String(format: "%.0f", score.overall)
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let scoreSize = scoreText.size(withAttributes: scoreAttrs)
        scoreText.draw(
            at: CGPoint(x: center.x - scoreSize.width / 2, y: center.y - scoreSize.height / 2),
            withAttributes: scoreAttrs
        )
    }

    private func drawHeatMapLegend(context: CGContext, colorScheme: DepthHeatMap.HeatMapColorScheme, minValue: Double, maxValue: Double) {
        let legendWidth: CGFloat = 300
        let legendHeight: CGFloat = 30
        let legendX = (pageSize.width - legendWidth) / 2

        // Draw gradient
        let colors = colorScheme.colors.map { $0.toUIColor().cgColor } as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!

        let startPoint = CGPoint(x: legendX, y: currentY)
        let endPoint = CGPoint(x: legendX + legendWidth, y: currentY)

        context.saveGState()
        context.addRect(CGRect(x: legendX, y: currentY, width: legendWidth, height: legendHeight))
        context.clip()
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        context.restoreGState()

        // Labels
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]

        String(format: "%.1f mm", minValue).draw(
            at: CGPoint(x: legendX, y: currentY + legendHeight + 5),
            withAttributes: labelAttrs
        )

        String(format: "%.1f mm", maxValue).draw(
            at: CGPoint(x: legendX + legendWidth - 40, y: currentY + legendHeight + 5),
            withAttributes: labelAttrs
        )

        currentY += legendHeight + 30
    }

    // MARK: - Image Generation

    private func generateHeatMapImage(_ heatMap: DepthHeatMap, minDepth: Double, maxDepth: Double) -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cellWidth = size.width / CGFloat(heatMap.gridSize.columns)
            let cellHeight = size.height / CGFloat(heatMap.gridSize.rows)

            for row in 0..<heatMap.gridSize.rows {
                for col in 0..<heatMap.gridSize.columns {
                    let depth = heatMap.dataPoints[row][col]
                    let color = heatMap.colorForDepth(depth, minDepth: minDepth, maxDepth: maxDepth).toUIColor()

                    let rect = CGRect(
                        x: CGFloat(col) * cellWidth,
                        y: CGFloat(row) * cellHeight,
                        width: cellWidth - 1,
                        height: cellHeight - 1
                    )

                    context.cgContext.setFillColor(color.cgColor)
                    context.cgContext.fill(rect)
                }
            }
        }
    }

    private func generateSummaryText(report: TyreAnalysisReport) -> String {
        return """
        This comprehensive tyre analysis report provides detailed insights into the condition and remaining life of your tyre. \
        The analysis reveals that your tyre has an average depth of \(String(format: "%.2f", report.depthAnalysis.average))mm, \
        with a \(report.wearAnalysis.pattern.description.lowercased()) wear pattern. \

        The overall safety score of \(Int(report.safetyScore.overall)) indicates \(report.safetyScore.rating.description.lowercased()). \
        Based on current wear rates and driving conditions, the estimated remaining life is approximately \(report.remainingLife.formattedDistance) \
        or \(report.remainingLife.estimatedMonths) months.

        Please review the detailed recommendations section for specific actions to maintain optimal tyre performance and safety.
        """
    }
}

// MARK: - Color Extensions

extension Color {
    func toUIColor() -> UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        } else {
            let components = self.cgColor?.components ?? [0, 0, 0, 1]
            return UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
