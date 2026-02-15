import Foundation

enum MaintenanceCSVExporter {

    static func generateCSV(entries: [CompletedMaintenanceEntry]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        var csv = "Data,Tipo,Categoria,Titolo,Note,Km,Costo (€),Officina,Fonte\n"

        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let date = dateFormatter.string(from: entry.date)
            let type = entry.maintenanceType?.localizedName ?? ""
            let category = entry.maintenanceType?.category.rawValue ?? ""
            let title = escapeCSV(entry.title)
            let note = escapeCSV(entry.note ?? "")
            let mileage = entry.mileage.map { "\($0)" } ?? ""
            let cost = entry.cost.map { String(format: "%.2f", $0) } ?? ""
            let workshop = escapeCSV(entry.workshopName ?? "")
            let source = entry.source.label

            csv += "\(date),\(type),\(category),\(title),\(note),\(mileage),\(cost),\(workshop),\(source)\n"
        }

        return csv
    }

    static func exportToFile(entries: [CompletedMaintenanceEntry]) -> URL? {
        let csv = generateCSV(entries: entries)
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "manutenzioni_\(dateStr).csv"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ [MaintenanceCSVExporter] Error: \(error.localizedDescription)")
            return nil
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
