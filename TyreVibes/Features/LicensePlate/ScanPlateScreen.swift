import SwiftUI
import UIKit
import AVFoundation
import Vision
import CoreML

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

    // Helper: Adaptive placeholder for plate text
    private func adaptivePlaceholder(countRange: ClosedRange<Int> = 6...8) -> String {
        // Estimate character width from font size (height * 0.5) and a conservative width factor
        let charWidth = height * 0.5 * 0.6 + 3 // 0.6 width factor + kerning (3)
        let usableWidth = width - (height * 0.64) // horizontal padding for blue band + border (both sides)
        let maxChars = max(countRange.lowerBound, min(Int(usableWidth / max(charWidth, 1)), countRange.upperBound))
        return String(repeating: "·", count: maxChars) // middle dot placeholder
    }

    var body: some View {
        ZStack {
            if !text.isEmpty {
                RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0))
                    .overlay(
                            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                                .stroke(Color.green, lineWidth: 4)
                       
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
            } else {
                RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0))
                    .overlay(
                            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                       
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
            }
            // Plate base
            

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

            // Plate number (adaptive placeholder when empty)
            let displayString = text.isEmpty ? adaptivePlaceholder() : text
            Text(displayString)
                .font(.customFont(size: height * 0.5, weight: .semibold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .kerning(3)
                .foregroundColor(text.isEmpty ? Color.black.opacity(0.35) : .black)
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
    var onPlateDetected: (String?) -> Void
    @Binding var viewController: CameraViewController?

        class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var lastRequestTime = Date(timeIntervalSince1970: 0)
        private var lastPlates: [String] = []
        let captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionLabel: UILabel?
        var roiSize: CGSize = .zero
        var onPlateDetected: ((String) -> Void)?
        private var hasFiredDetection = false

        // Metodo pubblico per resettare lo stato della camera
        public func resetDetection() {
            hasFiredDetection = false
            lastPlates.removeAll()
            resumeCamera()
        }

        private var plateDetectorModel: VNCoreMLModel?
        private var plateOCRModel: VNCoreMLModel?

        private func loadVNModel(named name: String) -> VNCoreMLModel? {
            // Prova prima a caricare il modello .mlmodelc
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                do {
                    let mlModel = try MLModel(contentsOf: url, configuration: MLModelConfiguration())
                    return try VNCoreMLModel(for: mlModel)
                } catch {
                    print("[CoreML] Impossibile caricare modello \(name).mlmodelc: \(error)")
                }
            }
            // Se non trovato o errore, prova a caricare .mlpackage (cartella modello)
            if let packageURL = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                do {
                    let mlModel = try MLModel(contentsOf: packageURL, configuration: MLModelConfiguration())
                    return try VNCoreMLModel(for: mlModel)
                } catch {
                    print("[CoreML] Impossibile caricare modello \(name).mlpackage: \(error)")
                }
            }
            print("[CoreML] Modello \(name) non trovato in .mlmodelc né .mlpackage")
            return nil
        }

        private func loadModels() {
            // Supporta modelli sia in formato .mlmodelc che .mlpackage.
            // Nomi attesi nei Resources del bundle: "LicensePlateDetector.mlmodelc" o "LicensePlateDetector.mlpackage"
            // e (opzionale) "PlateOCRCRNN.mlmodelc" o "PlateOCRCRNN.mlpackage"
            self.plateDetectorModel = loadVNModel(named: "LicensePlateDetector")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            loadModels()
            handleCameraAuthorization()
        }
            
            private func handleDetectedPlate(_ plate: String) {
                lastPlates.append(plate)
                if lastPlates.count > 5 { lastPlates.removeFirst() }

                let mostCommon = lastPlates.reduce(into: [:]) { counts, val in
                    counts[val, default: 0] += 1
                }.max(by: { $0.value < $1.value })?.key

                if let stablePlate = mostCommon,
                   lastPlates.filter({ $0 == stablePlate }).count >= 3,
                   !self.hasFiredDetection {
                    self.hasFiredDetection = true
                    DispatchQueue.main.async {
                        //self.captureSession.stopRunning()
                        self.onPlateDetected?(stablePlate)
                    }
                }
            }

            public func resumeCamera() {
                if !captureSession.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        self?.captureSession.startRunning()
                    }
                }
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
                print("Camera negata o ristretta")
                showPermissionLabel(text: "Accesso fotocamera negato o limitato.\nAbilitalo in Impostazioni > Privacy > Fotocamera.")
            @unknown default:
                print("Camera stato sconosciuto")
                showPermissionLabel(text: "Impossibile accedere alla fotocamera.")
            }
        }

        private func setupSession() {
            #if targetEnvironment(simulator)
            print("Simulator: la fotocamera non è disponibile")
            showPermissionLabel(text: "La fotocamera non è disponibile nel Simulator.\nEsegui su un dispositivo reale.")
            return
            #else
            captureSession.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                print("setupSession: errore input fotocamera")
                showPermissionLabel(text: "Impossibile inizializzare la fotocamera.")
                return
            }

            captureSession.addInput(videoInput)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            guard captureSession.canAddOutput(videoOutput) else {
                print("setupSession: errore output video")
                showPermissionLabel(text: "Impossibile aggiungere output video.")
                return
            }
            captureSession.addOutput(videoOutput)

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer

            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                }
            }
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
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("captureOutput: pixelBuffer nil")
                return
            }
            
            // Calcolo ROI normalizzata in coordinate Vision (origine in basso a sinistra)
            var roiRectNormalized: CGRect = .zero
            if let previewLayer = previewLayer {
                let videoWidth = previewLayer.bounds.width
                let videoHeight = previewLayer.bounds.height
                var widthNorm = (roiSize.width / videoWidth) * 0.85
                var heightNorm = (roiSize.height / videoHeight) * 0.60
                widthNorm = min(max(widthNorm, 0.1), 1.0)
                heightNorm = min(max(heightNorm, 0.1), 1.0)
                let originX = (1 - widthNorm) / 2
                let originY = (1 - heightNorm) / 2
                let originYFlipped = 1 - originY - heightNorm
                roiRectNormalized = CGRect(x: originX, y: originYFlipped, width: widthNorm, height: heightNorm)
            }

            // Determina l'orientamento per Vision
            let orientation = self.cgImagePropertyOrientation(for: UIDevice.current.orientation)

            // Se abbiamo un modello di detection, usiamolo per trovare la bounding box della targa
            if let detector = plateDetectorModel {
                let detRequest = VNCoreMLRequest(model: detector) { [weak self] req, _ in
                    guard let self = self else { return }
                    guard let results = req.results as? [VNRecognizedObjectObservation] else {
                        print("VNCoreMLRequest: nessun risultato/cast fallito")
                        return
                    }
                    // Converte ROI e bounding box nel sistema pixel buffer (origine in alto a sinistra)
                    let pixelWidth = CVPixelBufferGetWidth(pixelBuffer)
                    let pixelHeight = CVPixelBufferGetHeight(pixelBuffer)

                    let roiInPixels = VNImageRectForNormalizedRect(roiRectNormalized, pixelWidth, pixelHeight)

                    let filteredResults = results.filter { obs in
                        let boxInPixels = VNImageRectForNormalizedRect(obs.boundingBox, pixelWidth, pixelHeight)
                        return roiInPixels.intersects(boxInPixels)
                    }

                    guard let best = filteredResults.sorted(by: { $0.confidence > $1.confidence }).first else {
                        return
                    }
                    // Se vuoi mantenere la vecchia selezione, commenta la riga sotto:
                    // guard let best = results.sorted(by: { $0.confidence > $1.confidence }).first else { return }

                    // Esegui l'OCR solo sulla bounding box rilevata, clampa i valori in [0,1]
                    var plateBox = best.boundingBox
                    plateBox.origin.x = max(0, min(1, plateBox.origin.x))
                    plateBox.origin.y = max(0, min(1, plateBox.origin.y))
                    plateBox.size.width = max(0, min(1 - plateBox.origin.x, plateBox.size.width))
                    plateBox.size.height = max(0, min(1 - plateBox.origin.y, plateBox.size.height))

                    let textReq = VNRecognizeTextRequest { [weak self] treq, _ in
                        guard let self = self else { return }
                        guard let observations = treq.results as? [VNRecognizedTextObservation] else { return }

                        // Filtra le osservazioni che ricadono nella bounding box della targa
                        let filteredObservations = observations.filter { obs in
                            plateBox.intersects(obs.boundingBox)
                        }

                        // Raccogli al massimo 2 candidati per osservazione
                        let rawCandidates: [String] = filteredObservations.flatMap { $0.topCandidates(2).map { $0.string } }

                        // Normalizzazione
                        let cleanedCandidates: [String] = rawCandidates.map { cand in
                            cand.uppercased()
                                .replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "-", with: "")
                                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                                .joined()
                        }
                        //print("Candidati OCR cleaned: \(cleanedCandidates)")

                        // Regex: IT, EU, e regex permissiva di debug
                        let itRegex = try! NSRegularExpression(pattern: "^[A-Z]{2}[0-9]{3}[A-Z]{2}$")
                        let euRegex = try! NSRegularExpression(pattern: "^(?=.*[A-Z])(?=.*[0-9])[A-Z0-9]{5,8}$")
                        let anyPlateRegex = try! NSRegularExpression(pattern: "^[A-Z0-9]{4,10}$")

                        let scored: [(String, Int)] = cleanedCandidates.compactMap { s in
                            guard !s.isEmpty else { return nil }
                            guard (6...8).contains(s.count) else { return nil }
                            guard s.rangeOfCharacter(from: .letters) != nil,
                                  s.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }
                            let r = NSRange(location: 0, length: s.count)
                            let isIT = itRegex.firstMatch(in: s, range: r) != nil
                            let isEU = euRegex.firstMatch(in: s, range: r) != nil
                            let isAny = anyPlateRegex.firstMatch(in: s, range: r) != nil
                            guard isIT || isEU || isAny else { return nil }
                            let letters = s.filter { $0.isLetter }.count
                            let digits = s.filter { $0.isNumber }.count
                            // Score: premia IT, poi EU, poi any
                            let score = (isIT ? 100 : isEU ? 60 : 20) + s.count * 2 + min(letters, 4) + min(digits, 4)
                            return (s, score)
                        }

                        if let best = scored.sorted(by: { $0.1 > $1.1 }).first?.0 {
                           self.handleDetectedPlate(best)
                        } else if let fallback = cleanedCandidates.first, !fallback.isEmpty {
                            self.handleDetectedPlate(fallback)
                        }
                    }
                    textReq.usesLanguageCorrection = false
                    textReq.recognitionLevel = .accurate
                    textReq.recognitionLanguages = ["en-US"]
                    //textReq.regionOfInterest = plateBox

                    let handler2 = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                    try? handler2.perform([textReq])
                }
                detRequest.imageCropAndScaleOption = .scaleFill
                detRequest.regionOfInterest = roiRectNormalized

                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                try? handler.perform([detRequest])
                return
            }
            
            

            
        }

        // Helper per mappare UIDeviceOrientation a CGImagePropertyOrientation
        private func cgImagePropertyOrientation(for deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
            switch deviceOrientation {
            case .portraitUpsideDown: return .left
            case .landscapeLeft: return .up
            case .landscapeRight: return .down
            default: return .right
            }
        }
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.roiSize = roiSize
        vc.onPlateDetected = onPlateDetected
        DispatchQueue.main.async {
            self.viewController = vc
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
    
    
}

