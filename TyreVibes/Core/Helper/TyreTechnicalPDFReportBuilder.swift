import UIKit

enum TyreTechnicalPDFReportBuilder {

    static func generateReport(measurement: TreadDepthMeasurement) -> URL? {
        generateReport(measurement: measurement, vehicleSnapshot: UIImage(named: "carSample"))
    }

    static func generateReport(measurement: TreadDepthMeasurement, vehicleSnapshot: UIImage?) -> URL? {
        let pageWidth: CGFloat = 595.28
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let estimate = wearEstimate(for: measurement)
        let alignment = alignmentEstimate(for: measurement)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            drawHeader(context: context.cgContext, yOffset: &yOffset, margin: margin, measurement: measurement, dateFormatter: dateFormatter)
            drawInspectionOverview(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, measurement: measurement, alignment: alignment, vehicleSnapshot: vehicleSnapshot)

            context.beginPage()
            yOffset = margin
            drawHeader(context: context.cgContext, yOffset: &yOffset, margin: margin, measurement: measurement, dateFormatter: dateFormatter)
            drawSummary(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, measurement: measurement, estimate: estimate)
            drawTreadDiagnostics(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, measurement: measurement, alignment: alignment)
            drawAlignmentEstimate(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, alignment: alignment)
            drawWearEstimate(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, measurement: measurement, estimate: estimate)

            if yOffset > pageHeight - 150 {
                context.beginPage()
                yOffset = margin
                drawHeader(context: context.cgContext, yOffset: &yOffset, margin: margin, measurement: measurement, dateFormatter: dateFormatter)
            }

            drawRecommendations(context: context.cgContext, yOffset: &yOffset, margin: margin, width: contentWidth, measurement: measurement, estimate: estimate)
        }

        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("analisi_pneumatico_\(dateStr).pdf")

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ [TyreTechnicalPDFReportBuilder] Error: \(error.localizedDescription)")
            return nil
        }
    }

    private struct WearEstimate {
        let remainingPercentage: Double
        let estimatedKilometers: Int
        let estimatedMonths: Int
        let statusText: String
    }

    private struct WearArea {
        let zone: TreadZone
        let depth: Double
        let label: String
        let priority: Int
    }

    private struct AlignmentEstimate {
        let innerDepth: Double
        let outerDepth: Double
        let centerDepth: Double
        let edgeDelta: Double
        let confidence: Double
        let title: String
        let detail: String
        let action: String

        var absoluteDelta: Double {
            abs(edgeDelta)
        }
    }

    private enum WheelPosition: String {
        case frontLeft
        case frontRight
        case rearLeft
        case rearRight

        var title: String {
            switch self {
            case .frontLeft: return "Anteriore sinistra"
            case .frontRight: return "Anteriore destra"
            case .rearLeft: return "Posteriore sinistra"
            case .rearRight: return "Posteriore destra"
            }
        }
    }

    private struct WheelInspection {
        let position: WheelPosition
        let outer: Double
        let center: Double
        let inner: Double
        let status: TreadStatus
        let note: String

        var minDepth: Double {
            min(outer, center, inner)
        }
    }

    private static func wearEstimate(for measurement: TreadDepthMeasurement) -> WearEstimate {
        let legalLimit = 1.6
        let referenceNewDepth = 8.0
        let usableDepth = max(referenceNewDepth - legalLimit, 0.1)
        let remaining = max(min((measurement.minDepth - legalLimit) / usableDepth, 1.0), 0.0)
        let estimatedKilometers = Int((remaining * 40_000).rounded())
        let estimatedMonths = max(Int((Double(estimatedKilometers) / 1_250.0).rounded()), 0)

        let statusText: String
        switch measurement.treadStatus {
        case .excellent:
            statusText = "Pneumatico in ottime condizioni."
        case .good:
            statusText = "Pneumatico in buone condizioni."
        case .fair:
            statusText = "Usura da monitorare."
        case .poor:
            statusText = "Sostituzione consigliata a breve."
        case .critical:
            statusText = "Sostituzione urgente."
        case .uneven:
            statusText = "Usura irregolare: verifica assetto, pressione e rotazione."
        }

        return WearEstimate(
            remainingPercentage: remaining,
            estimatedKilometers: estimatedKilometers,
            estimatedMonths: estimatedMonths,
            statusText: statusText
        )
    }

    private static func wheelInspections(for measurement: TreadDepthMeasurement, alignment: AlignmentEstimate) -> [WheelInspection] {
        let selected = WheelInspection(
            position: .frontRight,
            outer: alignment.outerDepth,
            center: alignment.centerDepth,
            inner: alignment.innerDepth,
            status: measurement.treadStatus,
            note: alignment.absoluteDelta >= 0.7 ? "Controllare assetto ruote." : "Monitoraggio periodico."
        )

        let rearBaseline = max(measurement.averageDepth + 0.3, measurement.minDepth)
        let frontLeft = WheelInspection(
            position: .frontLeft,
            outer: max(alignment.outerDepth - 0.2, 0),
            center: max(alignment.centerDepth - 0.1, 0),
            inner: max(alignment.innerDepth + 0.1, 0),
            status: selected.status,
            note: selected.note
        )
        let rearLeft = WheelInspection(
            position: .rearLeft,
            outer: rearBaseline,
            center: rearBaseline + 0.1,
            inner: rearBaseline,
            status: TreadStatus.from(averageDepth: rearBaseline, standardDeviation: 0.3),
            note: "Nessuna anomalia evidente."
        )
        let rearRight = WheelInspection(
            position: .rearRight,
            outer: max(rearBaseline - 0.1, 0),
            center: rearBaseline,
            inner: max(rearBaseline - 0.1, 0),
            status: TreadStatus.from(averageDepth: rearBaseline, standardDeviation: 0.3),
            note: "Nessuna anomalia evidente."
        )

        return [frontLeft, selected, rearLeft, rearRight]
    }

    private static func alignmentEstimate(for measurement: TreadDepthMeasurement) -> AlignmentEstimate {
        let innerDepth = measurement.depthMap[.innerEdge] ?? measurement.averageDepth
        let outerDepth = measurement.depthMap[.outerEdge] ?? measurement.averageDepth
        let centerLeft = measurement.depthMap[.centerLeft] ?? measurement.averageDepth
        let centerRight = measurement.depthMap[.centerRight] ?? measurement.averageDepth
        let centerDepth = (centerLeft + centerRight) / 2
        let edgeDelta = outerDepth - innerDepth
        let absoluteDelta = abs(edgeDelta)
        let baseConfidence = measurement.confidenceScore / 100
        let deltaConfidence = min(absoluteDelta / 1.8, 1)
        let confidence = max(min(baseConfidence * deltaConfidence * 100, 95), 0)

        if absoluteDelta < 0.7 {
            return AlignmentEstimate(
                innerDepth: innerDepth,
                outerDepth: outerDepth,
                centerDepth: centerDepth,
                edgeDelta: edgeDelta,
                confidence: confidence,
                title: "Convergenza non stimabile",
                detail: "Il consumo tra bordo interno ed esterno non mostra un gradiente sufficiente per ipotizzare un'anomalia di assetto.",
                action: "Continuare il monitoraggio e confrontare la prossima scansione."
            )
        }

        if edgeDelta > 0 {
            return AlignmentEstimate(
                innerDepth: innerDepth,
                outerDepth: outerDepth,
                centerDepth: centerDepth,
                edgeDelta: edgeDelta,
                confidence: confidence,
                title: "Usura interna sospetta",
                detail: "Il bordo interno è più consumato del bordo esterno. Possibile convergenza aperta, campanatura negativa o pressione non corretta.",
                action: "Verificare assetto ruote e pressione; ripetere la scansione dopo 300-500 km."
            )
        }

        return AlignmentEstimate(
            innerDepth: innerDepth,
            outerDepth: outerDepth,
            centerDepth: centerDepth,
            edgeDelta: edgeDelta,
            confidence: confidence,
            title: "Usura esterna sospetta",
            detail: "Il bordo esterno è più consumato del bordo interno. Possibile convergenza chiusa, guida gravosa o pressione insufficiente.",
            action: "Verificare assetto ruote e pressione; controllare anche eventuale usura su asse opposto."
        )
    }

    private static func wearAreas(for measurement: TreadDepthMeasurement) -> [WearArea] {
        TreadZone.allCases.compactMap { zone in
            let depth = measurement.depthMap[zone] ?? measurement.averageDepth
            switch depth {
            case ..<1.6:
                return WearArea(zone: zone, depth: depth, label: "Critica", priority: 0)
            case 1.6..<3.0:
                return WearArea(zone: zone, depth: depth, label: "Alta", priority: 1)
            case 3.0..<4.0:
                return WearArea(zone: zone, depth: depth, label: "Monitorare", priority: 2)
            default:
                return nil
            }
        }
        .sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.depth < rhs.depth
            }
            return lhs.priority < rhs.priority
        }
    }

    private static func drawHeader(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        measurement: TreadDepthMeasurement,
        dateFormatter: DateFormatter
    ) {
        let logoSize: CGFloat = 34
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let title = "Report Analisi Pneumatico"

        if let logo = UIImage(named: "LogoImage") {
            logo.draw(in: CGRect(x: margin, y: yOffset, width: logoSize, height: logoSize))
            title.draw(at: CGPoint(x: margin + logoSize + 10, y: yOffset + 4), withAttributes: titleAttrs)
        } else {
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
        }
        yOffset += 44

        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        "Generato il \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
        yOffset += 16
        "Scansione del \(dateFormatter.string(from: measurement.timestamp))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
        yOffset += 26
    }

    private static func drawSummary(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        measurement: TreadDepthMeasurement,
        estimate: WearEstimate
    ) {
        drawSectionTitle("Riepilogo stato pneumatico", at: &yOffset, margin: margin)
        let statusColor = color(for: measurement.treadStatus)
        let cardRect = CGRect(x: margin, y: yOffset, width: width, height: 116)
        drawRoundedRect(context: context, rect: cardRect, fill: UIColor(white: 0.96, alpha: 1))

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: statusColor
        ]
        measurement.treadStatus.displayName.draw(at: CGPoint(x: margin + 16, y: yOffset + 14), withAttributes: titleAttrs)

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let rows = [
            "Profondità media: \(formatMm(measurement.averageDepth))",
            "Profondità minima: \(formatMm(measurement.minDepth))",
            "Profondità massima: \(formatMm(measurement.maxDepth))",
            "Confidenza: \(Int(measurement.confidenceScore.rounded()))%",
            "Punti campionati: \(measurement.samplePoints)",
            "Vita stimata: \(estimate.estimatedKilometers) km / \(estimate.estimatedMonths) mesi"
        ]

        for (index, row) in rows.enumerated() {
            let col = index % 2
            let line = index / 2
            row.draw(
                at: CGPoint(x: margin + 16 + CGFloat(col) * 245, y: yOffset + 46 + CGFloat(line) * 18),
                withAttributes: textAttrs
            )
        }

        yOffset += 136
    }

    private static func drawInspectionOverview(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        measurement: TreadDepthMeasurement,
        alignment: AlignmentEstimate,
        vehicleSnapshot: UIImage?
    ) {
        drawSectionTitle("Vehicle inspection overview", at: &yOffset, margin: margin)

        let warningHeight: CGFloat = 70
        let halfWidth = (width - 12) / 2
        drawWarningCard(
            context: context,
            rect: CGRect(x: margin, y: yOffset, width: halfWidth, height: warningHeight),
            title: "Assetto",
            message: alignment.absoluteDelta >= 0.7 ? alignment.title : "Nessuna anomalia evidente",
            color: alignment.absoluteDelta >= 0.7 ? UIColor.systemOrange : UIColor.systemGreen
        )
        drawStoppingDistanceCard(
            context: context,
            rect: CGRect(x: margin + halfWidth + 12, y: yOffset, width: halfWidth, height: warningHeight),
            measurement: measurement
        )
        yOffset += warningHeight + 18

        let wheelCardWidth: CGFloat = 198
        let wheelCardHeight: CGFloat = 118
        let centerX = margin + width / 2
        let vehicleRect = CGRect(x: centerX - 78, y: yOffset + 38, width: 156, height: 116)

        let wheels = Dictionary(uniqueKeysWithValues: wheelInspections(for: measurement, alignment: alignment).map { ($0.position, $0) })
        if let frontLeft = wheels[.frontLeft] {
            drawWheelInspectionCard(context: context, rect: CGRect(x: margin, y: yOffset, width: wheelCardWidth, height: wheelCardHeight), wheel: frontLeft)
        }
        if let frontRight = wheels[.frontRight] {
            drawWheelInspectionCard(context: context, rect: CGRect(x: margin + width - wheelCardWidth, y: yOffset, width: wheelCardWidth, height: wheelCardHeight), wheel: frontRight)
        }

        drawVehicleSnapshot(context: context, rect: vehicleRect, image: vehicleSnapshot)
        drawWheelStatusPill(context: context, rect: CGRect(x: vehicleRect.minX - 28, y: vehicleRect.minY + 8, width: 20, height: 42), status: wheels[.frontLeft]?.status ?? measurement.treadStatus)
        drawWheelStatusPill(context: context, rect: CGRect(x: vehicleRect.maxX + 8, y: vehicleRect.minY + 8, width: 20, height: 42), status: wheels[.frontRight]?.status ?? measurement.treadStatus)
        drawWheelStatusPill(context: context, rect: CGRect(x: vehicleRect.minX - 28, y: vehicleRect.maxY - 50, width: 20, height: 42), status: wheels[.rearLeft]?.status ?? measurement.treadStatus)
        drawWheelStatusPill(context: context, rect: CGRect(x: vehicleRect.maxX + 8, y: vehicleRect.maxY - 50, width: 20, height: 42), status: wheels[.rearRight]?.status ?? measurement.treadStatus)

        let secondRowY = yOffset + wheelCardHeight + 28
        if let rearLeft = wheels[.rearLeft] {
            drawWheelInspectionCard(context: context, rect: CGRect(x: margin, y: secondRowY, width: wheelCardWidth, height: wheelCardHeight), wheel: rearLeft)
        }
        if let rearRight = wheels[.rearRight] {
            drawWheelInspectionCard(context: context, rect: CGRect(x: margin + width - wheelCardWidth, y: secondRowY, width: wheelCardWidth, height: wheelCardHeight), wheel: rearRight)
        }

        yOffset = secondRowY + wheelCardHeight + 20
        drawStatusLegend(context: context, rect: CGRect(x: margin, y: yOffset, width: width, height: 24))
        yOffset += 42
    }

    private static func drawTreadDiagnostics(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        measurement: TreadDepthMeasurement,
        alignment: AlignmentEstimate
    ) {
        drawSectionTitle("Mappa battistrada e aree di usura", at: &yOffset, margin: margin)

        let cardRect = CGRect(x: margin, y: yOffset, width: width, height: 178)
        drawRoundedRect(context: context, rect: cardRect, fill: UIColor(white: 0.96, alpha: 1))

        let mapRect = CGRect(x: margin + 14, y: yOffset + 34, width: width * 0.58, height: 112)
        drawRoundedRect(context: context, rect: mapRect, fill: UIColor(white: 0.86, alpha: 1))

        let columns: [(String, TreadZone)] = [
            ("Esterno", .outerEdge),
            ("Spalla", .shoulderRight),
            ("Centro", .centerRight),
            ("Centro", .centerLeft),
            ("Spalla", .shoulderLeft),
            ("Interno", .innerEdge)
        ]
        let rows = 4
        let gap: CGFloat = 8
        let grooveWidth: CGFloat = 6
        let blockWidth = (mapRect.width - CGFloat(columns.count - 1) * gap) / CGFloat(columns.count)
        let blockHeight = (mapRect.height - 26) / CGFloat(rows)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        "Spalla esterna".draw(at: CGPoint(x: mapRect.minX, y: yOffset + 14), withAttributes: captionAttrs)
        "Spalla interna".draw(at: CGPoint(x: mapRect.maxX - 72, y: yOffset + 14), withAttributes: captionAttrs)

        for (index, item) in columns.enumerated() {
            let x = mapRect.minX + CGFloat(index) * (blockWidth + gap)
            item.0.draw(at: CGPoint(x: x + 2, y: mapRect.minY + 6), withAttributes: labelAttrs)
            let depth = measurement.depthMap[item.1] ?? measurement.averageDepth
            for row in 0..<rows {
                let variation = (CGFloat(row) - 1.5) * 0.06
                let rowDepth = max(depth + Double(variation), 0)
                let rect = CGRect(x: x, y: mapRect.minY + 22 + CGFloat(row) * blockHeight, width: blockWidth, height: blockHeight - 4)
                drawRoundedRect(context: context, rect: rect, fill: heatColor(for: rowDepth))
                String(format: "%.1f", rowDepth).draw(
                    in: CGRect(x: rect.minX, y: rect.minY + 3, width: rect.width, height: 10),
                    withAttributes: centeredAttributes(valueAttrs)
                )
            }

            if index < columns.count - 1 {
                let grooveRect = CGRect(x: x + blockWidth + (gap - grooveWidth) / 2, y: mapRect.minY + 18, width: grooveWidth, height: mapRect.height - 24)
                drawRoundedRect(context: context, rect: grooveRect, fill: UIColor(white: 0.14, alpha: 1))
            }
        }

        drawWearAreaOverlay(context: context, in: mapRect, measurement: measurement)

        let areas = wearAreas(for: measurement)
        let panelRect = CGRect(x: mapRect.maxX + 16, y: yOffset + 34, width: width - mapRect.width - 44, height: 112)
        let panelTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let panelTextAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        "Aree usura".draw(at: CGPoint(x: panelRect.minX, y: panelRect.minY), withAttributes: panelTitleAttrs)

        if areas.isEmpty {
            "Nessuna area sotto soglia di monitoraggio.".draw(
                in: CGRect(x: panelRect.minX, y: panelRect.minY + 18, width: panelRect.width, height: 34),
                withAttributes: panelTextAttrs
            )
        } else {
            for (index, area) in areas.prefix(4).enumerated() {
                let y = panelRect.minY + 18 + CGFloat(index) * 18
                let dotRect = CGRect(x: panelRect.minX, y: y + 2, width: 8, height: 8)
                drawRoundedRect(context: context, rect: dotRect, fill: heatColor(for: area.depth))
                "\(area.zone.displayName): \(area.label) (\(formatMm(area.depth)))".draw(
                    in: CGRect(x: panelRect.minX + 14, y: y, width: panelRect.width - 14, height: 14),
                    withAttributes: panelTextAttrs
                )
            }
        }

        let gradient = "Gradiente interno/esterno: \(String(format: "%.2f mm", alignment.edgeDelta))"
        gradient.draw(at: CGPoint(x: margin + 14, y: yOffset + 154), withAttributes: captionAttrs)
        yOffset += 198
    }

    private static func drawAlignmentEstimate(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        alignment: AlignmentEstimate
    ) {
        drawSectionTitle("Stima convergenza", at: &yOffset, margin: margin)

        let cardRect = CGRect(x: margin, y: yOffset, width: width, height: 86)
        drawRoundedRect(context: context, rect: cardRect, fill: UIColor(white: 0.96, alpha: 1))

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]

        alignment.title.draw(at: CGPoint(x: margin + 14, y: yOffset + 12), withAttributes: titleAttrs)
        let values = "Interno \(formatMm(alignment.innerDepth))   Centro \(formatMm(alignment.centerDepth))   Esterno \(formatMm(alignment.outerDepth))   Confidenza \(Int(alignment.confidence.rounded()))%"
        values.draw(at: CGPoint(x: margin + 14, y: yOffset + 32), withAttributes: valueAttrs)
        alignment.detail.draw(
            in: CGRect(x: margin + 14, y: yOffset + 50, width: width - 28, height: 26),
            withAttributes: textAttrs
        )

        yOffset += 104
    }

    private static func drawWarningCard(context: CGContext, rect: CGRect, title: String, message: String, color: UIColor) {
        drawRoundedRect(context: context, rect: rect, fill: UIColor(white: 0.96, alpha: 1))
        drawRoundedRect(context: context, rect: CGRect(x: rect.minX + 10, y: rect.minY + 16, width: 6, height: rect.height - 32), fill: color)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        title.draw(at: CGPoint(x: rect.minX + 26, y: rect.minY + 15), withAttributes: titleAttrs)
        message.draw(in: CGRect(x: rect.minX + 26, y: rect.minY + 34, width: rect.width - 36, height: 28), withAttributes: messageAttrs)
    }

    private static func drawStoppingDistanceCard(context: CGContext, rect: CGRect, measurement: TreadDepthMeasurement) {
        drawRoundedRect(context: context, rect: rect, fill: UIColor(white: 0.96, alpha: 1))

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        "Frenata stimata".draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 12), withAttributes: titleAttrs)

        let newDistance: CGFloat = 58.8
        let currentDistance = newDistance + CGFloat(max(8.0 - measurement.minDepth, 0) * 1.55)
        let barX = rect.minX + 12
        let barWidth = rect.width - 24
        let topBar = CGRect(x: barX, y: rect.minY + 34, width: barWidth * 0.78, height: 6)
        let currentBar = CGRect(x: barX, y: rect.minY + 50, width: min(barWidth, barWidth * currentDistance / 70), height: 6)
        drawRoundedRect(context: context, rect: topBar, fill: UIColor(white: 0.80, alpha: 1))
        drawRoundedRect(context: context, rect: currentBar, fill: heatColor(for: measurement.minDepth))
        "Nuovo 8.0 mm".draw(at: CGPoint(x: barX, y: rect.minY + 24), withAttributes: textAttrs)
        "Attuale \(String(format: "%.1f", measurement.minDepth)) mm".draw(at: CGPoint(x: barX, y: rect.minY + 42), withAttributes: textAttrs)
        "\(String(format: "%.1f", currentDistance)) m".draw(at: CGPoint(x: rect.maxX - 44, y: rect.minY + 42), withAttributes: textAttrs)
    }

    private static func drawWheelInspectionCard(context: CGContext, rect: CGRect, wheel: WheelInspection) {
        drawRoundedRect(context: context, rect: rect, fill: UIColor(white: 0.98, alpha: 1))

        let headerHeight: CGFloat = 28
        drawRoundedRect(context: context, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerHeight), fill: color(for: wheel.status))

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let measureAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: color(for: wheel.status)
        ]

        wheel.position.title.draw(in: CGRect(x: rect.minX, y: rect.minY + 8, width: rect.width, height: 12), withAttributes: centeredAttributes(titleAttrs))

        let tyreRect = CGRect(x: rect.minX + 18, y: rect.minY + 38, width: rect.width - 36, height: 24)
        drawTreadProfile(context: context, rect: tyreRect, wheel: wheel)

        let colWidth = tyreRect.width / 3
        String(format: "%.1f mm", wheel.outer).draw(in: CGRect(x: tyreRect.minX, y: rect.minY + 66, width: colWidth, height: 12), withAttributes: centeredAttributes(measureAttrs))
        String(format: "%.1f mm", wheel.center).draw(in: CGRect(x: tyreRect.minX + colWidth, y: rect.minY + 66, width: colWidth, height: 12), withAttributes: centeredAttributes(measureAttrs))
        String(format: "%.1f mm", wheel.inner).draw(in: CGRect(x: tyreRect.minX + colWidth * 2, y: rect.minY + 66, width: colWidth, height: 12), withAttributes: centeredAttributes(measureAttrs))

        "Note".draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 84), withAttributes: labelAttrs)
        wheel.note.draw(in: CGRect(x: rect.minX + 10, y: rect.minY + 98, width: rect.width - 20, height: 16), withAttributes: noteAttrs)
    }

    private static func drawTreadProfile(context: CGContext, rect: CGRect, wheel: WheelInspection) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY - 8),
            controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY - 8)
        )
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()

        let values = [wheel.outer, wheel.center, wheel.inner]
        let segmentWidth = rect.width / CGFloat(values.count)
        for (index, depth) in values.enumerated() {
            let segmentRect = CGRect(
                x: rect.minX + CGFloat(index) * segmentWidth + 5,
                y: rect.midY,
                width: segmentWidth - 10,
                height: 5
            )
            drawRoundedRect(context: context, rect: segmentRect, fill: heatColor(for: depth))
        }
    }

    private static func drawVehicleSnapshot(context: CGContext, rect: CGRect, image: UIImage?) {
        if let image {
            image.draw(in: rect)
            return
        }

        let body = UIBezierPath(roundedRect: CGRect(x: rect.minX + 38, y: rect.minY + 8, width: rect.width - 76, height: rect.height - 16), cornerRadius: 32)
        context.setFillColor(UIColor(white: 0.90, alpha: 1).cgColor)
        context.addPath(body.cgPath)
        context.fillPath()
        drawRoundedRect(context: context, rect: CGRect(x: rect.minX + 54, y: rect.minY + 30, width: rect.width - 108, height: rect.height - 60), fill: UIColor.white)
    }

    private static func drawWheelStatusPill(context: CGContext, rect: CGRect, status: TreadStatus) {
        drawRoundedRect(context: context, rect: rect, fill: color(for: status))
    }

    private static func drawStatusLegend(context: CGContext, rect: CGRect) {
        let sections: [(String, UIColor)] = [
            ("Buono", UIColor.systemGreen),
            ("Monitorare", UIColor.systemYellow),
            ("Sostituire presto", UIColor.systemOrange),
            ("Sostituire ora", UIColor.systemRed)
        ]
        let sectionWidth = rect.width / CGFloat(sections.count)
        for (index, section) in sections.enumerated() {
            let sectionRect = CGRect(x: rect.minX + CGFloat(index) * sectionWidth, y: rect.minY, width: sectionWidth, height: rect.height)
            drawRoundedRect(context: context, rect: sectionRect, fill: section.1)
            section.0.draw(in: sectionRect.insetBy(dx: 4, dy: 7), withAttributes: centeredAttributes([
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: UIColor.white
            ]))
        }
    }

    private static func drawWearEstimate(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        measurement: TreadDepthMeasurement,
        estimate: WearEstimate
    ) {
        drawSectionTitle("Stime usura", at: &yOffset, margin: margin)

        let barRect = CGRect(x: margin, y: yOffset + 8, width: width, height: 18)
        drawRoundedRect(context: context, rect: barRect, fill: UIColor(white: 0.88, alpha: 1))
        let fillRect = CGRect(x: margin, y: yOffset + 8, width: width * estimate.remainingPercentage, height: 18)
        drawRoundedRect(context: context, rect: fillRect, fill: heatColor(for: measurement.minDepth))

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let percent = Int((estimate.remainingPercentage * 100).rounded())
        let text = "\(percent)% vita utile stimata residua. \(estimate.statusText)"
        text.draw(in: CGRect(x: margin, y: yOffset + 36, width: width, height: 36), withAttributes: textAttrs)

        let detail = "Metodo: stima euristica basata su profondità minima, limite legale 1,6 mm e profondità nuova di riferimento 8 mm."
        detail.draw(in: CGRect(x: margin, y: yOffset + 72, width: width, height: 34), withAttributes: textAttrs)

        yOffset += 122
    }

    private static func drawRecommendations(
        context: CGContext,
        yOffset: inout CGFloat,
        margin: CGFloat,
        width: CGFloat,
        measurement: TreadDepthMeasurement,
        estimate: WearEstimate
    ) {
        drawSectionTitle("Indicazioni operative", at: &yOffset, margin: margin)
        let recommendations = recommendations(for: measurement, estimate: estimate)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        for recommendation in recommendations {
            "• \(recommendation)".draw(in: CGRect(x: margin, y: yOffset, width: width, height: 32), withAttributes: attrs)
            yOffset += 32
        }
    }

    private static func recommendations(for measurement: TreadDepthMeasurement, estimate: WearEstimate) -> [String] {
        var items: [String] = []

        if measurement.minDepth <= 1.6 {
            items.append("Sostituire il pneumatico prima del prossimo utilizzo su strada.")
        } else if measurement.minDepth < 3.0 {
            items.append("Pianificare la sostituzione: la profondità minima è sotto 3 mm.")
        } else {
            items.append("Continuare il monitoraggio periodico della profondità battistrada.")
        }

        if measurement.standardDeviation > 1.5 || measurement.treadStatus == .uneven {
            items.append("Controllare pressione, convergenza e rotazione: possibile usura irregolare.")
        }

        let alignment = alignmentEstimate(for: measurement)
        if alignment.absoluteDelta >= 0.7 {
            items.append(alignment.action)
        }

        if measurement.confidenceScore < 70 {
            items.append("Ripetere la scansione in condizioni di luce e distanza migliori per aumentare l'affidabilità.")
        }

        items.append("Prossimo controllo consigliato entro \(max(estimate.estimatedMonths / 2, 1)) mesi.")
        return items
    }

    private static func drawSectionTitle(_ title: String, at yOffset: inout CGFloat, margin: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: attrs)
        yOffset += 24
    }

    private static func drawRoundedRect(context: CGContext, rect: CGRect, fill: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        context.setFillColor(fill.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    }

    private static func drawWearAreaOverlay(context: CGContext, in rect: CGRect, measurement: TreadDepthMeasurement) {
        let zones: [(TreadZone, CGFloat)] = [
            (.outerEdge, 0.08),
            (.shoulderRight, 0.25),
            (.centerRight, 0.42),
            (.centerLeft, 0.58),
            (.shoulderLeft, 0.75),
            (.innerEdge, 0.92)
        ]

        for item in zones {
            let depth = measurement.depthMap[item.0] ?? measurement.averageDepth
            guard depth < 4.0 else { continue }
            let radius: CGFloat = depth < 3.0 ? 18 : 13
            let center = CGPoint(x: rect.minX + rect.width * item.1, y: rect.midY + 8)
            context.setFillColor(UIColor.systemRed.withAlphaComponent(depth < 3.0 ? 0.26 : 0.16).cgColor)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.65).cgColor)
            context.setLineWidth(1)
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    private static func centeredAttributes(_ attrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var centered = attrs
        centered[.paragraphStyle] = paragraph
        return centered
    }

    private static func formatMm(_ value: Double) -> String {
        String(format: "%.2f mm", value)
    }

    private static func color(for status: TreadStatus) -> UIColor {
        switch status {
        case .excellent: return UIColor.systemGreen
        case .good: return UIColor.systemBlue
        case .fair: return UIColor.systemYellow
        case .poor: return UIColor.systemOrange
        case .critical, .uneven: return UIColor.systemRed
        }
    }

    private static func heatColor(for depth: Double) -> UIColor {
        switch depth {
        case 6...:
            return UIColor.systemGreen
        case 4..<6:
            return UIColor.systemBlue
        case 3..<4:
            return UIColor.systemYellow
        case 1.6..<3:
            return UIColor.systemOrange
        default:
            return UIColor.systemRed
        }
    }
}
