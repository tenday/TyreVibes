import SwiftUI

struct AttachmentGalleryView: View {
    let entryId: String
    let isEditing: Bool

    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var imagePickerSource: ImagePickerView.Source = .photoLibrary
    @State private var selectedAttachment: AttachmentManager.Attachment?
    @State private var showViewer = false

    init(entryId: String, isEditing: Bool = true) {
        self.entryId = entryId
        self.isEditing = isEditing
    }

    private var entryAttachments: [AttachmentManager.Attachment] {
        attachmentManager.attachments(for: entryId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entryAttachments.isEmpty || isEditing {
                HStack {
                    Text("Allegati")
                        .font(.customFont(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("(\(entryAttachments.count))")
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entryAttachments) { attachment in
                            attachmentThumbnail(attachment)
                        }

                        if isEditing {
                            addButton
                        }
                    }
                }
            }
        }
        .confirmationDialog("Aggiungi allegato", isPresented: $showActionSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Fotocamera") {
                    imagePickerSource = .camera
                    showImagePicker = true
                }
            }
            Button("Libreria foto") {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }
            Button("Documento PDF") {
                showDocumentPicker = true
            }
            Button("Annulla", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(
                source: imagePickerSource,
                onImagePicked: { image in
                    _ = attachmentManager.addPhoto(image, for: entryId)
                    showImagePicker = false
                },
                onCancel: {
                    showImagePicker = false
                }
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let data = try? Data(contentsOf: url) {
                    _ = attachmentManager.addPDF(data, fileName: url.lastPathComponent, for: entryId)
                }
                showDocumentPicker = false
            }
        }
        .sheet(isPresented: $showViewer) {
            if let attachment = selectedAttachment {
                AttachmentViewerView(attachment: attachment)
            }
        }
    }

    private func attachmentThumbnail(_ attachment: AttachmentManager.Attachment) -> some View {
        Button {
            selectedAttachment = attachment
            showViewer = true
        } label: {
            ZStack {
                if attachment.type == .photo, let thumb = attachmentManager.thumbnail(for: attachment) {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 64, height: 64)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: attachment.type == .pdf ? "doc.richtext" : "photo")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(attachment.type == .pdf ? "PDF" : "Foto")
                                    .font(.customFont(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                }

                if isEditing {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                attachmentManager.deleteAttachment(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.red).frame(width: 16, height: 16))
                            }
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            showActionSheet = true
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
    }
}
