import Foundation
import SwiftUI
import AVFoundation
import Vision

// Memory monitoring structure
struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}

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
    var vehicleId: Int = 0
}

// MARK: - OCR Manager
class TireOCRManager: NSObject, ObservableObject {
    @Published var extractedData = TireData()
    @Published var isProcessing = false
    @Published var tireDetected = false

    private var textRecognitionRequest: VNRecognizeTextRequest!
    
    // Static data to avoid memory allocation on each call
    private static let primaryBrands: Set<String> = [
        "MICHELIN", "BRIDGESTONE", "PIRELLI", "CONTINENTAL", "GOODYEAR",
        "DUNLOP", "YOKOHAMA", "HANKOOK", "KUMHO", "TOYO", "NOKIAN",
        "FALKEN", "COOPER", "MAXXIS", "NEXEN", "UNIROYAL", "GENERAL",
        "BF GOODRICH", "FIRESTONE", "VREDESTEIN", "GISLAVED", "SEMPERIT",
        "BARUM", "FULDA", "AVON", "METZELER", "NORAUTO"
    ]
    
    private static let brandAbbreviations: [String: String] = [
        "MICH": "MICHELIN", "BRIDGE": "BRIDGESTONE", "CONT": "CONTINENTAL",
        "GOOD": "GOODYEAR", "YOKO": "YOKOHAMA", "HANK": "HANKOOK",
        "BFG": "BF GOODRICH", "FIRE": "FIRESTONE"
    ]

    private static let knownModelsByBrand: [String: [String]] = [
        "MICHELIN": [
            "PILOT SPORT", "PILOT SPORT 4", "PILOT SUPER SPORT", "PILOT SPORT CUP",
            "PRIMACY", "PRIMACY 4", "CROSSCLIMATE", "CROSSCLIMATE 2", "LATITUDE",
            "ENERGY SAVER", "DEFENDER", "X-ICE", "ALPIN", "AGILIS", "LTX"
        ],
        "PIRELLI": [
            "CINTURATO", "CINTURATO P7", "CINTURATO ALL SEASON", "P ZERO", "PZERO",
            "P ZERO CORSA", "SCORPION", "SCORPION VERDE", "SCORPION WINTER",
            "SCORPION ZERO", "WINTER SOTTOZERO", "POWERGY", "CARRIER", "P6000"
        ],
        "CONTINENTAL": [
            "CONTISPORTCONTACT", "CONTISPORTCONTACT 5", "CONTISPORTCONTACT 6",
            "CONTIPREMIUMCONTACT", "PREMIUMCONTACT 6", "CONTIPROCONTACT",
            "EXTREMECONTACT", "CONTIWINTERCONTACT", "ALLSEASONCONTACT",
            "CROSSCONTACT", "ECOCONTACT", "VIKINGCONTACT", "VANCONTACT", "ICECONTACT"
        ],
        "BRIDGESTONE": [
            "POTENZA", "POTENZA S001", "POTENZA SPORT", "TURANZA", "TURANZA T005",
            "DUELER", "DUELER H/P", "BLIZZAK", "ECOPIA", "ALENZA", "WEATHERPEAK",
            "DRIVEGUARD", "RE050"
        ],
        "GOODYEAR": [
            "EAGLE", "EAGLE F1", "EFFICIENTGRIP", "EFFICIENTGRIP PERFORMANCE",
            "VECTOR", "VECTOR 4SEASONS", "ULTRAGRIP", "WRANGLER", "ASSURANCE",
            "DURAGRIP", "EXCELLENCE"
        ],
        "DUNLOP": [
            "SPORT MAXX", "SPORT MAXX RT", "SPORT BLURESPONSE", "WINTER SPORT",
            "SP WINTER", "GRANDTREK", "STREETRESPONSE"
        ],
        "YOKOHAMA": [
            "ADVAN", "ADVAN SPORT", "ADVAN FLEVA", "BLUEARTH", "BLUEARTH AE",
            "GEOLANDAR", "ICEGUARD", "PARADA", "S.DRIVE"
        ],
        "HANKOOK": [
            "VENTUS", "VENTUS S1 EVO", "VENTUS PRIME", "KINERGY", "KINERGY 4S",
            "DYNAPRO", "WINTER ICEPT", "I PIKE"
        ],
        "KUMHO": [
            "ECSTA", "ECSTA PS", "SOLUS", "SOLUS 4S", "CRUGEN", "WINTERCRAFT",
            "ROAD VENTURE", "PORTRAN"
        ],
        "NOKIAN": [
            "HAKKAPELIITTA", "NORDMAN", "POWERPROOF", "SEASONPROOF", "WEATHERPROOF",
            "WR SUV", "SNOWPROOF"
        ],
        "FALKEN": [
            "AZENIS", "ZIEX", "EUROWINTER", "WILDPEAK", "SN832"
        ],
        "TOYO": [
            "PROXES", "PROXES SPORT", "OPEN COUNTRY", "OBSERVE", "NANOENERGY", "CELSIUS"
        ],
        "NEXEN": [
            "N'FERA", "NFERA", "ROADIAN", "WINGUARD", "NBLUE"
        ],
        "GENERAL": [
            "GRABBER", "ALTIMAX"
        ],
        "BF GOODRICH": [
            "ALL TERRAIN", "ADVANTAGE", "G-FORCE", "TRAIL-TERRAIN", "KO2"
        ],
        "FIRESTONE": [
            "DESTINATION", "ROADHAWK", "MULTISEASON", "WINTERHAWK", "TZ300"
        ],
        "COOPER": [
            "ZEON", "DISCOVERER", "WEATHERMASTER", "EVOLUTION"
        ],
        "MAXXIS": [
            "PREMITRA", "BRAVO", "VICTRA", "MA-Z1", "MAZ1"
        ],
        "UNIROYAL": [
            "RAINSPORT", "RAINEXPERT", "ALLSEASONEXPERT", "WINTEREXPERT"
        ],
        "VREDESTEIN": [
            "QUATRAC", "SPORTRAC", "ULTRAC", "WINTRAC"
        ]
    ]

