import Foundation
import SwiftUI
import UIKit

@MainActor
class ScanReceiptViewModel: ObservableObject {
    let vehicleId: Int

    // MARK: - Image Capture

    @Published var showImagePicker = false
    @Published var imagePickerSource: ImagePickerView.Source = .camera
    @Published var scannedImage: UIImage?
    @Published var showLiveScanner = false

    // MARK: - OCR State

    @Published var isProcessing = false
    @Published var ocrCompleted = false
    @Published var errorMessage: String?

    // MARK: - Editable Form Fields

    @Published var maintenanceType: MaintenanceSchedule.MaintenanceType = .generalService
    @Published var title: String = ""
    @Published var note: String = ""
    @Published var date: Date = Date()
    @Published var mileageInput: String = ""
    @Published var costText: String = ""
    @Published var workshopName: String = ""

    // MARK: - Raw OCR

    @Published var rawOCRText: String = ""

    // MARK: - Computed

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && scannedImage != nil
    }

    // MARK: - Init

    init(vehicleId: Int) {
        self.vehicleId = vehicleId
    }

    // MARK: - Image Picked

    func handleImagePicked(_ image: UIImage) {
        scannedImage = image
        showImagePicker = false
        showLiveScanner = false
        Task {
            await processOCR(image: image)
        }
    }

    // MARK: - OCR Processing

    func processOCR(image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let lines = try await ReceiptOCRParser.recognizeText(from: image)
            let parsed = ReceiptOCRParser.parse(lines: lines)

            rawOCRText = parsed.rawText

            if let parsedDate = parsed.date {
                date = parsedDate
            }
            if let cost = parsed.cost {
                costText = String(format: "%.2f", cost).replacingOccurrences(of: ".", with: ",")
            }
            if let workshop = parsed.workshopName {
                workshopName = workshop
            }
            if let km = parsed.mileage {
                mileageInput = "\(km)"
            }
            if let type = parsed.maintenanceType {
                maintenanceType = type
                title = type.localizedName
            }
            if let notes = parsed.notes {
                note = notes
            }

            if title.isEmpty {
                title = workshopName.isEmpty ? "Manutenzione" : "Manutenzione - \(workshopName)"
            }

            ocrCompleted = true
        } catch {
            errorMessage = error.localizedDescription
            ocrCompleted = true
        }

        isProcessing = false
    }

    // MARK: - Save

    func save() -> Bool {
        errorMessage = nil

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scannedImage else {
            errorMessage = "Aggiungi prima una scansione della ricevuta."
            return false
        }

        guard !cleanedTitle.isEmpty else {
            errorMessage = "Inserisci un titolo prima di salvare."
            return false
        }

        let mileage: Int?
        if mileageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mileage = nil
        } else if let parsedMileage = parseLocalizedInt(mileageInput) {
            mileage = parsedMileage
        } else {
            errorMessage = "Inserisci un valore di chilometri valido."
            return false
        }

        let entryId = UUID().uuidString

        var attachmentIds: [String]?
        if let attachment = AttachmentManager.shared.addPhoto(scannedImage, for: entryId) {
            attachmentIds = [attachment.id]
        }

        let cost: Double?
        if costText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cost = nil
        } else if let parsedCost = parseLocalizedDecimal(costText) {
            cost = parsedCost
        } else {
            errorMessage = "Inserisci un costo valido."
            return false
        }
        let cleanedWorkshop = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)

        MaintenanceHistoryStore.shared.addManualEntry(
            id: entryId,
            vehicleId: vehicleId,
            title: cleanedTitle,
            note: cleanedNote.isEmpty ? nil : cleanedNote,
            date: date,
            mileage: mileage,
            maintenanceType: maintenanceType,
            cost: cost,
            workshopName: cleanedWorkshop.isEmpty ? nil : cleanedWorkshop,
            attachmentIds: attachmentIds
        )

        return true
    }

    private func parseLocalizedInt(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")

        let allowed = trimmed.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
        guard allowed == trimmed else { return nil }
        guard !sanitized.isEmpty else { return nil }
        return Int(sanitized)
    }

    private func parseLocalizedDecimal(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let removedWhitespace = trimmed.replacingOccurrences(of: " ", with: "")
        let allowed = removedWhitespace.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !allowed.isEmpty else { return nil }
        guard allowed.count == removedWhitespace.count else { return nil }

        let separatorsCount = allowed.filter { $0 == "." || $0 == "," }.count
        let normalized: String
        if separatorsCount == 0 {
            normalized = allowed
        } else if separatorsCount >= 1 {
            let decimalIndex = allowed.lastIndex(of: ".") ?? allowed.lastIndex(of: ",")
            if let decimalIndex {
                let integerPart = String(allowed[..<decimalIndex]).filter(\.isNumber)
                let decimalPart = String(allowed[allowed.index(after: decimalIndex)...]).filter(\.isNumber)

                if integerPart.isEmpty && decimalPart.isEmpty { return nil }
                normalized = "\(integerPart).\(decimalPart)"
            } else {
                return nil
            }
        } else {
            return nil
        }

        return Double(normalized)
    }
}
