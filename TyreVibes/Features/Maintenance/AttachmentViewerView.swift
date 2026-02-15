import SwiftUI
import PDFKit

struct AttachmentViewerView: View {
    let attachment: AttachmentManager.Attachment

    @Environment(\.dismiss) private var dismiss
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if attachment.type == .photo {
                    photoViewer
                } else {
                    pdfViewer
                }
            }
            .background(Color.black)
            .navigationTitle(attachment.type == .photo ? "Foto" : "Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                let url = attachmentManager.fileURL(for: attachment)
                ShareSheet(items: [url])
            }
        }
    }

    private var photoViewer: some View {
        ZoomableImageView(attachment: attachment)
    }

    private var pdfViewer: some View {
        PDFViewer(url: attachmentManager.fileURL(for: attachment))
    }
}

// MARK: - Zoomable Image

struct ZoomableImageView: View {
    let attachment: AttachmentManager.Attachment

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            if let image = AttachmentManager.shared.loadFullImage(for: attachment) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation { scale = 1.0 }
                                    lastScale = 1.0
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2).onEnded {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                    )
            } else {
                Text("Impossibile caricare l'immagine")
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - PDF Viewer

struct PDFViewer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black

        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