    private static let modelSearchIndex: [(pattern: String, model: String, brand: String)] = {
        var entries: [(String, String, String)] = []
        for (brand, models) in TireOCRManager.knownModelsByBrand {
            for model in models {
                let upperModel = model.uppercased()
                entries.append((upperModel, model, brand))

                let compact = upperModel
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: ".", with: "")
                if compact != upperModel {
                    entries.append((compact, model, brand))
                }
            }
        }
        return entries
    }()

    // Metodo per resettare i dati catturati
    func resetExtractedData() {
        extractedData = TireData()
        tireDetected = false
    }

    // Metodo per controllare il flash
    func toggleFlash(_ isOn: Bool, intensity: Float = 0.3) {
        NotificationCenter.default.post(
            name: .flashToggle,
            object: nil,
            userInfo: [
                "isOn": isOn,
                "level": intensity
            ]
        )
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


        textRecognitionRequest.recognitionLevel = .accurate // Changed from .accurate for speed
        textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.recognitionLanguages = ["en-US"]
        textRecognitionRequest.minimumTextHeight = 0.01 // Skip very small text
    }
    
    func extractTextFromImage(_ image: CGImage) {
        // Skip if already processing to avoid queue buildup
        guard !isProcessing else { 
            print("OCR already processing, skipping frame")
            return 
        }
        
        // Check available memory before processing
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        // Skip processing if memory usage is too high (> 300MB - more reasonable limit)
        if kerr == KERN_SUCCESS {
            let memoryUsage = memoryInfo.resident_size
            if memoryUsage > 800_000_000 {
                print("Memory usage too high: \(memoryUsage / 1_000_000)MB, skipping OCR")
                return
            }
        }
        
        // Validate image dimensions
        guard image.width > 0 && image.height > 0 && image.width <= 2000 && image.height <= 2000 else {
            print("Image dimensions invalid: \(image.width)x\(image.height)")
            return
        }
        
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isProcessing = true
                self.tireDetected = true
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                // Add timeout to prevent hanging
                let timeoutQueue = DispatchQueue.global(qos: .utility)
                let timeoutItem = DispatchWorkItem { [weak self] in
                    print("OCR timeout - resetting processing state")
                    DispatchQueue.main.async { [weak self] in
                        self?.isProcessing = false
                    }
                }
                
                timeoutQueue.asyncAfter(deadline: .now() + 2.0, execute: timeoutItem)
                
                try handler.perform([self.textRecognitionRequest])
                
                // Cancel timeout if processing completes successfully
                timeoutItem.cancel()
                
            } catch {
                print("OCR failed: \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isProcessing = false
                }
            }
        }
    }
    
    
    /// Contrast Limited Adaptive Histogram Equalization
    private func applyCLAHE(to image: CIImage) -> CIImage? {
        // Use a simpler approach since CGColorSpace.lab is not available
        // Apply selective histogram equalization using tone curve
        let enhancedImage = image
            .applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0),
                "inputPoint1": CIVector(x: 0.25, y: 0.35), // Shadow lift
                "inputPoint2": CIVector(x: 0.5, y: 0.55),  // Midtone adjustment
                "inputPoint3": CIVector(x: 0.75, y: 0.8),  // Highlight compression
                "inputPoint4": CIVector(x: 1, y: 1)
            ])
        
        return enhancedImage
    }
    
    /// Advanced noise reduction with edge preservation using bilateral filtering
    private func applyAdvancedDenoise(to image: CIImage) -> CIImage? {
        // Multi-scale bilateral filtering for edge-preserving smoothing
        let smoothed1 = image.applyingFilter("CINoiseReduction", parameters: [
            "inputSharpness": 0.8,
            "inputNoiseLevel": 0.15
        ])
        
        // Gaussian blur with small sigma for fine detail preservation
        let blurred = smoothed1.applyingFilter("CIGaussianBlur", parameters: [
            "inputRadius": 0.7
        ])
        
        // Combine original and blurred using difference of gaussians
        guard let composite = CIFilter(name: "CIBlendWithMask") else { return nil }
        composite.setValue(smoothed1, forKey: kCIInputImageKey)
        composite.setValue(blurred, forKey: kCIInputBackgroundImageKey)
        
        // Create mask based on edge detection
        let edgeMask = image
            .applyingFilter("CIEdges", parameters: ["inputIntensity": 2.0])
            .applyingFilter("CIColorInvert")
        
        composite.setValue(edgeMask, forKey: kCIInputMaskImageKey)
        return composite.outputImage
    }
    
    /// Unsharp masking for text enhancement
    private func applyUnsharpMask(to image: CIImage) -> CIImage? {
        // Create unsharp mask using difference of gaussians
        let blurred = image.applyingFilter("CIGaussianBlur", parameters: [
            "inputRadius": 1.5
        ])
        
        guard let unsharpMask = CIFilter(name: "CISubtractBlendMode") else { return nil }
        unsharpMask.setValue(image, forKey: kCIInputImageKey)
        unsharpMask.setValue(blurred, forKey: kCIInputBackgroundImageKey)
        
        guard let maskResult = unsharpMask.outputImage else { return nil }
        
        // Apply mask with controlled intensity
        guard let finalMask = CIFilter(name: "CIColorMatrix") else { return nil }
        finalMask.setValue(maskResult, forKey: kCIInputImageKey)
        finalMask.setValue(CIVector(x: 2.0, y: 0, z: 0, w: 0), forKey: "inputRVector") // Amplify contrast
        finalMask.setValue(CIVector(x: 0, y: 2.0, z: 0, w: 0), forKey: "inputGVector")
        finalMask.setValue(CIVector(x: 0, y: 0, z: 2.0, w: 0), forKey: "inputBVector")
        
        guard let amplifiedMask = finalMask.outputImage else { return nil }
        
        // Combine with original
        guard let finalComposite = CIFilter(name: "CIAdditionCompositing") else { return nil }
        finalComposite.setValue(image, forKey: kCIInputImageKey)
        finalComposite.setValue(amplifiedMask, forKey: kCIInputBackgroundImageKey)
        
        return finalComposite.outputImage
    }
    
    /// Simple perspective correction using transform-based approach
    private func applyPerspectiveCorrection(to image: CIImage) -> CIImage? {
        // Apply a mild perspective transform to help with typical tire viewing angles
        // Since keystone correction filters have complex parameters, use a simpler transform approach
        let transform = CGAffineTransform.identity
            .scaledBy(x: 1.02, y: 0.98)  // Slight adjustment for perspective
            .rotated(by: 0.01)           // Minor rotation correction
        
        let correctedImage = image.transformed(by: transform)
        
        // Ensure the image stays within reasonable bounds
        let extent = correctedImage.extent
        if extent.width > 0 && extent.height > 0 && 
           extent.width < 5000 && extent.height < 5000 {
            return correctedImage
        } else {
            // Return original if transform created invalid dimensions
            return image
        }
    }
    
    /// Morphological operations for text cleanup
    private func applyMorphologicalOperations(to image: CIImage) -> CIImage? {
        // Convert to monochrome for morphological operations
        let monochrome = image.applyingFilter("CIColorControls", parameters: [
            "inputSaturation": 0.0,
            "inputContrast": 1.3,
            "inputBrightness": 0.1
        ])
        
        // Apply morphological opening (erosion followed by dilation) to clean up text
        let cleaned = monochrome.applyingFilter("CIMorphologyGradient", parameters: [
            "inputRadius": 0.5
        ])
        
        // Final contrast enhancement
        return cleaned.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0.1),
            "inputPoint1": CIVector(x: 0.3, y: 0.2),
            "inputPoint2": CIVector(x: 0.7, y: 0.8),
            "inputPoint3": CIVector(x: 1, y: 0.95)
        ])
    }
    
    private func processTextResults(_ observations: [VNRecognizedTextObservation]) {
        // Thread-safe access to extractedData
        var updatedData = TireData()
        DispatchQueue.main.sync { [weak self] in
            updatedData = self?.extractedData ?? TireData()
        }
        
        var allDetectedText: [String] = []
        
        // Sort observations by bounding box area (descending) to prioritize larger text
        let sortedObservations = observations.sorted {
            ($0.boundingBox.width * $0.boundingBox.height) > ($1.boundingBox.width * $1.boundingBox.height)
        }
        
        // Limit number of observations more aggressively
        let limitedObservations = sortedObservations.prefix(10)
        
        // Extract all detected text
        for observation in limitedObservations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let confidence = Double(topCandidate.confidence)
            
            // Less restrictive text filtering for better detection
            if !text.isEmpty && text.count >= 2 && text.count <= 50 { // Reduced max length from 80 to 50
                allDetectedText.append(text)
                
                // Extract specific data
                do {
                    try extractSpecificDataWithConfidence(from: text, confidence: confidence, into: &updatedData)
                } catch {
                    continue
                }
            }
        }
        
        // Limit text accumulation
        let combinedText = Set(updatedData.allText + allDetectedText)
        let limitedText = Array(combinedText).prefix(20) // Reduced from 30 to 20
        updatedData.allText = Array(limitedText).sorted()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.extractedData = updatedData
            self.isProcessing = false
        }
    }
    
    /// Advanced extraction with confidence weighting
    private func extractSpecificDataWithConfidence(from text: String, confidence: Double, into data: inout TireData) throws {
        guard text.count <= 50 else { // Reduced from 100 to 50
            throw NSError(domain: "TextTooLong", code: 1, userInfo: nil)
        }
        
        let upperText = text.uppercased()
        let weightedConfidence = confidence
        
        // Store extraction candidates with confidence scores
        var extractionCandidates: [String: (value: String, confidence: Double)] = [:]
        
        // Extract dimensions with confidence
        if data.size.isEmpty {
            if let sizeMatch = try? extractTireSize(from: upperText) {
                let sizeConfidence = validateTireSize(sizeMatch) * weightedConfidence
                extractionCandidates["size"] = (sizeMatch, sizeConfidence)
            }
        }
        
        // Extract brand with confidence
        if data.brand.isEmpty {
            if let brandMatch = extractBrand(from: upperText) {
                let brandConfidence = calculateBrandConfidence(brandMatch, in: upperText) * weightedConfidence
                extractionCandidates["brand"] = (brandMatch, brandConfidence)
            }
        }
        
        // Extract model with confidence
        if data.model.isEmpty {
            if let modelResult = extractModel(from: upperText, brand: data.brand) {
                let modelBrand = modelResult.inferredBrand ?? data.brand
                let modelConfidence = calculateModelConfidence(modelResult.model, brand: modelBrand) * weightedConfidence
                extractionCandidates["model"] = (modelResult.model, modelConfidence)

                if data.brand.isEmpty, let inferredBrand = modelResult.inferredBrand {
                    let brandConfidence = calculateBrandConfidence(inferredBrand, in: upperText) * weightedConfidence
                    if let existing = extractionCandidates["brand"] {
                        if brandConfidence > existing.confidence {
                            extractionCandidates["brand"] = (inferredBrand, brandConfidence)
                        }
                    } else {
                        extractionCandidates["brand"] = (inferredBrand, brandConfidence)
                    }
                }
            }
        }
        
        // Extract DOT with confidence
        if data.dot.isEmpty {
            if let dotMatch = extractDOT(from: upperText) {
                let dotConfidence = validateDOTCode(dotMatch) * weightedConfidence
                extractionCandidates["dot"] = (dotMatch, dotConfidence)
            }
        }
        
        // Extract season with confidence
        if data.season.isEmpty {
            if let seasonMatch = extractSeason(from: upperText) {
                let seasonConfidence = calculateSeasonConfidence(seasonMatch, in: upperText) * weightedConfidence
                extractionCandidates["season"] = (seasonMatch, seasonConfidence)
            }
        }
        
        // Extract load and speed with confidence
        if data.loadIndex.isEmpty || data.speedRating.isEmpty {
            try? extractLoadAndSpeedWithConfidence(from: upperText, confidence: weightedConfidence, into: &data)
        }
        
        // Apply high-confidence extractions immediately
        for (field, candidate) in extractionCandidates {
            if candidate.confidence >= 0.5 { // Lowered from 0.6 to be even less restrictive
                switch field {
                case "size": data.size = candidate.value
                case "brand": data.brand = candidate.value
                case "model": data.model = candidate.value
                case "dot": data.dot = candidate.value
                case "season": data.season = candidate.value
                default: break
                }
            }
        }
    }
    
    /// Probabilistic data fusion to combine multiple observations
    private func applyProbabilisticDataFusion(to data: TireData, with confidenceMap: [String: Double]) -> TireData {
        var fusedData = data
        
        // Apply Bayesian inference for improving accuracy
        // This would combine multiple observations of the same data type
        
        return fusedData
    }
    
    /// Calculate brand confidence based on context
    private func calculateBrandConfidence(_ brand: String, in text: String) -> Double {
        var confidence = 0.8
        
        // Exact match increases confidence
        if text.contains(brand) {
            confidence = 1.0
        }
        
        // Context clues increase confidence
        let brandContext = ["TIRE", "TYRE", "PNEUMATIC", "RUBBER"]
        for context in brandContext {
            if text.contains(context) {
                confidence *= 1.1
                break
            }
        }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate model confidence
    private func calculateModelConfidence(_ model: String, brand: String) -> Double {
        let upperModel = model.uppercased()
        let upperBrand = brand.uppercased()

        if let models = Self.knownModelsByBrand[upperBrand],
           models.contains(where: { upperModel.contains($0) || $0.contains(upperModel) }) {
            return 1.0
        }

        // If brand is unknown, see if the model matches any catalog to boost confidence
        for (_, models) in Self.knownModelsByBrand {
            if models.contains(where: { upperModel.contains($0) || $0.contains(upperModel) }) {
                return 0.85
            }
        }

        return 0.7
    }
    
    /// Calculate season confidence
    private func calculateSeasonConfidence(_ season: String, in text: String) -> Double {
        let seasonIndicators: [String: [String]] = [
            "Winter": ["WINTER", "SNOW", "ICE", "M+S", "3PMSF"],
            "Summer": ["SUMMER", "ESTIVO"],
            "All Season": ["ALL SEASON", "4SEASON", "ALL WEATHER"]
        ]
        
        if let indicators = seasonIndicators[season] {
            for indicator in indicators {
                if text.contains(indicator) {
                    return 1.0
                }
            }
        }
        
        return 0.7
    }
    
    /// Extract load and speed with confidence scoring
    private func extractLoadAndSpeedWithConfidence(from text: String, confidence: Double, into data: inout TireData) throws {
        guard text.count <= 200 else { 
            throw NSError(domain: "TextTooLong", code: 1, userInfo: nil)
        }
        
        let pattern = #"(\d{2,3})([A-Z])\b"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            var bestLoadSpeed: (load: String, speed: String, confidence: Double) = ("", "", 0.0)
            
            for match in matches {
                if let loadRange = Range(match.range(at: 1), in: text),
                   let speedRange = Range(match.range(at: 2), in: text) {
                    
                    let loadValue = String(text[loadRange])
                    let speedValue = String(text[speedRange])
                    
                    if let loadInt = Int(loadValue), loadInt >= 60 && loadInt <= 120 {
                        let combinedConfidence = validateLoadSpeedCombination(load: loadInt, speed: speedValue) * confidence
                        
                        if combinedConfidence > bestLoadSpeed.confidence {
                            bestLoadSpeed = (loadValue, speedValue, combinedConfidence)
                        }
                    }
                }
            }
            
            if bestLoadSpeed.confidence >= 0.7 {
                if data.loadIndex.isEmpty {
                    data.loadIndex = bestLoadSpeed.load
                }
                if data.speedRating.isEmpty {
                    data.speedRating = bestLoadSpeed.speed
                }
            }
        } catch {
            throw error
        }
    }
    
    /// Validate load and speed rating combination
    private func validateLoadSpeedCombination(load: Int, speed: String) -> Double {
        let validSpeedRatings = ["L", "M", "N", "P", "Q", "R", "S", "T", "U", "H", "V", "W", "Y", "Z"]
        
        guard validSpeedRatings.contains(speed) else {
            return 0.3
        }
        
        // Mathematical validation of load-speed correlation
        let speedIndex = validSpeedRatings.firstIndex(of: speed) ?? 0
        
        // Higher loads typically correlate with higher speed ratings
        let expectedSpeedRange = (load - 70) / 10  // Rough correlation
        
        if abs(speedIndex - expectedSpeedRange) <= 3 {
            return 1.0
        } else {
            return 0.8
        }
    }
    
    private func extractSpecificData(from text: String, into data: inout TireData) throws {
        // Less restrictive text length check
        guard text.count <= 100 else { // Increased from 50 to 100
            throw NSError(domain: "TextTooLong", code: 1, userInfo: nil)
        }
        
        let upperText = text.uppercased()
        
        // Extract dimensions only if not already present
        if data.size.isEmpty {
            if let sizeMatch = try? extractTireSize(from: upperText) {
                data.size = sizeMatch
            }
        }
        
        // Extract brand only if not already present
        if data.brand.isEmpty {
            if let brandMatch = extractBrand(from: upperText) {
                data.brand = brandMatch
            }
        }

        if data.model.isEmpty {
            if let modelResult = extractModel(from: upperText, brand: data.brand) {
                data.model = modelResult.model
                if data.brand.isEmpty, let inferredBrand = modelResult.inferredBrand {
                    data.brand = inferredBrand
                }
            }
        }

        // Extract DOT only if not already present
        if data.dot.isEmpty {
            if let dotMatch = extractDOT(from: upperText) {
                data.dot = dotMatch
            }
        }

        // Extract season only if not already present
        if data.season.isEmpty {
            if let seasonMatch = extractSeason(from: upperText) {
                data.season = seasonMatch
            }
        }

        // Extract load index and speed rating only if not already present
        if data.loadIndex.isEmpty || data.speedRating.isEmpty {
            try? extractLoadAndSpeed(from: upperText, into: &data)
        }
    }
    
    private func extractTireSize(from text: String) -> String? {
        guard text.count <= 200 else { return nil }

        // Advanced tire size pattern recognition using mathematical precision
        let advancedPatterns = [
            // Standard patterns with mathematical validation
            #"(\d{3}\/\d{2}\s?R\s?\d{2})"#,     // 225/55R17 o 225/55 R 17
            #"(\d{3}\/\d{2}-\d{2})"#,            // 225/55-17
            #"(\d{3}\s\d{2}\s?R\s?\d{2})"#,     // 225 55 R17 o 225 55R17
            #"(\d{3}\/\d{2}ZR\s?\d{2})"#,       // 225/55ZR17 o 225/55ZR 17
            #"(\d{3}\/\d{2}\/R\s?\d{2})"#,      // Alternative format
            #"(\d{2,3}x\d{2}R?\s?\d{2})"#,      // Metric format
            #"(P\d{3}\/\d{2}R\s?\d{2})"#        // P-metric
        ]
        
        var bestMatch: (size: String, confidence: Double) = ("", 0.0)
        
        for pattern in advancedPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        var candidate = String(text[range])
                        // Normalizza il formato rimuovendo spazi multipli e formattando correttamente
                        candidate = candidate.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                        // Formatta in modo standard: 255/35R19
                        let confidence = validateTireSize(candidate)

                        if confidence > bestMatch.confidence {
                            bestMatch = (candidate, confidence)
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        // Return match only if confidence is high enough (abbassata da 0.8 a 0.6)
        return bestMatch.confidence >= 0.6 ? bestMatch.size : nil
    }
    
    /// Mathematical validation of tire size using industry standards
    private func validateTireSize(_ size: String) -> Double {
        let cleanSize = size.uppercased().replacingOccurrences(of: " ", with: "")
        
        // Extract numeric components using regex
        guard let regex = try? NSRegularExpression(pattern: #"(\d{2,3})\/(\d{2}).*?(\d{2})"#) else {
            return 0.0
        }
        
        guard let match = regex.firstMatch(in: cleanSize, options: [], range: NSRange(cleanSize.startIndex..., in: cleanSize)) else {
            return 0.0
        }

        // Try to extract each range, return 0.0 if any is not valid
        guard let widthRange = Range(match.range(at: 1), in: cleanSize) else { return 0.0 }
        guard let profileRange = Range(match.range(at: 2), in: cleanSize) else { return 0.0 }
        guard let diameterRange = Range(match.range(at: 3), in: cleanSize) else { return 0.0 }
        
        guard let width = Int(String(cleanSize[widthRange])),
              let profile = Int(String(cleanSize[profileRange])),
              let diameter = Int(String(cleanSize[diameterRange])) else {
            return 0.0
        }
        
        var confidence = 1.0
        
        // Mathematical validation based on tire industry standards
        // Width validation (typically 125-375mm for passenger cars)
        if width < 125 || width > 375 {
            confidence *= 0.3
        } else if width >= 155 && width <= 315 {
            confidence *= 1.0  // Most common range
        } else {
            confidence *= 0.8
        }
        
        // Profile validation (typically 25-85 for passenger cars)
        if profile < 25 || profile > 85 {
            confidence *= 0.4
        } else if profile >= 40 && profile <= 70 {
            confidence *= 1.0  // Most common range
        } else {
            confidence *= 0.9
        }
        
        // Diameter validation (typically 12-24 inches for passenger cars)
        if diameter < 12 || diameter > 24 {
            confidence *= 0.3
        } else if diameter >= 15 && diameter <= 20 {
            confidence *= 1.0  // Most common range
        } else {
            confidence *= 0.8
        }
        
        // Mathematical relationship validation
        // Aspect ratio should make sense with width
        let aspectRatio = Double(profile) / 100.0
        let calculatedHeight = Double(width) * aspectRatio
        
        // Reasonable height range validation
        if calculatedHeight < 20 || calculatedHeight > 200 {
            confidence *= 0.5
        }
        
        // Common size combination validation
        confidence *= validateCommonSizeCombination(width: width, profile: profile, diameter: diameter)
        
        return min(confidence, 1.0)
    }
    
    /// Validates against common tire size combinations in the industry
    private func validateCommonSizeCombination(width: Int, profile: Int, diameter: Int) -> Double {
        // Common combinations boost confidence
        let commonCombinations: [(width: ClosedRange<Int>, profile: ClosedRange<Int>, diameter: ClosedRange<Int>)] = [
            (width: 175...225, profile: 50...70, diameter: 14...18),  // Compact/Mid-size cars
            (width: 215...275, profile: 35...55, diameter: 17...20),  // Sports/Luxury cars
            (width: 225...285, profile: 40...70, diameter: 16...20),  // SUVs/Crossovers
            (width: 155...195, profile: 60...80, diameter: 13...16),  // Economy cars
            (width: 235...295, profile: 30...45, diameter: 18...22)   // High-performance/Sports cars (255/35R19, 265/40R20, etc.)
        ]
        
        for combo in commonCombinations {
            if combo.width.contains(width) && 
               combo.profile.contains(profile) && 
               combo.diameter.contains(diameter) {
                return 1.2  // Boost confidence for common combinations
            }
        }
        
        return 1.0  // Neutral for uncommon but potentially valid combinations
    }
    
    private func extractBrand(from text: String) -> String? {
        // Quick exit for very long text
        guard text.count <= 100 else { return nil }
        
        // Quick check for exact matches first (most efficient)
        for brand in Self.primaryBrands {
            if text.contains(brand) {
                return brand
            }
        }
        
        // Check abbreviations
        for (abbrev, fullName) in Self.brandAbbreviations {
            if text.contains(abbrev) {
                return fullName
            }
        }
        
        // Simple fuzzy matching for short text only
        guard text.count <= 30 else { return nil }
        
        let words = text.split(separator: " ", maxSplits: 5)
        for word in words.prefix(5) {
            let cleanWord = String(word).trimmingCharacters(in: .punctuationCharacters)
            guard cleanWord.count >= 4 && cleanWord.count <= 15 else { continue }
            
            // Simple similarity check - just compare with top 5 brands
            for brand in Self.primaryBrands.prefix(5) {
                let similarity = simpleStringSimilarity(brand, cleanWord)
                if similarity >= 0.75 {
                    return brand
                }
            }
        }
        
        return nil
    }
    
    // Simple similarity calculation without heavy algorithms
    private func simpleStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.uppercased()
        let s2 = str2.uppercased()
        
        if s1 == s2 { return 1.0 }
        
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.count == 0 { return 1.0 }
        
        let editDistance = levenshteinDistance(Array(longer), Array(shorter))
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    // Simple Levenshtein distance
    private func levenshteinDistance(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count, n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
    
    // Dynamic threshold calculation based on string characteristics
    private func calculateDynamicThreshold(brand: String, word: String) -> Double {
        let lengthDifference = abs(brand.count - word.count)
        let avgLength = Double(brand.count + word.count) / 2.0
        
        // More permissive threshold for shorter strings
        let baseThreshold: Double = 0.75
        let lengthPenalty = Double(lengthDifference) / avgLength * 0.1
        
        return max(0.65, baseThreshold - lengthPenalty)
    }

    // MARK: - Advanced String Matching Algorithms
    
    // Advanced string similarity using Levenshtein Distance with Wagner-Fischer algorithm
    private func advancedStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = Array(str1.uppercased())
        let s2 = Array(str2.uppercased())
        
        // Use Wagner-Fischer algorithm for optimal string alignment
        let levenshteinDistance = calculateLevenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        // Calculate similarity as 1 - normalized distance
        let similarity = 1.0 - (Double(levenshteinDistance) / Double(maxLength))
        
        // Apply Jaro-Winkler similarity for additional precision
        let jaroSimilarity = calculateJaroSimilarity(s1, s2)
        
        // Combine both metrics with weighted average
        return (similarity * 0.6) + (jaroSimilarity * 0.4)
    }
    
    // Wagner-Fischer algorithm for Levenshtein distance
    private func calculateLevenshteinDistance(_ s1: [Character], _ s2: [Character]) -> Int {
        let m = s1.count
        let n = s2.count
        
        // Create matrix for dynamic programming
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize base cases
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        // Fill the matrix using optimal substructure property
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // Jaro similarity algorithm
    private func calculateJaroSimilarity(_ s1: [Character], _ s2: [Character]) -> Double {
        let len1 = s1.count
        let len2 = s2.count
        
        guard len1 > 0 && len2 > 0 else { return 0.0 }
        
        let matchWindow = max(len1, len2) / 2 - 1
        guard matchWindow >= 0 else { return len1 == len2 ? 1.0 : 0.0 }
        
        var s1Matches = Array(repeating: false, count: len1)
        var s2Matches = Array(repeating: false, count: len2)
        
        var matches = 0
        var transpositions = 0
        
        // Find matches
        for i in 0..<len1 {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, len2)
            
            for j in start..<end {
                if s2Matches[j] || s1[i] != s2[j] { continue }
                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }
        
        guard matches > 0 else { return 0.0 }
        
        // Count transpositions
        var k = 0
        for i in 0..<len1 {
            if !s1Matches[i] { continue }
            while !s2Matches[k] { k += 1 }
            if s1[i] != s2[k] { transpositions += 1 }
            k += 1
        }
        
        let jaro = (Double(matches) / Double(len1) + 
                   Double(matches) / Double(len2) + 
                   Double(matches - transpositions/2) / Double(matches)) / 3.0
        
        return jaro
    }
    
    // N-gram based similarity for fuzzy matching
    private func calculateNGramSimilarity(_ str1: String, _ str2: String, n: Int = 2) -> Double {
        let s1 = str1.uppercased()
        let s2 = str2.uppercased()
        
        let ngrams1 = Set(generateNGrams(s1, n: n))
        let ngrams2 = Set(generateNGrams(s2, n: n))
        
        let intersection = ngrams1.intersection(ngrams2)
        let union = ngrams1.union(ngrams2)
        
        guard union.count > 0 else { return 0.0 }
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private func generateNGrams(_ string: String, n: Int) -> [String] {
        if string.count < n { return [string] }
        var ngrams: [String] = []
        let chars = Array(string)
        for i in 0..<(chars.count - n + 1) {
            let ngram = String(chars[i..<i+n])
            ngrams.append(ngram)
        }
        return ngrams
    }
    
    private func extractDOT(from text: String) -> String? {
        // Advanced DOT code extraction with mathematical validation
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        var bestCandidate: (code: String, confidence: Double) = ("", 0.0)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            // Look for DOT pattern variations
            let dotCandidates = extractDOTCandidates(from: cleanWord)
            
            for candidate in dotCandidates {
                let confidence = validateDOTCode(candidate)
                if confidence > bestCandidate.confidence {
                    bestCandidate = (candidate, confidence)
                }
            }
        }
        
        return bestCandidate.confidence >= 0.7 ? bestCandidate.code : nil
    }
    
    /// Extract potential DOT code candidates using pattern matching
    private func extractDOTCandidates(from text: String) -> [String] {
        var candidates: [String] = []
        
        // Standard 4-digit DOT code
        if text.count == 4, let _ = Int(text) {
            candidates.append(text)
        }
        
        // DOT code within longer string (e.g., "DOT1234" or "AB1234CD")
        let patterns = [
            #"DOT(\d{4})"#,
            #"(\d{4})"#
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        candidates.append(String(text[range]))
                    }
                }
            } catch {
                continue
            }
        }
        
        return candidates
    }
    
    /// Mathematical validation of DOT code using date algorithms
    private func validateDOTCode(_ code: String) -> Double {
        guard code.count == 4, let numericCode = Int(code) else {
            return 0.0
        }
        
        let week = numericCode / 100  // First two digits
        let year = numericCode % 100  // Last two digits
        
        var confidence = 1.0
        
        // Week validation (1-52/53)
        if week < 1 || week > 53 {
            confidence *= 0.1
        } else if week <= 52 {
            confidence *= 1.0
        } else {
            // Week 53 validation - mathematically possible but rare
            confidence *= 0.8
        }
        
        // Year validation based on current date and tire manufacturing reality
        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        
        if year > currentYear {
            // Future date - not valid
            confidence *= 0.0
        } else if year >= (currentYear - 10) {
            // Recent tire (within 10 years) - high confidence
            confidence *= 1.0
        } else if year >= 0 && year <= 50 {
            // 2000-2050 range assumption - medium confidence
            let ageInYears = (currentYear > year) ? (currentYear - year) : (currentYear + 100 - year)
            if ageInYears <= 20 {
                confidence *= 0.9
            } else {
                confidence *= 0.6  // Very old tire
            }
        } else {
            // Unlikely year range
            confidence *= 0.3
        }
        
        // Additional validation: check if it's a reasonable week for the year
        confidence *= validateWeekForYear(week: week, year: year)
        
        return min(confidence, 1.0)
    }
    
    /// Validates if a week number is reasonable for a given year
    private func validateWeekForYear(week: Int, year: Int) -> Double {
        // Calculate the actual number of weeks in the year using mathematical approach
        let fullYear = year <= 50 ? 2000 + year : 1900 + year
        let calendar = Calendar.current
        
        // Create date for the year
        guard let yearDate = calendar.date(from: DateComponents(year: fullYear, month: 1, day: 1)) else {
            return 0.8  // Default confidence if calculation fails
        }
        
        // Calculate weeks in year using ISO week numbering
        let weeksInYear = calendar.range(of: .weekOfYear, in: .year, for: yearDate)?.count ?? 52
        
        if week <= weeksInYear {
            return 1.0
        } else {
            return 0.3  // Week number exceeds actual weeks in year
        }
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

    private func extractModel(from text: String, brand: String) -> (model: String, inferredBrand: String?)? {
        let upperText = text.uppercased()
        let requestedBrand = brand.uppercased()

        if let modelsForBrand = Self.knownModelsByBrand[requestedBrand] {
            for model in modelsForBrand {
                let compactModel = model.replacingOccurrences(of: " ", with: "")
                if upperText.contains(model) || upperText.contains(compactModel) {
                    return (model.capitalized, requestedBrand)
                }
            }
        }

        for entry in Self.modelSearchIndex {
            if upperText.contains(entry.pattern) {
                return (entry.model.capitalized, entry.brand)
            }
        }

        var contextBrand = requestedBrand
        if contextBrand.isEmpty {
            for candidate in Self.primaryBrands {
                if upperText.contains(candidate) {
                    contextBrand = candidate
                    break
                }
            }
        }

        guard !contextBrand.isEmpty else { return nil }

        let lines = upperText.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.contains(contextBrand) {
                let words = line.components(separatedBy: CharacterSet.whitespaces)
                if let brandIndex = words.firstIndex(where: { $0.contains(contextBrand) }) {
                    let nextIndex = brandIndex + 1
                    guard nextIndex < words.count else { continue }

                    let endIndex = min(nextIndex + 2, words.count)
                    let remainingWords = Array(words[nextIndex..<endIndex])
                    let candidateModel = remainingWords.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)

                    let excludeWords = ["TIRE", "TYRE", "PNEUMATIC", "PNEUMATICO", "RADIAL", "STEEL", "BELT", "DOT", contextBrand]
                    let cleanModel = candidateModel.components(separatedBy: " ")
                        .filter { word in
                            !excludeWords.contains(word) &&
                            word.count > 2 &&
                            !word.allSatisfy({ $0.isNumber }) &&
                            !word.contains("/")
                        }
                        .joined(separator: " ")

                    if !cleanModel.isEmpty {
                        return (cleanModel.capitalized, contextBrand)
                    }
                }
            }
        }

        return nil
    }

    private func extractLoadAndSpeed(from text: String, into data: inout TireData) throws {
        guard text.count <= 200 else { 
            throw NSError(domain: "TextTooLong", code: 1, userInfo: nil)
        }
        
        // Pattern per load index + speed rating (es: "91V", "225/55R17 91V")
        let pattern = #"(\d{2,3})([A-Z])\b"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
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
        } catch {
            throw error
        }
    }
}

