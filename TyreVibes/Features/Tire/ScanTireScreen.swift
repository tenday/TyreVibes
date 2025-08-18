import SwiftUI
import AVFoundation
import Vision

struct DashedROI: View {
    var cornerRadius: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .foregroundColor(.white.opacity(0.9))
            .accessibilityHidden(true)
    }
}


struct TireCameraPreview: UIViewControllerRepresentable {
    var roiSize: CGSize
    var onTireDataDetected: (String) -> Void

    class TireCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        let captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionLabel: UILabel?
        var roiSize: CGSize = .zero
        var onTireDataDetected: ((String) -> Void)?
        private var hasFiredDetection = false

        override func viewDidLoad() {
            super.viewDidLoad()
            handleCameraAuthorization()
        }

        private func handleCameraAuthorization() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.setupSession()
                        } else {
                            self?.showPermissionLabel(text: "Accesso fotocamera negato.\nAbilitalo in Impostazioni > Privacy > Fotocamera.")
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionLabel(text: "Accesso fotocamera negato o limitato.\nAbilitalo in Impostazioni > Privacy > Fotocamera.")
            @unknown default:
                showPermissionLabel(text: "Impossibile accedere alla fotocamera.")
            }
        }

        private func setupSession() {
            #if targetEnvironment(simulator)
            showPermissionLabel(text: "La fotocamera non è disponibile nel Simulator.\nEsegui su un dispositivo reale.")
            return
            #else
            captureSession.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                showPermissionLabel(text: "Impossibile inizializzare la fotocamera.")
                return
            }

            captureSession.addInput(videoInput)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            guard captureSession.canAddOutput(videoOutput) else {
                showPermissionLabel(text: "Impossibile aggiungere output video.")
                return
            }
            captureSession.addOutput(videoOutput)

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer

            captureSession.startRunning()
            #endif
        }

        private func showPermissionLabel(text: String) {
            permissionLabel?.removeFromSuperview()
            let label = UILabel()
            label.text = text
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            permissionLabel = label
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let request = VNRecognizeTextRequest { req, error in
                if let results = req.results as? [VNRecognizedTextObservation] {
                    let candidates: [String] = results.compactMap { $0.topCandidates(1).first?.string }
                    let merged = candidates.joined(separator: " ")
                        .uppercased()
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "-", with: "")

                    let regex = try! NSRegularExpression(pattern: "(\\d{3}/\\d{2}\\s?R\\d{2})")
                    let range = NSRange(location: 0, length: merged.utf16.count)
                    if let match = regex.firstMatch(in: merged, options: [], range: range) {
                        if let swiftRange = Range(match.range, in: merged) {
                            let tireCode = String(merged[swiftRange])
                            if !self.hasFiredDetection {
                                self.hasFiredDetection = true
                                DispatchQueue.main.async {
                                    self.onTireDataDetected?(tireCode)
                                }
                            }
                        }
                    }
                }
            }
            request.usesLanguageCorrection = false
            request.recognitionLevel = .accurate

            // Calculate the region of interest centered in the previewLayer
            if let previewLayer = previewLayer {
                let videoWidth = previewLayer.bounds.width
                let videoHeight = previewLayer.bounds.height

                let widthNorm = roiSize.width / videoWidth
                let heightNorm = roiSize.height / videoHeight

                let originX = (1 - widthNorm) / 2
                let originY = (1 - heightNorm) / 2

                let originYFlipped = 1 - originY - heightNorm

                request.regionOfInterest = CGRect(x: originX, y: originYFlipped, width: widthNorm, height: heightNorm)
            }

            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? requestHandler.perform([request])
        }
    }

    func makeUIViewController(context: Context) -> TireCameraViewController {
        let vc = TireCameraViewController()
        vc.roiSize = roiSize
        vc.onTireDataDetected = onTireDataDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: TireCameraViewController, context: Context) {
    }
}

struct ScanTireScreen: View {
    var onDetected: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var tireDataText: String = ""
    @State private var showDetectedAlert: Bool = false

    var body: some View {
        let roiWidth: CGFloat = 300
        let roiHeight: CGFloat = 100

        NavigationStack {
            ZStack(alignment: .top) {
                TireCameraPreview(roiSize: CGSize(width: roiWidth, height: roiHeight)) { tireData in
                    self.tireDataText = tireData
                    self.showDetectedAlert = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                .ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()

                        Text("Scan Tire Data")
                            .font(.customFont(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    ZStack {
                                        Circle()
                                            .fill(Color.customBackgroundColor)
                                        Circle()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                            .blur(radius: 1)
                                            .offset(x: 0.3, y: 1)
                                            .mask(
                                                Circle().fill(LinearGradient(
                                                    gradient: Gradient(colors: [.black, .black]),
                                                    startPoint: .top,
                                                    endPoint: .bottom)
                                                )
                                            )
                                        VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                            .clipShape(Circle())
                                            .padding(12)
                                            .blur(radius: 40)
                                            .opacity(0.8)
                                    }
                                )
                        }
                    }
                    .padding(.top)
                    .padding(.horizontal,24)


                    Spacer()
                    ZStack {
                        DashedROI(cornerRadius: 12)
                            .frame(width: roiWidth, height: roiHeight)
                        Text(tireDataText.isEmpty ? "..." : tireDataText)
                            .font(.customFont(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    Spacer()

                    // Instructions
                    VStack(alignment: .center, spacing: 8) {
                        Text("Position Tire Markings within Frame")
                            .font(.customFont(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Ensure the tire size code is clearly visible")
                            .font(.customFont(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
            .preferredColorScheme(.dark)
            .alert("Tire Data Detected", isPresented: $showDetectedAlert) {
                Button("OK") {
                    self.onDetected?(tireDataText)
                    dismiss()
                }
            } message: {
                Text(tireDataText)
            }
        }
    }
}

#Preview {
    ScanTireScreen()
}
