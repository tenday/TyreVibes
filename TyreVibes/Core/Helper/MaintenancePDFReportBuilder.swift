import UIKit

enum MaintenancePDFReportBuilder {

    static func generateReport(entries: [CompletedMaintenanceEntry], vehicleId: Int) -> URL? {
        let pageWidth: CGFloat = 595.28  // A4
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "EUR"
        currencyFormatter.maximumFractionDigits = 2

        let sortedEntries = entries.sorted { $0.date > $1.date }
        let totalCost = entries.compactMap(\.cost).reduce(0, +)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            // Logo + Title
            let logoSize: CGFloat = 32
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let title = "Report Manutenzione Veicolo"
            if let logo = UIImage(named: "LogoImage") {
                let logoRect = CGRect(x: margin, y: yOffset, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
                let titleSize = title.size(withAttributes: titleAttrs)
                title.draw(
                    at: CGPoint(x: margin + logoSize + 10, y: yOffset + (logoSize - titleSize.height) / 2),
                    withAttributes: titleAttrs
                )
            } else {
                title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
            }
            yOffset += logoSize + 8

            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let dateStr = "Generato il \(dateFormatter.string(from: Date()))"
            dateStr.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttrs)
            yOffset += 28

            // Summary
            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let totalStr = "Totale speso: \(currencyFormatter.string(from: NSNumber(value: totalCost)) ?? "€0")"
            totalStr.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: summaryAttrs)
            yOffset += 20

            let countStr = "Interventi registrati: \(sortedEntries.count)"
            countStr.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttrs)
            yOffset += 30

            // Separator
            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 16

            // Table header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let columns: [(String, CGFloat)] = [
                ("Data", margin),
                ("Tipo", margin + 80),
                ("Titolo", margin + 170),
                ("Costo", margin + 350),
                ("Officina", margin + 420)
            ]
            for (header, x) in columns {
                header.draw(at: CGPoint(x: x, y: yOffset), withAttributes: headerAttrs)
            }
            yOffset += 18

            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 8

            // Table rows
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            for entry in sortedEntries {
                if yOffset > pageHeight - margin - 40 {
                    context.beginPage()
                    yOffset = margin
                }

                let date = dateFormatter.string(from: entry.date)
                let type = entry.maintenanceType?.localizedName ?? "-"
                let title = String(entry.title.prefix(25))
                let cost = entry.cost.flatMap { currencyFormatter.string(from: NSNumber(value: $0)) } ?? "-"
                let workshop = String((entry.workshopName ?? "-").prefix(18))

                let rowData: [(String, CGFloat)] = [
                    (date, margin),
                    (type, margin + 80),
                    (title, margin + 170),
                    (cost, margin + 350),
                    (workshop, margin + 420)
                ]

                for (text, x) in rowData {
                    text.draw(at: CGPoint(x: x, y: yOffset), withAttributes: rowAttrs)
                }
                yOffset += 16
            }
        }

        // Save to temp file
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "manutenzioni_\(dateStr).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ [MaintenancePDFReportBuilder] Error: \(error.localizedDescription)")
            return nil
        }
    }

    private static func drawLine(context: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + width, y: y))
        context.strokePath()
    }
}
