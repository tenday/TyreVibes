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
    var onPlateDetected: (String) -> Void

        class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var lastRequestTime = Date(timeIntervalSince1970: 0)
        private var lastPlates: [String] = []
        let captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionLabel: UILabel?
        var roiSize: CGSize = .zero
        var onPlateDetected: ((String) -> Void)?
        private var hasFiredDetection = false

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
            print("CameraViewController viewDidLoad")
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
                        self.captureSession.stopRunning()
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
            print("handleCameraAuthorization chiamato")
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                print("Camera autorizzata")
                setupSession()
            case .notDetermined:
                print("Camera: richiesta permesso")
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("Permesso fotocamera garantito")
                            self?.setupSession()
                        } else {
                            print("Permesso fotocamera NEGATO")
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
            print("setupSession: inizializzo sessione fotocamera")
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

            print("setupSession: avvio captureSession")
            print("▶️ captureSession.startRunning chiamato")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    print("✅ captureSession in esecuzione: \(self?.captureSession.isRunning ?? false)")
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
                        print("Candidati OCR raw: \(rawCandidates)")

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
                            print("⚠️ Nessun match regex, uso fallback:", fallback)
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
    @State private var navigateToCheckDetails: Bool = false
    @State private var data: PlateData?
    @State private var vehicleImage: UIImage?
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false

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
                    // Overlay guidato per l'utente
                    VStack(spacing: 0) {
                        // Testo guida sopra il riquadro ROI
                        if plateText.isEmpty {
                            Text("Allinea la targa all’interno del riquadro")
                                .font(.customFont(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.bottom, 16)
                        }
                        // ZStack con bordo animato attorno alla ROI
                        ZStack {
                            if plateText.isEmpty {
                                DashedROI(cornerRadius: plateHeight * 0.18)
                                    .frame(width: plateWidth, height: plateHeight)
                                    .foregroundColor(.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: plateHeight * 0.18)
                                            .stroke(Color.yellow, lineWidth: 3)
                                            .opacity(0.6)
                                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: plateText.isEmpty)
                                    )
                            }

                            LicensePlateView(text: plateText, width: plateWidth, height: plateHeight, countryCode: "I")
                                .padding(.horizontal)
                                .scaleEffect(plateText.isEmpty ? 1.0 : 1.1)
                                .opacity(plateText.isEmpty ? 0.7 : 1.0)
                                .animation(.easeOut(duration: 0.4), value: plateText.isEmpty)

                            if !plateText.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                    .transition(.scale.combined(with: .opacity))
                                    .padding(.top, -plateHeight * 1.4)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: plateText)
                            }
                        }
                        // Testo dinamico sotto al riquadro
                        if isLoadingPlateData {
                            Text("Rimani fermo")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        } else if plateText.isEmpty {
                            Text("Inquadra la targa all’interno del riquadro")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                    Spacer()
                }
                ZStack {
                    if isLoadingPlateData {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .overlay(
                                Color.clear.customAlert(
                                    isPresented: $isLoadingPlateData,
                                    title: "",
                                    message: "Ricerca targa in corso...",
                                    showprogress: false,
                                    primaryButtonTitle: "OK",
                                    primaryButtonAction: {

                                    }
                                )
                            )
                            .task {
                                let trimmed = plateText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else {
                                    self.isLoadingPlateData = false
                                    return
                                }
                                // Interrompe subito la ricerca visuale
                                self.isLoadingPlateData = false
                                do {
                                    let data = try await LicensePlateReader.fetchPlateSummary(plate: trimmed)
                                    self.data = data
                                    self.vehicleImage = data.vehicleImage
                                    self.navigateToCheckDetails = true
                                } catch {
                                    self.errorMessage = error.localizedDescription
                                    self.showErrorAlert = true
                                }
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: isLoadingPlateData)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: self.$navigateToCheckDetails) {
                CheckDetailsView(
                    vehicleImage: self.vehicleImage,
                    plateData: self.data,
                    isContinueEnabled: .constant(false),
                    viewModel: ConfirmDetailsViewModel()
                )
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

       