// MARK: - Vista principale aggiornata
struct TyreRegistrationView: View {
    var onConfirmCompletion: (() -> Void)? = nil
    var vehicleid: Int = 0
    var scanContext: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ocrManager = TireOCRManager()
    @State private var showExtractedData = true
    @State private var navigateToConfirm = false
    @State private var isFlashOn = false
    @State private var isCameraActive = true
    @State private var showRotationGuide = true


    // Computed property per verificare se tutti i dati essenziali sono stati raccolti
    private var allEssentialDataCollected: Bool {
        return !ocrManager.extractedData.brand.isEmpty &&
               !ocrManager.extractedData.size.isEmpty &&
               !ocrManager.extractedData.loadIndex.isEmpty &&
               !ocrManager.extractedData.speedRating.isEmpty &&
               !ocrManager.extractedData.dot.isEmpty
    }

    // Computed property per ottenere i dati con vehicleId assegnato
    private var tireDataWithVehicleId: TireData {
        var data = ocrManager.extractedData
        data.vehicleId = vehicleid
        return data
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
                    Text(L10n.tireRegistration.localized)
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
                        ocrManager.toggleFlash(isFlashOn, intensity: 0.3)
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
                    
                    Button(action: {
                        resetScanningSession()
                        dismiss()
                    }) {
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

                if let scanContext {
                    Text(scanContext)
                        .font(.customFont(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
                
                // Camera con OCR
                ZStack {
                    Circle()
                        .stroke(
                            style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                        )
                        .foregroundColor(.white)
                        .frame(width: 360, height: 360)

                    if isCameraActive {
                        OCRCameraPreview(ocrManager: ocrManager)
                            .frame(width: 350, height: 350)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 350, height: 350)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                    // AGGIUNGI LE GUIDE QUI
                             //              if showRotationGuide && ocrManager.tireDetected {
                             //                  RotationGuideOverlay(
                             //                      isScanning: $ocrManager.isProcessing,
                             //                      onRotationComplete: {
                             //                          showRotationGuide = false
                             //                      }
                             //                  )
                             //                  .allowsHitTesting(false)
                             //              }
                    
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
                    Text(L10n.tireSidewallScanning.localized)
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
                    // Stop camera session before navigating
                    isCameraActive = false
                    
                    // Feedback tattile per successo
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    // Pausa di 1 secondo per permettere all'utente di vedere i dati raccolti
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        navigateToConfirm = true
                    }
                }
            }
            .onChange(of: navigateToConfirm) {
                // This is triggered when the user returns from the confirmation view,
                // ensuring the scanning state is reset for a new session.
                if !navigateToConfirm {
                    resetScanningSession()
                }
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                ConfirmDetailsTyreView(
                    tireData: tireDataWithVehicleId,
                    onConfirm: { selectedSeason, confirmedModel in
                        handleTyreConfirmation(withSeason: selectedSeason, model: confirmedModel)
                    },
                    onCancel: {
                        resetScanningSession()
                    },
                    onConfirmCompletion: {
                        // Questa closure viene chiamata quando il viewModel.success diventa true
                        // Chiudi la navigazione e poi il fullScreenCover
                        navigateToConfirm = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            resetScanningSession()
                            onConfirmCompletion?()
                        }
                    }
                )
                .navigationBarBackButtonHidden(true)
                .background(InteractivePopGestureEnabler())
            }
            }
        }
        .onAppear { 
            isCameraActive = true
            resetScanningSession() 
        }
        .onDisappear {
            isCameraActive = false
            isFlashOn = false
            ocrManager.toggleFlash(false)
        }
    }

    private func handleTyreConfirmation(withSeason season: String, model: String) {
        // Aggiorna solo i dati, la chiusura è gestita da onConfirmCompletion in ConfirmDetailsTyreView
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        ocrManager.extractedData.season = season
        ocrManager.extractedData.model = normalizedModel
    }

    private func resetScanningSession() {
        isCameraActive = true
        isFlashOn = false
        ocrManager.toggleFlash(false)
        ocrManager.resetExtractedData()
        showExtractedData = true
        navigateToConfirm = false
    }
}





