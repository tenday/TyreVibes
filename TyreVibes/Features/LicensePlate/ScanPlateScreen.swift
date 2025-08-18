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

struct LicensePlateView: View {
    var text: String
    var width: CGFloat = 200
    var height: CGFloat = 100
    var countryCode: String = "I"

    var body: some View {
        ZStack {
            // Plate base
            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                .fill(Color.white.opacity(0))
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        .stroke(Color.clear, lineWidth: 3)
                )
                // subtle inner bevel
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        .blur(radius: 1)
                        .offset(x: 0, y: 1)
                        .mask(
                            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        )
                )

            // Blue EU/country band on the left
            HStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(Color(red: 0.0, green: 0.35, blue: 0.8))
                    VStack(spacing: height * 0.06) {
                        // (Optional) stars could be added later if you have an asset
                        Text(countryCode)
                            .font(.customFont(size: height * 0.38, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, height * 0.08)
                    }
                }
                .frame(width: height * 0.28)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous))

            // Plate number
            Text(text)
                .font(.system(size: height * 0.5, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .kerning(3)
                .foregroundColor(.black)
                .padding(.horizontal, height * 0.32) // keep clear of blue band and border

        }
        .frame(width: width, height: height)
        // Rivets
        .overlay(
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Group {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .frame(width: h * 0.08, height: h * 0.08)
                        .position(x: w * 0.14, y: h * 0.22)
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .frame(width: h * 0.08, height: h * 0.08)
                        .position(x: w * 0.86, y: h * 0.22)
                }
            }
        )
        .accessibilityLabel(Text("License plate \(text)"))
    }
}

struct CameraPreview: UIViewControllerRepresentable {
    var roiSize: CGSize
    var onPlateDetected: (String) -> Void

    class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        let captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionLabel: UILabel?
        var roiSize: CGSize = .zero
        var onPlateDetected: ((String) -> Void)?
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

                    // Simple EU-style heuristic: 5–8 alphanumeric, at least 1 letter and 1 digit
                    let charset = CharacterSet.alphanumerics.inverted
                    let cleaned = merged.components(separatedBy: charset).joined()
                    if cleaned.count >= 5 && cleaned.count <= 8 && cleaned.rangeOfCharacter(from: .letters) != nil && cleaned.rangeOfCharacter(from: .decimalDigits) != nil {
                        if !self.hasFiredDetection {
                            self.hasFiredDetection = true
                            DispatchQueue.main.async {
                                self.onPlateDetected?(cleaned)
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

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.roiSize = roiSize
        vc.onPlateDetected = onPlateDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}

struct ScanPlateView: View {
    var onDetected: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var plateText: String = ""
    @State private var isLoadingPlateData: Bool = false

    var body: some View {
        let plateWidth: CGFloat = 280
        let plateHeight: CGFloat = 80

        NavigationStack {
            ZStack(alignment: .top) {
                CameraPreview(roiSize: CGSize(width: plateWidth, height: plateHeight)) { plate in
                    self.plateText = plate
                    self.isLoadingPlateData = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    fetchPlateData(for: plate)
                }
                .ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        
                        Text("Scan License Plate")
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
                        DashedROI(cornerRadius: plateHeight * 0.18)
                            .frame(width: plateWidth, height: plateHeight)
                        LicensePlateView(text: plateText.isEmpty ? "PLATYPS" : plateText, width: plateWidth, height: plateHeight, countryCode: "I")
                            .padding(.horizontal)
                    }
                    Spacer()
                    
                    // Instructions
                    VStack(alignment: .center, spacing: 8) {
                        Text("Position License Plate within Frame")
                            .font(.customFont(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Ensure words are visible")
                            .font(.customFont(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    Spacer()
                }
                if isLoadingPlateData {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView("Recupero dati targa...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
            .preferredColorScheme(.dark)
            .alert(isPresented: .constant(!plateText.isEmpty)) {
                Alert(title: Text("Targa rilevata"), message: Text(plateText), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func fetchPlateData(for plate: String) {
        // Simula chiamata di scraping in background
        DispatchQueue.global().async {
            // Simulazione ritardo rete
            sleep(2)
            let scrapedInfo = "Dati veicolo per \(plate) ottenuti"
            DispatchQueue.main.async {
                isLoadingPlateData = false
                // Puoi usare scrapedInfo o passarla al view model
                print(scrapedInfo)
                self.onDetected?(plate)
            }
        }
    }
}

#Preview {
    ScanPlateView()
}
