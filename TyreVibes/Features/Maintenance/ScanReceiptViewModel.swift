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

    func save() {
        let entryId = UUID().uuidString

        var attachmentIds: [String]?
        if let image = scannedImage {
            if let attachment = AttachmentManager.shared.addPhoto(image, for: entryId) {
                attachmentIds = [attachment.id]
            }
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost = Double(costText.replacingOccurrences(of: ",", with: "."))
        let cleanedWorkshop = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)

        MaintenanceHistoryStore.shared.addManualEntry(
            vehicleId: vehicleId,
            title: cleanedTitle,
            note: cleanedNote.isEmpty ? nil : cleanedNote,
            date: date,
            mileage: Int(mileageInput),
            maintenanceType: maintenanceType,
            cost: cost,
            workshopName: cleanedWorkshop.isEmpty ? nil : cleanedWorkshop,
            attachmentIds: attachmentIds
        )
    }
}