struct ScanPlateView: View {
    var onDetected: ((String) -> Void)? = nil
    var onFullScreenDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var navigationDismiss
    @State private var plateText: String = ""
    @State private var isLoadingPlateData: Bool = false
    @State private var navigateToCheckDetails: Bool = false
    @State private var data: PlateData?
    @State private var vehicleImage: UIImage?
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var cameraViewController: CameraPreview.CameraViewController?

    // Nuovi stati per le guide UX
    @State private var showInstructions: Bool = true
    @State private var pulseAnimation: Bool = false
    @State private var guideStep: Int = 0
    @State private var scanningIndicatorOpacity: Double = 0.0

    // Vehicle action selection
    @State private var showActionSheet: Bool = true
    @State private var selectedAction: VehicleAction?
    @State private var hasSelectedAction: Bool = false

    enum VehicleAction {
        case addToGarage
        case justConsult
    }

    var body: some View {
        let plateWidth: CGFloat = 280
        let plateHeight: CGFloat = 80

        NavigationStack {
            ZStack(alignment: .top) {
                CameraPreview(
                    roiSize: CGSize(width: plateWidth, height: plateHeight),
                    onPlateDetected: { plate in
                        self.plateText = plate ?? ""
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        // Avvia il caricamento senza chiamare fetchPlateData (deprecata)
                        self.isLoadingPlateData = true
                    },
                    viewController: $cameraViewController
                )
                .ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        Spacer()
                        Button(action: { navigationDismiss() }) {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
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

                    // Istruzioni iniziali animate
                    if showInstructions && plateText.isEmpty && !isLoadingPlateData {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.9))
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

                            VStack(spacing: 8) {
                                Text("Scansione Targa")
                                    .font(.customFont(size: 22, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Posiziona la targa del veicolo\nall'interno del riquadro")
                                    .font(.customFont(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }

                            // Indicatori di suggerimento
                            HStack(spacing: 20) {
                                ScanTipView(icon: "light.max", text: "Luce\nbuona")
                                ScanTipView(icon: "rectangle.center.inset.filled", text: "Targa\ncentrata")
                                ScanTipView(icon: "hand.raised", text: "Tieni\nfermo")
                            }

                            Button(action: {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showInstructions = false
                                }
                            }) {
                                Text("Inizia Scansione")
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(.white)
                                    )
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 32)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Overlay guidato per la scansione
                    if !showInstructions {
                        VStack(spacing: 16) {
                            // ZStack con bordo animato e guide di allineamento
                            ZStack {
                                // Guide di allineamento negli angoli
                                if plateText.isEmpty {
                                    CornerGuidesView(width: plateWidth, height: plateHeight)
                                        .opacity(scanningIndicatorOpacity)
                                        .animation(.easeInOut(duration: 0.5), value: scanningIndicatorOpacity)
                                }

                                // ROI principale
                                if plateText.isEmpty {
                                    DashedROI(cornerRadius: plateHeight * 0.18)
                                        .frame(width: plateWidth, height: plateHeight)
                                        .foregroundColor(.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: plateHeight * 0.18)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.yellow, .orange],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                                .opacity(pulseAnimation ? 0.8 : 0.4)
                                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                                        )
                                }

                                LicensePlateView(text: plateText, width: plateWidth, height: plateHeight, countryCode: "I")
                                    .padding(.horizontal)
                                    .scaleEffect(plateText.isEmpty ? 1.0 : 1.1)
                                    .opacity(plateText.isEmpty ? 0.7 : 1.0)
                                    .animation(.easeOut(duration: 0.4), value: plateText.isEmpty)

                                if !plateText.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                            .transition(.scale.combined(with: .opacity))
                                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: plateText)
                                    }
                                    .offset(y: -plateHeight * 0.8)
                                }
                            }

                            // Testo dinamico e suggerimenti sotto al riquadro
                            VStack(spacing: 8) {
                                if plateText.isEmpty {
                                    Text("Inquadra la targa nel riquadro")
                                        .font(.customFont(size: 18, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("Assicurati che la targa sia ben illuminata e leggibile")
                                        .font(.customFont(size: 14, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            pulseAnimation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    scanningIndicatorOpacity = 1.0
                                }
                            }
                        }
                    }

                    Spacer()
                }
                // Loading overlay persistente
                if isLoadingPlateData {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .overlay(
                            CustomAlertView(
                                title: "Ricerca targa in corso...",
                                showProgress: true
                            )
                        )
                }
            }
            .onChange(of: isLoadingPlateData) { oldValue, newValue in
                // Quando isLoadingPlateData diventa true, avvia la ricerca
                if newValue && !oldValue {
                    performPlateSearch()
                }
            }
            .onChange(of: navigateToCheckDetails) { oldValue, newValue in
                // Quando si torna indietro da CheckDetailsScreen (navigateToCheckDetails diventa false)
                if !newValue && oldValue {
                    resetScanningState()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: self.$navigateToCheckDetails) {
                CheckDetailsView(
                    onFullScreenDismiss: { onFullScreenDismiss?() },
                    vehicleImage: self.vehicleImage,
                    plateData: self.data,
                    isContinueEnabled: .constant(false),
                    viewModel: ConfirmDetailsViewModel()
                )
            }
            .alert("Errore", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    plateText = ""
                    // Reset per permettere nuova scansione
                }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "Cosa vuoi fare?",
                isPresented: $showActionSheet,
                titleVisibility: .visible
            ) {
                Button("Aggiungi al Garage") {
                    selectedAction = .addToGarage
                    hasSelectedAction = true
                }

                Button("Solo Consultare Dati") {
                    selectedAction = .justConsult
                    hasSelectedAction = true
                }

                Button("Annulla", role: .cancel) {
                    navigationDismiss()
                }
            } message: {
                Text("Puoi aggiungere il veicolo al tuo garage per tenere traccia di manutenzioni e pneumatici, oppure consultare solo i dati del veicolo.")
            }
        }
    }
    
