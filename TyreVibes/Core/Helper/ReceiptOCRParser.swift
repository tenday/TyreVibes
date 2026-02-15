import Foundation
import Vision
import UIKit

// MARK: - Parsed Receipt Data

struct ParsedReceiptData {
    var date: Date?
    var cost: Double?
    var workshopName: String?
    var mileage: Int?
    var maintenanceType: MaintenanceSchedule.MaintenanceType?
    var notes: String?
    var rawText: String
}

// MARK: - Error

enum ReceiptOCRError: LocalizedError {
    case invalidImage
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Impossibile elaborare l'immagine."
        case .ocrFailed(let msg): return "Errore OCR: \(msg)"
        }
    }
}

// MARK: - Receipt OCR Parser

struct ReceiptOCRParser {

    // MARK: - OCR

    static func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ReceiptOCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["it-IT", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parse

    static func parse(lines: [String]) -> ParsedReceiptData {
        let rawText = lines.joined(separator: "\n")
        var result = ParsedReceiptData(rawText: rawText)

        result.date = extractDate(from: lines)
        result.cost = extractCost(from: lines)
        result.workshopName = extractWorkshopName(from: lines)
        result.mileage = extractMileage(from: lines)
        result.maintenanceType = extractMaintenanceType(from: rawText)
        result.notes = extractNotes(from: lines)

        return result
    }

    // MARK: - Date Extraction

    private static func extractDate(from lines: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")

        let dateLines = lines.filter { $0.lowercased().contains("data") }
        let candidateLines = dateLines + lines

        for line in candidateLines {
            // DD/MM/YYYY or DD.MM.YYYY or DD-MM-YYYY
            if let match = line.range(of: #"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\b"#, options: .regularExpression) {
                let dateString = String(line[match])
                for format in ["dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yyyy"] {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }

            // "15 Gen 2026", "15 Gennaio 2026"
            let monthPattern = #"\b(\d{1,2})\s+(Gen(?:naio)?|Feb(?:braio)?|Mar(?:zo)?|Apr(?:ile)?|Mag(?:gio)?|Giu(?:gno)?|Lug(?:lio)?|Ago(?:sto)?|Set(?:tembre)?|Ott(?:obre)?|Nov(?:embre)?|Dic(?:embre)?)\s+(\d{4})\b"#
            if let match = line.range(of: monthPattern, options: [.regularExpression, .caseInsensitive]) {
                let dateString = String(line[match])
                for format in ["dd MMM yyyy", "dd MMMM yyyy"] {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Cost Extraction

    private static func extractCost(from lines: [String]) -> Double? {
        let costKeywords = ["totale", "tot.", "importo", "da pagare", "dovuto"]

        // First pass: lines with keywords
        for line in lines {
            let lower = line.lowercased()
            if costKeywords.contains(where: { lower.contains($0) }) {
                if let cost = extractCurrencyValue(from: line) {
                    return cost
                }
            }
        }

        // Second pass: any line with currency symbol (from bottom, total usually last)
        for line in lines.reversed() {
            if line.contains("€") || line.lowercased().contains("eur") {
                if let cost = extractCurrencyValue(from: line) {
                    return cost
                }
            }
        }

        return nil
    }

    private static func extractCurrencyValue(from text: String) -> Double? {
        let patterns = [
            #"€\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#,     // € 1.250,00
            #"€\s*(\d+,\d{2})"#,                        // € 150,00
            #"€\s*(\d+\.\d{2})"#,                       // € 150.00
            #"(\d{1,3}(?:\.\d{3})*,\d{2})\s*€"#,       // 1.250,00 €
            #"(\d+,\d{2})\s*€"#,                        // 150,00 €
            #"EUR\s*(\d+[,\.]\d{2})"#,                  // EUR 150,00
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: nsRange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                var numStr = String(text[range])
                // Italian format: 1.250,00 → 1250.00
                if numStr.contains(",") {
                    numStr = numStr.replacingOccurrences(of: ".", with: "")
                        .replacingOccurrences(of: ",", with: ".")
                }
                return Double(numStr)
            }
        }

        return nil
    }

    // MARK: - Workshop Name

    private static func extractWorkshopName(from lines: [String]) -> String? {
        guard !lines.isEmpty else { return nil }

        let skipPatterns = [
            #"P\.?\s*IVA"#, #"C\.?\s*F\.?"#, #"[Tt]el\.?"#, #"[Ff]ax"#,
            #"\d{5}"#,                          // CAP
            #"\d{2}[/.\-]\d{2}[/.\-]\d{4}"#,   // dates
            #"[Ff]attura"#, #"[Rr]icevuta"#, #"[Ss]contrino"#, #"[Nn]\.?\s*\d+"#
        ]

        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count >= 3 else { continue }

            let shouldSkip = skipPatterns.contains { pattern in
                trimmed.range(of: pattern, options: .regularExpression) != nil
            }

            if !shouldSkip {
                return trimmed
            }
        }

        return nil
    }

    // MARK: - Mileage

    private static func extractMileage(from lines: [String]) -> Int? {
        let mileagePatterns = [
            #"[Kk][Mm]\s*[:\.]?\s*(\d{1,3}(?:\.\d{3})*)"#,
            #"[Cc]hilometr\w+\s*[:\.]?\s*(\d{1,3}(?:\.\d{3})*)"#,
        ]

        for line in lines {
            for pattern in mileagePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsRange = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: nsRange),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: line) {
                    let numStr = String(line[range]).replacingOccurrences(of: ".", with: "")
                    if let km = Int(numStr), km >= 100 {
                        return km
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Maintenance Type Detection

    private static func extractMaintenanceType(from text: String) -> MaintenanceSchedule.MaintenanceType? {
        let lower = text.lowercased()

        let keywordMap: [(keywords: [String], type: MaintenanceSchedule.MaintenanceType)] = [
            // Tyres
            (["cambio gomme", "sostituzione pneumatic", "pneumatici nuov", "montaggio gomme"], .replacement),
            (["rotazione gomme", "rotazione pneumatic", "inversione gomme"], .rotation),
            (["pressione gomme", "pressione pneumatic", "gonfiaggio"], .pressureCheck),
            (["convergenza", "assetto ruote", "allineamento"], .alignment),
            (["cambio stagionale", "gomme invernali", "gomme estive", "pneumatici invernali", "pneumatici estivi"], .seasonalChange),
            (["equilibratura", "bilanciatura"], .balancing),
            // Filters (before engine to match "filtro olio" before "olio")
            (["filtro aria"], .airFilter),
            (["filtro olio"], .oilFilter),
            (["filtro carburante", "filtro gasolio", "filtro benzina"], .fuelFilter),
            (["filtro abitacolo", "filtro antipolline", "filtro clima", "filtro pollini"], .cabinFilter),
            // Engine
            (["cambio olio", "olio motore", "sostituzione olio"], .oilChange),
            (["candele", "candelette"], .sparkPlugs),
            (["cinghia distribuzione", "distribuzione", "cinghia servizi"], .timingBelt),
            (["frizione", "kit frizione", "disco frizione"], .clutch),
            (["tagliando", "manutenzione ordinaria", "check-up", "check up", "revisione generale"], .generalService),
            // Brakes
            (["pastiglie freno", "pastiglie", "pattini freno"], .brakePads),
            (["dischi freno", "disco freno"], .brakeDiscs),
            // Fluids
            (["liquido freni", "olio freni"], .brakeFluid),
            (["liquido raffreddamento", "antigelo", "refrigerante", "liquido radiatore"], .coolant),
            (["liquido tergicristall", "liquido lavavetri", "lavavetro"], .washerFluid),
            // Other
            (["batteria", "accumulatore"], .battery),
            (["ammortizzator", "sospension"], .shockAbsorbers),
        ]

        for entry in keywordMap {
            for keyword in entry.keywords {
                if lower.contains(keyword) {
                    return entry.type
                }
            }
        }

        return nil
    }

    // MARK: - Notes

    private static func extractNotes(from lines: [String]) -> String? {
        let descKeywords = ["lavoro", "descrizione", "intervento", "riparazione", "lavorazione", "manodopera"]
        var collecting = false
        var noteLines: [String] = []

        for line in lines {
            let lower = line.lowercased()
            if descKeywords.contains(where: { lower.contains($0) }) {
                collecting = true
                noteLines.append(line)
            } else if collecting {
                if lower.contains("totale") || lower.contains("iva") || lower.contains("subtotale") {
                    break
                }
                noteLines.append(line)
            }
        }

        let result = noteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
