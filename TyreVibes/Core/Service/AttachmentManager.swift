import Foundation
import UIKit

@MainActor
final class AttachmentManager: ObservableObject {
    static let shared = AttachmentManager()

    struct Attachment: Identifiable, Codable, Hashable {
        let id: String
        let entryId: String
        let type: AttachmentType
        let fileName: String
        let fileSize: Int
        let createdAt: Date
        let thumbnailData: Data?
    }

    enum AttachmentType: String, Codable {
        case photo
        case pdf
    }

    @Published private(set) var attachments: [Attachment] = []

    private let storageKey = "maintenance_attachments"
    private let fileManager = FileManager.default

    private var storageDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MaintenanceAttachments")
    }

    private init() {
        ensureDirectoryExists()
        load()
    }

    // MARK: - Public API

    func attachments(for entryId: String) -> [Attachment] {
        attachments.filter { $0.entryId == entryId }
    }

    func addPhoto(_ image: UIImage, for entryId: String) -> Attachment? {
        guard let resized = resizeImage(image, maxDimension: 1200),
              let data = resized.jpegData(compressionQuality: 0.8) else { return nil }

        let id = UUID().uuidString
        let fileName = "\(id).jpg"
        let thumbnailData = resizeImage(image, maxDimension: 200)?.jpegData(compressionQuality: 0.6)

        let entryDir = storageDirectory.appendingPathComponent(entryId)
        ensureDirectoryExists(at: entryDir)

        let fileURL = entryDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ [AttachmentManager] Failed to save photo: \(error.localizedDescription)")
            return nil
        }

        let attachment = Attachment(
            id: id,
            entryId: entryId,
            type: .photo,
            fileName: fileName,
            fileSize: data.count,
            createdAt: Date(),
            thumbnailData: thumbnailData
        )

        attachments.append(attachment)
        save()
        return attachment
    }

    func addPDF(_ data: Data, fileName: String, for entryId: String) -> Attachment? {
        let id = UUID().uuidString
        let safeFileName = "\(id)_\(fileName)"

        let entryDir = storageDirectory.appendingPathComponent(entryId)
        ensureDirectoryExists(at: entryDir)

        let fileURL = entryDir.appendingPathComponent(safeFileName)
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ [AttachmentManager] Failed to save PDF: \(error.localizedDescription)")
            return nil
        }

        let attachment = Attachment(
            id: id,
            entryId: entryId,
            type: .pdf,
            fileName: safeFileName,
            fileSize: data.count,
            createdAt: Date(),
            thumbnailData: nil
        )

        attachments.append(attachment)
        save()
        return attachment
    }

    func deleteAttachment(_ attachmentId: String) {
        guard let attachment = attachments.first(where: { $0.id == attachmentId }) else { return }

        let fileURL = storageDirectory
            .appendingPathComponent(attachment.entryId)
            .appendingPathComponent(attachment.fileName)

        try? fileManager.removeItem(at: fileURL)
        attachments.removeAll { $0.id == attachmentId }
        save()
    }

    func fileURL(for attachment: Attachment) -> URL {
        storageDirectory
            .appendingPathComponent(attachment.entryId)
            .appendingPathComponent(attachment.fileName)
    }

    func thumbnail(for attachment: Attachment) -> UIImage? {
        if let data = attachment.thumbnailData {
            return UIImage(data: data)
        }
        return nil
    }

    func loadFullImage(for attachment: Attachment) -> UIImage? {
        guard attachment.type == .photo else { return nil }
        let url = fileURL(for: attachment)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Private

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        if ratio >= 1.0 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    private func ensureDirectoryExists(at url: URL? = nil) {
        let dir = url ?? storageDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(attachments)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ [AttachmentManager] Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        attachments = (try? JSONDecoder().decode([Attachment].self, from: data)) ?? []
    }
}