// MARK: - Vista dati estratti essenziali
struct ExtractedDataView: View {
    let data: TireData

    private var completionPercentage: Double {
        // Campi essenziali (richiesti)
        let essentialFields = [data.brand, data.size, data.loadIndex, data.speedRating, data.dot]
        let essentialCompleted = essentialFields.filter { !$0.isEmpty }.count

        // Modello e stagionalità sono opzionali, quindi non influiscono sulla percentuale di completamento
        return Double(essentialCompleted) / Double(essentialFields.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header con progress
            HStack {
                Text(L10n.tireData.localized)
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
                    icon: "textformat",
                    label: "Model",
                    value: data.model.isEmpty ? "Auto-detecting..." : data.model,
                    isCompleted: !data.model.isEmpty
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
        .scrollIndicators(.hidden)
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
    
    static func dismantleUIView(_ uiView: OCRCameraView, coordinator: ()) {
        uiView.stopCameraSession()
    }
}

class OCRCameraView: UIView {
    var ocrManager: TireOCRManager?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var frameCounter = 0
    private var camera: AVCaptureDevice?
    private var currentTorchLevel: Float = 0.3
    private var isSessionRunning = false
    
    func stopCameraSession() {
        guard let session = captureSession, isSessionRunning else { return }
        
        isSessionRunning = false
        
        // Turn off flash before stopping
        if let camera = camera, camera.hasTorch, camera.isTorchActive {
            do {
                try camera.lockForConfiguration()
                camera.torchMode = .off
                camera.unlockForConfiguration()
            } catch {
                print("Error turning off flash: \(error)")
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            session.stopRunning()
        }
    }
    
    func startCameraSession() {
        guard let session = captureSession, !isSessionRunning else { return }
        
        isSessionRunning = true
        DispatchQueue.global(qos: .utility).async {
            session.startRunning()
        }
    }

    /// Calculate dynamic frame processing interval based on device performance and current memory pressure
    private var frameInterval: Int {
        return 1
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.global(qos: .background).async { [weak captureSession] in
            captureSession?.stopRunning()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if captureSession == nil {
            setupCamera()
            setupFlashObserver()
        }
        previewLayer?.frame = bounds
    }
    

    // 1. Setup camera con risoluzione più alta
    private func setupCamera() {
        guard captureSession == nil else { return }
        
        let session = AVCaptureSession()
        
        // USA PHOTO per massima qualità (invece di .high o .medium)
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160  // 4K Ultra HD
            print("Using 4K capture preset")
        } else if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                self.camera = device
                session.addInput(input)
            }
            
            // Configura per massima qualità
            try device.lockForConfiguration()
            
            // Abilita tutti i formati ad alta risoluzione
            let formats = device.formats
            let highResFormats = formats.filter { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width >= 1920 && dimensions.height >= 1080
            }
            
            if let bestFormat = highResFormats.first {
                device.activeFormat = bestFormat
                print("Camera format set to: \(CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription))")
            }
            
            // Focus ottimizzato per distanza ravvicinata
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
            }
            
            // Range restrizione per macro (iPhone 13 Pro+)
            if #available(iOS 15.0, *) {
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Camera setup failed: \(error)")
            return
        }
        
        // Output con settings ottimizzati
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        
        let queue = DispatchQueue(label: "ocr.camera.queue", qos: .userInitiated, attributes: .concurrent)
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            // Imposta la connessione video per massima qualità
            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Disabilita video mirroring
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        
        self.captureSession = session
        self.videoOutput = output
        self.previewLayer = preview
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.isSessionRunning = true
            session.startRunning()
            print("Camera session started with preset: \(session.sessionPreset.rawValue)")
        }
    }