    private func performPlateSearch() {
        let trimmed = plateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.isLoadingPlateData = false
            return
        }

        Task {
            do {
                let data = try await LicensePlateReader.fetchPlateSummary(plate: trimmed)

                await MainActor.run {
                    if data.make == "" {
                        self.errorMessage = "Targa inserita non trovata, si prega di riprovare"
                        self.showErrorAlert = true
                        self.isLoadingPlateData = false
                    } else {
                        self.data = data
                        self.vehicleImage = data.vehicleImage
                        self.isLoadingPlateData = false
                        self.navigateToCheckDetails = true
                    }
                }
            } catch let apiError as PlateAPIError {
                await MainActor.run {
                    switch apiError {
                    case .alreadyInGarage:
                        self.errorMessage = "Questa targa è già presente nel tuo garage."
                    default:
                        self.errorMessage = apiError.localizedDescription
                    }
                    self.showErrorAlert = true
                    self.isLoadingPlateData = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    self.isLoadingPlateData = false
                }
            }
        }
    }

    // Funzione deprecata - ora la ricerca avviene in performPlateSearch() tramite onChange
    private func fetchPlateData(for plate: String) {
        // Non più utilizzata - rimossa la doppia chiamata
    }

    // Funzione per resettare lo stato quando si torna indietro
    private func resetScanningState() {
        // Reset di tutti gli stati UI
        plateText = ""
        isLoadingPlateData = false
        data = nil
        vehicleImage = nil
        errorMessage = ""
        showErrorAlert = false
        showInstructions = false
        pulseAnimation = false
        scanningIndicatorOpacity = 0.0

        // Reset della camera
        cameraViewController?.resetDetection()

        // Riavvia le animazioni
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                pulseAnimation = true
                scanningIndicatorOpacity = 1.0
            }
        }
    }
}

// MARK: - Helper Views per le guide UX

struct ScanTipView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.yellow)

            Text(text)
                .font(.customFont(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(width: 60)
    }
}

struct CornerGuidesView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Angolo superiore sinistro
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 20, height: 3)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: width, height: height)

            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 3, height: 20)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: width, height: height)

            // Angolo superiore destro
            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 20, height: 3)
                }
                Spacer()
            }
            .frame(width: width, height: height)

            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 3, height: 20)
                }
                Spacer()
            }
            .frame(width: width, height: height)

            // Angolo inferiore sinistro
            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 20, height: 3)
                    Spacer()
                }
            }
            .frame(width: width, height: height)

            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 3, height: 20)
                    Spacer()
                }
            }
            .frame(width: width, height: height)

            // Angolo inferiore destro
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 20, height: 3)
                }
            }
            .frame(width: width, height: height)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.yellow)
                        .frame(width: 3, height: 20)
                }
            }
            .frame(width: width, height: height)
        }
    }
}

#Preview {
    ScanPlateView()
}

       
