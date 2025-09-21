import SwiftUI
import AVFoundation
import Vision

// Estensione per la notifica del flash
extension Notification.Name {
    static let flashToggle = Notification.Name("flashToggle")
}

// MARK: - Modello dati semplice
struct TireData {
    var brand: String = ""
    var model: String = ""
    var size: String = ""
    var dot: String = ""
    var loadIndex: String = ""
    var speedRating: String = ""
    var season: String = ""
    var allText: [String] = []
}

// MARK: - OCR Manager
class TireOCRManager: NSObject, ObservableObject {
    @Published var extractedData = TireData()
    @Published var isProcessing = false
    @Published var tireDetected = false

    private var textRecognitionRequest: VNRecognizeTextRequest!

    // Metodo per resettare i dati catturati
    func resetExtractedData() {
        extractedData = TireData()
        tireDetected = false
    }

    // Metodo per controllare il flash
    func toggleFlash(_ isOn: Bool) {
        NotificationCenter.default.post(name: .flashToggle, object: isOn)
    }
    
    override init() {
        super.init()
        setupOCR()
    }
    
    private func setupOCR() {
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            self.processTextResults(observations)
        }

        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
    }
    
    func extractTextFromImage(_ image: CGImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isProcessing = true
                self.tireDetected = true // Always assume tire is present, let user guide themselves
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([self.textRecognitionRequest])
            } catch {
                print("OCR Error: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }


    
    private func processTextResults(_ observations: [VNRecognizedTextObservation]) {
        // Inizia con i dati esistenti invece di creare nuovi dati
        var updatedData = extractedData
        var allDetectedText: [String] = []
        
        // Estrai tutto il testo rilevato
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !text.isEmpty {
                allDetectedText.append(text)
                
                // Estrai dati specifici preservando quelli esistenti
                extractSpecificData(from: text, into: &updatedData)
            }
        }
        
        // Accumula il testo rilevato invece di sovrascriverlo
        let combinedText = Set(updatedData.allText + allDetectedText)
        updatedData.allText = Array(combinedText).sorted()
        
        DispatchQueue.main.async { [weak self] in
            self?.extractedData = updatedData
            self?.isProcessing = false
        }
    }
    
    private func extractSpecificData(from text: String, into data: inout TireData) {
        let upperText = text.uppercased()
        
        // Estrai dimensioni solo se non già presente
        if data.size.isEmpty, let sizeMatch = extractTireSize(from: upperText) {
            data.size = sizeMatch
        }
        
        // Estrai marca solo se non già presente
        if data.brand.isEmpty, let brandMatch = extractBrand(from: upperText) {
            data.brand = brandMatch
        }
        
        // Estrai DOT solo se non già presente
        if data.dot.isEmpty, let dotMatch = extractDOT(from: upperText) {
            data.dot = dotMatch
        }

        // Estrai stagionalità solo se non già presente
        if data.season.isEmpty, let seasonMatch = extractSeason(from: upperText) {
            data.season = seasonMatch
        }

        // Estrai load index e speed rating solo se non già presenti
        if data.loadIndex.isEmpty || data.speedRating.isEmpty {
            extractLoadAndSpeed(from: upperText, into: &data)
        }
    }
    
    private func extractTireSize(from text: String) -> String? {
        let patterns = [
            #"(\d{3}\/\d{2}R\d{2})"#,  // 225/55R17
            #"(\d{3}\/\d{2}-\d{2})"#,   // 225/55-17
            #"(\d{3} \d{2} R\d{2})"#    // 225 55 R17
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).replacingOccurrences(of: " ", with: "")
            }
        }
        return nil
    }
    
    private func extractBrand(from text: String) -> String? {
        let brands = [
            // Marche principali con varianti
            "MICHELIN", "BRIDGESTONE", "PIRELLI", "CONTINENTAL", "GOODYEAR",
            "DUNLOP", "YOKOHAMA", "HANKOOK", "KUMHO", "TOYO", "NOKIAN",
            "FALKEN", "COOPER", "MAXXIS", "NEXEN", "UNIROYAL", "GENERAL",
            "BF GOODRICH", "FIRESTONE", "VREDESTEIN",

            // Varianti e abbreviazioni comuni
            "MICH", "BRIDGE", "CONT", "GOOD", "YOKO", "HANK",
            "MAXIS", "NEX", "UNI", "BFG", "FIRE", "VRED",

            // Marche europee e asiatiche
            "GISLAVED", "SEMPERIT", "BARUM", "FULDA", "SAVA",
            "NANKANG", "TRIANGLE", "LINGLONG", "DOUBLE COIN",
            "FEDERAL", "LANVIGATOR", "SUNNY", "ROTALLA",
            "NORAUTO", "BLACKLION", "TRACMAX", "ROADSTONE",

            // Marche premium e specialistiche
            "AVON", "METZELER", "SPORTCONTACT", "PILOT SPORT",
            "ASYMMETRIC", "CINTURATO", "ENERGY", "EFFICIENTGRIP"
        ]

        // Prima cerca match esatti
        for brand in brands {
            if text.contains(brand) {
                return brand
            }
        }

        // Poi cerca match parziali (minimo 4 caratteri)
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if cleanWord.count >= 4 {
                for brand in brands {
                    // Fuzzy matching - permette 1 carattere di differenza
                    if brand.count >= 4 && abs(brand.count - cleanWord.count) <= 2 {
                        let similarity = calculateSimilarity(brand, cleanWord)
                        if similarity >= 0.7 { // 70% di similarità
                            return brand
                        }
                    }
                }
            }
        }

        return nil
    }

    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let len1 = str1.count
        let len2 = str2.count
        let maxLen = max(len1, len2)

        if maxLen == 0 { return 1.0 }

        let distance = levenshteinDistance(str1, str2)
        return Double(maxLen - distance) / Double(maxLen)
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let len1 = str1Array.count
        let len2 = str2Array.count

        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)

        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }

        for i in 1...len1 {
            for j in 1...len2 {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[len1][len2]
    }
    
    private func extractDOT(from text: String) -> String? {
        // Cerca semplicemente sequenze di 4 cifre che possano essere DOT
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if cleanWord.count == 4, let numericCode = Int(cleanWord) {
                // Verifica che sia un possibile DOT (anni dal 2000 in poi)
                let year = numericCode % 100
                if year >= 0 && year <= 50 {
                    return cleanWord
                }
            }
        }
        return nil
    }

    private func extractSeason(from text: String) -> String? {
        let upperText = text.uppercased()

        // Indicatori invernali
        let winterIndicators = [
            "WINTER", "INVERNO", "SNOW", "NEVE", "ICE", "GHIACCIO",
            "M+S", "M&S", "MS", "MUD", "FANGO", "3PMSF"
        ]

        // Indicatori estivi
        let summerIndicators = [
            "SUMMER", "ESTATE", "ESTIVO"
        ]

        // Indicatori quattro stagioni
        let allSeasonIndicators = [
            "ALL SEASON", "ALL-SEASON", "ALLSEASON", "4 SEASON",
            "QUATTRO STAGIONI", "4SEASON", "ALL WEATHER"
        ]

        // Cerca indicatori di quattro stagioni per primi (più specifici)
        for indicator in allSeasonIndicators {
            if upperText.contains(indicator) {
                return "All Season"
            }
        }

        // Cerca indicatori invernali
        for indicator in winterIndicators {
            if upperText.contains(indicator) {
                return "Winter"
            }
        }

        // Cerca indicatori estivi
        for indicator in summerIndicators {
            if upperText.contains(indicator) {
                return "Summer"
            }
        }

        return nil
    }
    
    private func extractLoadAndSpeed(from text: String, into data: inout TireData) {
        // Pattern per load index + speed rating (es: "91V", "225/55R17 91V")
        let pattern = #"(\d{2,3})([A-Z])\b"#
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let loadRange = Range(match.range(at: 1), in: text),
                   let speedRange = Range(match.range(at: 2), in: text) {
                    
                    let loadValue = String(text[loadRange])
                    let speedValue = String(text[speedRange])
                    
                    // Verifica che sia un load index valido (tipicamente 60-120)
                    if let loadInt = Int(loadValue), loadInt >= 60 && loadInt <= 120 {
                        // Aggiorna solo se i campi sono vuoti
                        if data.loadIndex.isEmpty {
                            data.loadIndex = loadValue
                        }
                        if data.speedRating.isEmpty {
                            data.speedRating = speedValue
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Vista principale aggiornata
struct TyreRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ocrManager = TireOCRManager()
    @State private var showExtractedData = true
    @State private var navigateToConfirm = false
    @State private var isFlashOn = false

    // Computed property per verificare se tutti i dati essenziali sono stati raccolti
    private var allEssentialDataCollected: Bool {
        let data = ocrManager.extractedData
        return !data.brand.isEmpty &&
               !data.size.isEmpty &&
               !data.loadIndex.isEmpty &&
               !data.speedRating.isEmpty &&
               !data.dot.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 29)
                
                // Header
                HStack {
                    Text("Tire Registration")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Pulsante reset dati
                    Button(action: {
                        ocrManager.resetExtractedData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .padding(8)
                    }

                    // Pulsante flash
                    Button(action: {
                        isFlashOn.toggle()
                        ocrManager.toggleFlash(isFlashOn)
                    }) {
                        Image(systemName: isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundColor(isFlashOn ? .yellow : .white)
                            .padding(8)
                    }

                    Button(action: { showExtractedData.toggle() }) {
                        Image(systemName: showExtractedData ? "text.viewfinder" : "camera.viewfinder")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.customBackgroundColor)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                
                // Camera con OCR
                ZStack {
                    Circle()
                        .stroke(
                            style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                        )
                        .foregroundColor(.white)
                        .frame(width: 360, height: 360)

                    OCRCameraPreview(ocrManager: ocrManager)
                        .frame(width: 350, height: 350)
                        .clipShape(Circle())

                }
                .padding(.bottom, 20)
                
                // Dati estratti
                if showExtractedData {
                    ScrollView {
                        ExtractedDataView(data: ocrManager.extractedData)
                    }
                    .frame(maxHeight: 300)
                    .padding(.horizontal, 24)
                }
                
                // Istruzioni
                VStack(spacing: 8) {
                    Text("Tire Sidewall Scanning")
                        .font(.customFont(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Get close to tire sidewall")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Move camera slowly to scan text")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Follow guide lines for coverage")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .onChange(of: allEssentialDataCollected) {
                if allEssentialDataCollected {
                    // Feedback tattile per successo
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    // Pausa di 1 secondo per permettere all'utente di vedere i dati raccolti
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        navigateToConfirm = true
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                ConfirmDetailsTyreView(tireData: ocrManager.extractedData)
                    .navigationBarBackButtonHidden(true)
                    .background(InteractivePopGestureEnabler())
            }
            }
        }
    }
}






// MARK: - Vista dati estratti essenziali
struct ExtractedDataView: View {
    let data: TireData

    private var completionPercentage: Double {
        // Campi essenziali (richiesti)
        let essentialFields = [data.brand, data.size, data.loadIndex, data.speedRating, data.dot]
        let essentialCompleted = essentialFields.filter { !$0.isEmpty }.count

        // La stagionalità è opzionale, quindi non influisce sulla percentuale di completamento
        return Double(essentialCompleted) / Double(essentialFields.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header con progress
            HStack {
                Text("Tire Data")
                    .font(.customFont(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Progress indicator
                HStack(spacing: 4) {
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(completionPercentage == 1.0 ? .green : .yellow)

                    ProgressView(value: completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: completionPercentage == 1.0 ? .green : .yellow))
                        .frame(width: 60)
                }
            }

            // Dati essenziali con stato
            VStack(spacing: 12) {
                EssentialDataRow(
                    icon: "textformat.size",
                    label: "Size",
                    value: data.size,
                    isCompleted: !data.size.isEmpty
                )

                EssentialDataRow(
                    icon: "tag.fill",
                    label: "Brand",
                    value: data.brand,
                    isCompleted: !data.brand.isEmpty
                )

                EssentialDataRow(
                    icon: "speedometer",
                    label: "Load Index",
                    value: data.loadIndex,
                    isCompleted: !data.loadIndex.isEmpty
                )

                EssentialDataRow(
                    icon: "gauge.high",
                    label: "Speed Rating",
                    value: data.speedRating,
                    isCompleted: !data.speedRating.isEmpty
                )

                EssentialDataRow(
                    icon: "calendar",
                    label: "DOT Code",
                    value: data.dot,
                    isCompleted: !data.dot.isEmpty
                )

                EssentialDataRow(
                    icon: "snowflake",
                    label: "Season",
                    value: data.season.isEmpty ? "Auto-detecting..." : data.season,
                    isCompleted: !data.season.isEmpty
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                completionPercentage == 1.0 ?
                                    LinearGradient(colors: [.green.opacity(0.8), .green.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: completionPercentage == 1.0 ? 2 : 1
                            )
                    )
                    .shadow(
                        color: completionPercentage == 1.0 ? .green.opacity(0.3) : .black.opacity(0.2),
                        radius: completionPercentage == 1.0 ? 10 : 5,
                        x: 0,
                        y: 5
                    )
            )

            // Messaggio di stato
            if completionPercentage == 1.0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All data collected! Redirecting...")
                        .font(.customFont(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("Keep scanning to collect all tire information")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completionPercentage)
    }
}

// MARK: - Componente per riga dati essenziali
struct EssentialDataRow: View {
    let icon: String
    let label: String
    let value: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon con stato
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .green : .white.opacity(0.5))
                .frame(width: 20)

            // Label
            Text(label)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 80, alignment: .leading)

            // Value o placeholder
            if isCompleted {
                Text(value)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("Scanning...")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
            }

            Spacer()

            // Status indicator
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isCompleted ? .green : .white.opacity(0.3))
        }
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Camera Preview per OCR
struct OCRCameraPreview: UIViewRepresentable {
    let ocrManager: TireOCRManager
    
    func makeUIView(context: Context) -> OCRCameraView {
        let cameraView = OCRCameraView()
        cameraView.ocrManager = ocrManager
        return cameraView
    }
    
    func updateUIView(_ uiView: OCRCameraView, context: Context) {}
}

class OCRCameraView: UIView {
    var ocrManager: TireOCRManager?
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var frameCounter = 0
    private var camera: AVCaptureDevice?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if captureSession == nil {
            setupCamera()
            setupFlashObserver()
        }
        previewLayer?.frame = bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        self.camera = device
        
        captureSession.addInput(input)
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_queue"))
        captureSession.addOutput(videoOutput)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func setupFlashObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFlashToggle(_:)),
            name: .flashToggle,
            object: nil
        )
    }

    @objc private func handleFlashToggle(_ notification: Notification) {
        guard let isOn = notification.object as? Bool else { return }
        toggleFlash(isOn)
    }

    private func toggleFlash(_ isOn: Bool) {
        guard let camera = camera, camera.hasTorch else { return }

        do {
            try camera.lockForConfiguration()
            if isOn && camera.isTorchAvailable {
                camera.torchMode = .on
            } else {
                camera.torchMode = .off
            }
            camera.unlockForConfiguration()
        } catch {
            print("Error controlling flash: \(error)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension OCRCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Processa ogni 30 frame per evitare sovraccarico
        frameCounter += 1
        guard frameCounter % 30 == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        ocrManager?.extractTextFromImage(cgImage)
    }
}

