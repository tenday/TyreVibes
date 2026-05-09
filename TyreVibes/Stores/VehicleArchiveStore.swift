import Foundation
import SwiftUI

struct VehicleArchiveDocument: Identifiable, Codable, Hashable {
    let id: String
    let vehicleId: Int
    let category: Category
    let title: String
    let note: String?
    let documentDate: Date
    let expiryDate: Date?
    let amount: Double?
    let linkedMaintenanceEntryId: String?
    let createdAt: Date

    enum Category: String, Codable, CaseIterable {
        case registration
        case insurance
        case tax
        case revision
        case maintenance
        case warranty
        case other

        var label: String {
            switch self {
            case .registration: return "Libretto"
            case .insurance: return "Assicurazione"
            case .tax: return "Bollo"
            case .revision: return "Revisione"
            case .maintenance: return "Manutenzione"
            case .warranty: return "Garanzia"
            case .other: return "Altro"
            }
        }

        var icon: String {
            switch self {
            case .registration: return "doc.text.fill"
            case .insurance: return "shield.lefthalf.filled"
            case .tax: return "eurosign.circle.fill"
            case .revision: return "checkmark.seal.fill"
            case .maintenance: return "wrench.and.screwdriver.fill"
            case .warranty: return "rosette"
            case .other: return "folder.fill"
            }
        }

        var color: Color {
            switch self {
            case .registration: return .cyan
            case .insurance: return .purple
            case .tax: return .teal
            case .revision: return .green
            case .maintenance: return .orange
            case .warranty: return .pink
            case .other: return .gray
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        vehicleId: Int,
        category: Category,
        title: String,
        note: String? = nil,
        documentDate: Date = Date(),
        expiryDate: Date? = nil,
        amount: Double? = nil,
        linkedMaintenanceEntryId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.category = category
        self.title = title
        self.note = note
        self.documentDate = documentDate
        self.expiryDate = expiryDate
        self.amount = amount
        self.linkedMaintenanceEntryId = linkedMaintenanceEntryId
        self.createdAt = createdAt
    }
}

@MainActor
final class VehicleArchiveStore: ObservableObject {
    static let shared = VehicleArchiveStore()

    @Published private(set) var documents: [VehicleArchiveDocument] = []

    private let storageKey = "vehicle_archive_documents"

    private init() {
        load()
    }

    func documents(for vehicleId: Int) -> [VehicleArchiveDocument] {
        documents
            .filter { $0.vehicleId == vehicleId }
            .sorted { lhs, rhs in
                if lhs.documentDate == rhs.documentDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.documentDate > rhs.documentDate
            }
    }

    func addDocument(
        id: String = UUID().uuidString,
        vehicleId: Int,
        category: VehicleArchiveDocument.Category,
        title: String,
        note: String?,
        documentDate: Date,
        expiryDate: Date?,
        amount: Double?,
        linkedMaintenanceEntryId: String?
    ) {
        let document = VehicleArchiveDocument(
            id: id,
            vehicleId: vehicleId,
            category: category,
            title: title,
            note: note,
            documentDate: documentDate,
            expiryDate: expiryDate,
            amount: amount,
            linkedMaintenanceEntryId: linkedMaintenanceEntryId
        )

        documents.append(document)
        save()
    }

    func deleteDocument(_ document: VehicleArchiveDocument) {
        documents.removeAll { $0.id == document.id }
        AttachmentManager.shared.deleteAttachments(for: document.id)
        save()
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(documents)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("❌ [VehicleArchiveStore] Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            documents = []
            return
        }

        do {
            documents = try JSONDecoder().decode([VehicleArchiveDocument].self, from: data)
        } catch {
            print("⚠️ [VehicleArchiveStore] Load error: \(error.localizedDescription)")
            documents = []
        }
    }
}