    // 2. Capture output modificato per mantenere risoluzione alta
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isSessionRunning else { return }
        
        // Riduci frame skipping per non perdere testo
        frameCounter += 1
        guard frameCounter % 2 == 0 else { return }  // Processa ogni 2 frame invece di 3
        
        guard CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Ottieni dimensioni originali
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Context con massima qualità
        let context = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true,
            .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ])
        
        // NON scalare l'immagine o scalare minimamente
        // Solo se necessario per performance, usa un fattore alto
        let shouldScale = false // Solo se veramente grande
        let finalImage: CIImage
        
        if shouldScale {
            let scaleFactor: CGFloat = 2000.0 / CGFloat(width)  // Mantieni almeno 2000px
            finalImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        } else {
            finalImage = ciImage
        }
        
        // Crea CGImage mantenendo la qualità
        guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else { return }
        
        // Crop migliorato che mantiene più risoluzione
        if let croppedImage = cropImageToCircleHighRes(cgImage) {
            ocrManager?.extractTextFromImage(croppedImage)
        }
    }
    
    
    

    private func cropImageToCircleHighRes(_ image: CGImage) -> CGImage? {
        let imageWidth = image.width
        let imageHeight = image.height
        
        // Requisiti minimi meno restrittivi
        guard imageWidth >= 500 && imageHeight >= 500 else {
            print("Image too small: \(imageWidth)x\(imageHeight)")
            return nil
        }
        
        let centerX = imageWidth / 2
        let centerY = imageHeight / 2
        
        // Usa un'area più grande possibile (90% del minimo tra larghezza e altezza)
        let radius = Int(Double(min(imageWidth, imageHeight)) * 0.80)
        
        // Assicurati che il radius sia abbastanza grande
        guard radius >= 250 else {  // Minimo 500x500 per l'area croppata
            print("Radius too small: \(radius)")
            return nil
        }
        
        let cropRect = CGRect(
            x: max(0, centerX - radius),
            y: max(0, centerY - radius),
            width: min(radius * 2, imageWidth),
            height: min(radius * 2, imageHeight)
        )
        
        print("Cropping rect: \(cropRect)")
        
        // Validazione finale
        guard cropRect.width >= 500 && cropRect.height >= 500 else {
            print("Crop rect too small: \(cropRect.width)x\(cropRect.height)")
            return nil
        }
        
        return image.cropping(to: cropRect)
    }

    // 4. In TireOCRManager - modifica extractTextFromImage per gestire immagini più grandi
    func extractTextFromImage(_ image: CGImage) {
        // Log dimensioni per debug
        print("OCR receiving image: \(image.width)x\(image.height)")
        
        // Verifica dimensione minima
        guard image.width >= 400 && image.height >= 400 else {
            return
        }
        
        // Se l'immagine è troppo grande, riducila a una dimensione gestibile
        let maxDimension = 2000
        let finalImage: CGImage
        
        if image.width > maxDimension || image.height > maxDimension {
            let scale = CGFloat(maxDimension) / CGFloat(max(image.width, image.height))
            
            let context = CIContext(options: [.useSoftwareRenderer: false])
            let ciImage = CIImage(cgImage: image)
            let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            if let scaled = context.createCGImage(scaledImage, from: scaledImage.extent) {
                finalImage = scaled
                print("OCR scaled image to: \(scaled.width)x\(scaled.height)")
            } else {
                finalImage = image
            }
        } else {
            finalImage = image
        }
        
        // Processa su background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Enhancement ottimizzato per alta risoluzione
            guard let enhancedImage = self.applyOptimizedEnhancement(to: finalImage) else {
                print("Enhancement failed")
                return
            }
            
            // Delegate OCR to the manager instead of performing Vision requests here
            self.ocrManager?.extractTextFromImage(enhancedImage)
            print("Forwarded enhanced image to OCR manager")
        }
    }

    private func applyOptimizedEnhancement(to image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        
        // Context ottimizzato per performance con immagini grandi
        let context = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: false,  // Più veloce per immagini grandi
            .cacheIntermediates: false       // Risparmia memoria
        ])
        
        // Enhancement semplificato ma efficace
        let enhanced = ciImage
            // Sharpening per testo
            .applyingFilter("CIUnsharpMask", parameters: [
                "inputRadius": 2.5,
                "inputIntensity": 1.0
            ])
            // Alto contrasto
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 0.0,
                "inputContrast": 2.2,
                "inputBrightness": 0.0
            ])
        
        return context.createCGImage(enhanced, from: enhanced.extent)
    }

    private func setupFlashObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFlashToggle(_:)),
            name: .flashToggle,
            object: nil
        )
    
    }
    
    @objc private func subjectAreaDidChange(_ notification: Notification) {
        // Reset focus and exposure when subject area changes
        guard let device = camera else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Reset focus to center
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Reset exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to reset focus and exposure: \(error)")
        }
    }

    @objc private func handleFlashToggle(_ notification: Notification) {
        var desiredLevel = currentTorchLevel
        let isOn: Bool

        if let userInfo = notification.userInfo,
           let toggleValue = userInfo["isOn"] as? Bool {
            isOn = toggleValue
            if let levelValue = userInfo["level"] as? NSNumber {
                desiredLevel = max(0.01, min(levelValue.floatValue, 1.0))
            }
        } else if let toggleValue = notification.object as? Bool {
            isOn = toggleValue
        } else {
            return
        }

        currentTorchLevel = desiredLevel
        toggleFlash(isOn, level: desiredLevel)
    }

    private func toggleFlash(_ isOn: Bool, level: Float) {
        guard let camera = camera, camera.hasTorch else { return }

        do {
            try camera.lockForConfiguration()
            if isOn && camera.isTorchAvailable {
                let clampedLevel = max(0.01, min(level, 1.0))
                if camera.isTorchActive, abs(camera.torchLevel - clampedLevel) < 0.01 {
                    // Already at desired level
                } else {
                    do {
                        try camera.setTorchModeOn(level: clampedLevel)
                    } catch {
                        camera.torchMode = .on
                    }
                }
            } else {
                camera.torchMode = .off
            }
            camera.unlockForConfiguration()
        } catch {
            print("Error controlling flash: \(error)")
        }
    }


}

extension OCRCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
   

    private func cropImageToCircle(_ image: CGImage) -> CGImage? {
        let imageWidth = image.width
        let imageHeight = image.height
        
        // More permissive size validation
        guard imageWidth > 50 && imageHeight > 50 else { return nil } // Reduced from 100

        let centerX = imageWidth / 2
        let centerY = imageHeight / 2
        let radius = min(imageWidth, imageHeight) / 2 // Back to /2 instead of /3 for better area coverage
        
        guard radius > 25 else { return nil } // Reduced from 50

        let cropRect = CGRect(
            x: max(0, centerX - radius),
            y: max(0, centerY - radius),
            width: min(radius * 2, imageWidth),
            height: min(radius * 2, imageHeight)
        )
        
        // Validate crop rectangle - less restrictive
        guard cropRect.width > 25 && cropRect.height > 25, // Reduced from 50
              cropRect.maxX <= CGFloat(imageWidth) && 
              cropRect.maxY <= CGFloat(imageHeight) else {
            return nil
        }

        return image.cropping(to: cropRect)
    }
}

