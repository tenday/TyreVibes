import SwiftUI
import VisionKit

private enum ReceiptLiveScannerError: LocalizedError {
    case scannerUnavailable

    var errorDescription: String? {
        switch self {
        case .scannerUnavailable:
            return "Scanner non disponibile su questo dispositivo."
        }
    }
}

@MainActor
private final class ReceiptLiveScannerState: ObservableObject {
    @Published var recognizedTextCount = 0
    @Published var recognizedPreview = ""
    @Published var errorMessage: String?

    weak var scanner: DataScannerViewController?

    func capturePhoto() async throws -> UIImage {
        guard let scanner else {
            throw ReceiptLiveScannerError.scannerUnavailable
        }

        return try await scanner.capturePhoto()
    }

    func updateRecognizedItems(_ items: [RecognizedItem]) {
        let textItems = items.compactMap(Self.textTranscript(from:))

        recognizedTextCount = textItems.count
        recognizedPreview = textItems
            .prefix(3)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func textTranscript(from item: RecognizedItem) -> String? {
        guard case .text(let text) = item else { return nil }
        return text.transcript
    }
}

struct ReceiptLiveScannerView: View {
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var scannerState = ReceiptLiveScannerState()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                ReceiptDataScannerRepresentable(scannerState: scannerState)
                    .ignoresSafeArea()
            } else {
                unavailableView
            }

            overlay
        }
        .background(Color.black)
    }

    private var overlay: some View {
        VStack(spacing: 16) {
            header
            Spacer()
            statusPanel
            captureControls
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 26)
    }

    private var header: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }

            Spacer()

            Text("Scanner ricevuta")
                .font(.customFont(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.black.opacity(0.55)))

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: scannerState.recognizedTextCount > 0 ? "text.viewfinder" : "viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)

                Text(scannerState.recognizedTextCount > 0 ? "Testo rilevato" : "Inquadra la ricevuta")
                    .font(.customFont(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            if let errorMessage = scannerState.errorMessage {
                Text(errorMessage)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.orange)
                    .lineLimit(2)
            } else if scannerState.recognizedPreview.isEmpty {
                Text("Mantieni il documento ben illuminato e fermo, poi acquisisci.")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            } else {
                Text(scannerState.recognizedPreview)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var captureControls: some View {
        HStack(spacing: 20) {
            Spacer()

            Button {
                captureCurrentFrame()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)

                    Circle()
                        .stroke(Color.black.opacity(0.8), lineWidth: 3)
                        .frame(width: 58, height: 58)

                    if isCapturing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                }
            }
            .disabled(isCapturing || scannerState.scanner == nil)
            .opacity(isCapturing || scannerState.scanner == nil ? 0.65 : 1)

            Spacer()
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.75))

            Text("Scanner live non disponibile")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("Puoi usare la libreria foto oppure la fotocamera classica.")
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "191919"))
    }

    private func captureCurrentFrame() {
        Task { @MainActor in
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await scannerState.capturePhoto()
                onImageCaptured(image)
            } catch {
                scannerState.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ReceiptDataScannerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var scannerState: ReceiptLiveScannerState

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["it-IT", "en-US"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator

        Task { @MainActor in
            scannerState.scanner = scanner
            do {
                try scanner.startScanning()
                scannerState.errorMessage = nil
            } catch {
                scannerState.errorMessage = error.localizedDescription
            }
        }

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        Task { @MainActor in
            if scannerState.scanner == nil {
                scannerState.scanner = uiViewController
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scannerState: scannerState)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let scannerState: ReceiptLiveScannerState

        init(scannerState: ReceiptLiveScannerState) {
            self.scannerState = scannerState
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            updateRecognizedItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            updateRecognizedItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            updateRecognizedItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            Task { @MainActor in
                scannerState.errorMessage = error.localizedDescription
            }
        }

        private func updateRecognizedItems(_ items: [RecognizedItem]) {
            Task { @MainActor in
                scannerState.updateRecognizedItems(items)
            }
        }
    }
}
