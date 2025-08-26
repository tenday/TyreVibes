
import Foundation
import UIKit
import Vision
import CoreImage

// Modello dati (manteniamo PlateData)
public struct PlateData {
    public var plate: String
    public var make: String?
    public var model: String?
    public var version: String?
    public var year: String?
    public var month: String?
    public var color: String?
    public var fuelType: String?
    public var powerKW: String?
    public var powerCV: String?
    public var modelDetails: String?
    public var displacementCC: String?
    public var registrationDate: String?
    public var vin: String?
    public var rcaCompany : String?
    public var rcaExpiry : Date?
    public var rcaInsurancePresent: Bool?
    public var rcaPolicyNumber: String?
    public var classeAmbientale: String?
    public var tyres: [[String: String]]?
        
}

// Lettore principale
public class LicensePlateReader {
    
    
    

public static func fetchCaptchaGenerate(completion: @escaping (Result<[String: String], Error>) -> Void) {
    guard let url = URL(string: "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/noauth/captcha/generate") else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 1001, userInfo: nil)))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = "{}".data(using: .utf8)
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 1002, userInfo: nil)))
            return
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String,
               let image = json["image"] as? String {
                completion(.success(["id": id, "image": image]))
            } else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing id or image in response"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}
    public static func fetchRevisioniSecure(
        plate: String,
        tipoVeicolo: String = "A",
        maxAttempts: Int = 8,
        completion: @escaping (Result<[[String:String]], Error>) -> Void
    ) {
        func attempt(_ remaining: Int) {
            let captchaCount = 10
            let group = DispatchGroup()
            var captchaResults: [(id: String, image: String)] = []
            var firstError: Error?
            let lock = NSLock()
            for _ in 0..<captchaCount {
                group.enter()
                fetchCaptchaGenerate { result in
                    switch result {
                    case .success(let dict):
                        if let id = dict["id"], let image = dict["image"] {
                            lock.lock()
                            captchaResults.append((id: id, image: image))
                            lock.unlock()
                        }
                    case .failure(let err):
                        lock.lock()
                        if firstError == nil { firstError = err }
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            group.notify(queue: .global()) {
                if captchaResults.isEmpty {
                    if let err = firstError {
                        completion(.failure(err))
                    } else {
                        completion(.failure(NSError(domain: "LicensePlateReader", code: 3010, userInfo: [NSLocalizedDescriptionKey: "Nessun captcha ottenuto"])))
                    }
                    return
                }
                guard let best = chooseBestCaptcha(captchaResults) else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 3011, userInfo: [NSLocalizedDescriptionKey: "Impossibile selezionare captcha"])))
                    return
                }
                fetchCaptchaVerify(id: best.id, imageBase64: best.image) { verifyResult in
                    switch verifyResult {
                    case .failure(let error):
                        if remaining > 1 {
                            attempt(remaining - 1)
                        } else {
                            completion(.failure(error))
                        }
                        return
                    case .success(let guid):
                        callRevisioniAPI(plate: plate, tipoVeicolo: tipoVeicolo, guid: guid, completion: completion)
                    }
                }
            }
        }
        attempt(maxAttempts)
    }

    /// Chiamata all'API revisioni con header Guid, estratta da fetchRevisioniSecure
    private static func callRevisioniAPI(
        plate: String,
        tipoVeicolo: String,
        guid: String,
        completion: @escaping (Result<[[String:String]], Error>) -> Void
    ) {
        let urlString = "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/api/v1/storicorevisioni/\(tipoVeicolo)/\(plate)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 3002, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue(guid, forHTTPHeaderField: "Guid")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 3003, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
                return
            }
            do {
                let obj = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = obj as? [String: Any] {
                    guard let informations = dict["informations"] as? [[String: Any]] else {
                        // Se non c'è "informations" restituisce array vuoto
                        completion(.success([]))
                        return
                    }
                    // Estrai campi richiesti
                    let resultArr: [[String:String]] = informations.compactMap { info in
                        var res: [String:String] = [:]
                        if let datRvs = info["datRvs"] as? String { res["datRvs"] = datRvs }
                        if let numKmiPcsRvs = info["numKmiPcsRvs"] as? String ?? (info["numKmiPcsRvs"] as? NSNumber)?.stringValue {
                            res["numKmiPcsRvs"] = numKmiPcsRvs
                        }
                        if let flgEsiRvsVei = info["flgEsiRvsVei"] as? String {
                            let mapped: String
                            switch flgEsiRvsVei {
                            case "P": mapped = "REGOLARE"
                            case "S": mapped = "SOSPENDERE"
                            case "R": mapped = "RIPETERE"
                            default:  mapped = flgEsiRvsVei
                            }
                            res["flgEsiRvsVei"] = mapped
                        }
                        return res.isEmpty ? nil : res
                    }
                    completion(.success(resultArr))
                } else if let dict = obj as? [AnyHashable: Any] {
                    // Try to read "messaggio" if present
                    if let msg = dict["messaggio"] as? String {
                        let err = NSError(domain: "LicensePlateReader", code: 3005, userInfo: [NSLocalizedDescriptionKey: msg])
                        completion(.failure(err))
                        return
                    } else {
                        completion(.failure(NSError(domain: "LicensePlateReader", code: 3004, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida"])))
                        return
                    }
                } else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 3004, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida"])))
                    return
                }
            } catch {
                // Fallback: non è JSON, stampa come stringa e ritorna errore
                if let str = String(data: data, encoding: .utf8) {
                    print("Risposta non JSON:", str)
                }
                completion(.failure(error))
            }
        }
        task.resume()
    }

// Verifica captcha tramite OCR e chiamata POST
public static func fetchCaptchaVerify(id: String, imageBase64: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Gestione robusta del base64 (rimozione eventuale prefisso data URL)
    let base64String: String = {
        if let comma = imageBase64.firstIndex(of: ",") {
            return String(imageBase64[imageBase64.index(after: comma)...])
        } else {
            return imageBase64
        }
    }()
    guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
          let uiImage = UIImage(data: imageData),
          let cgImage = uiImage.cgImage else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])))
        return
    }

    // OCR con Vision (robusto: preprocessing + multi-candidati + normalizzazione)
    // Esegue OCR in background (sincrono per Vision; nessun callback multiplo)
    DispatchQueue.global(qos: .userInitiated).async {
        guard let solved = solveCaptchaWithVisionSimple(from: cgImage) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 2002, userInfo: [NSLocalizedDescriptionKey: "OCR non riuscito"])))
            return
        }
        let captchaText = solved

        // Chiamata POST per verifica captcha
        guard let url = URL(string: "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/noauth/captcha/verify") else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 2003, userInfo: nil)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["id": id, "text": captchaText]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 2004, userInfo: nil)))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let guid = json["guid"] as? String {
                    completion(.success(guid))
                } else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 2005, userInfo: [NSLocalizedDescriptionKey: "Risposta senza guid"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
    
    /// Euristica per distinguere tra O e Q
    private static func disambiguateQvsO(_ cgImage: CGImage, _ recognized: String, _ box: CGRect) -> String {
        guard recognized.uppercased() == "O" else { return recognized }
        
        let width = cgImage.width
        let height = cgImage.height
        let rect = CGRect(
            x: Int(box.origin.x * CGFloat(width)),
            y: Int(box.origin.y * CGFloat(height)),
            width: Int(box.width * CGFloat(width)),
            height: Int(box.height * CGFloat(height))
        )
        guard let cropped = cgImage.cropping(to: rect),
              let dataProvider = cropped.dataProvider,
              let data = dataProvider.data as Data? else {
            return recognized
        }
        
        let w = cropped.width, h = cropped.height
        let bytesPerPixel = cropped.bitsPerPixel / 8
        let bytesPerRow = cropped.bytesPerRow
        
        var sum = 0
        for y in Int(Double(h) * 0.6)..<h { // parte bassa
            for x in Int(Double(w) * 0.5)..<w { // lato destro
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(data[offset])
                let g = Int(data[offset+1])
                let b = Int(data[offset+2])
                let luma = (2126*r + 7152*g + 722*b) / 10000
                sum += (255 - luma)
            }
        }
        
        // Se c’è abbastanza inchiostro extra, interpretalo come Q
        if sum > (h * w / 20) {
            return "Q"
        }
        return recognized
    }

    /// Rimuove eventuali linee orizzontali marcate (es. strike-through centrale) schiarendo la/le bande più scure
    /// - Parameters:
    ///   - cgImage: immagine sorgente
    ///   - bandHalfHeight: semi-spessore (in pixel) della banda da schiarire attorno alla riga più scura
    ///   - thresholdRatio: rimuove tutte le righe con proiezione >= max*thresholdRatio (0..1)
    /// - Returns: nuova immagine senza la linea orizzontale se riuscito, altrimenti l'originale
    private static func removeCentralLineArtifacts(_ cgImage: CGImage, bandHalfHeight: Int = 2, thresholdRatio: Double = 0.85) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height

        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return cgImage
        }
        // Disegna l'immagine di partenza nel buffer RGBA
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let dataPtr = ctx.data else { return cgImage }

        let bytesPerPixel = 4
        let bytesPerRow = ctx.bytesPerRow
        let buffer = dataPtr.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        // Proiezione orizzontale: somma "inchiostro" per riga (più scuro -> valore più alto)
        var proj = [Int](repeating: 0, count: height)
        for y in 0..<height {
            var sum = 0
            let rowBase = y * bytesPerRow
            for x in 0..<width {
                let idx = rowBase + x * bytesPerPixel
                let r = Int(buffer[idx + 0])
                let g = Int(buffer[idx + 1])
                let b = Int(buffer[idx + 2])
                // Luma Rec.709 approx
                let luma = (2126 * r + 7152 * g + 722 * b) / 10000
                sum += (255 - luma)
            }
            proj[y] = sum
        }

        // Trova il picco (riga più scura) e soglia
        guard let maxVal = proj.max(), maxVal > 0 else {
            return cgImage
        }
        let thresh = Int(Double(maxVal) * thresholdRatio)

        // Schiarisci (porta a bianco) le righe molto scure e una banda attorno a ciascuna
        for y in 0..<height {
            if proj[y] >= thresh {
                let y0 = max(0, y - bandHalfHeight)
                let y1 = min(height - 1, y + bandHalfHeight)
                for yy in y0...y1 {
                    let rowBase = yy * bytesPerRow
                    // Porta a bianco preservando l'alpha
                    for x in 0..<width {
                        let idx = rowBase + x * bytesPerPixel
                        buffer[idx + 0] = 255
                        buffer[idx + 1] = 255
                        buffer[idx + 2] = 255
                        // alpha invariato
                    }
                }
            }
        }

        return ctx.makeImage() ?? cgImage
    }
    
    private static func majorityVoteCaptcha(_ captchas: [(id: String, image: String)], topN: Int = 5) -> (id: String, image: String, text: String)? {
        var scored: [(captcha: (id: String, image: String), score: Double)] = []

        for captcha in captchas {
            guard let data = Data(base64Encoded: captcha.image),
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else { continue }
            
            let score = inkDensity(of: cgImage)
            let spacing = averageCharSpacing(of: cgImage)
            let combined = score - spacing * 0.01 // pesatura semplice
            scored.append((captcha, combined))
        }
        
        // prendi i migliori N
        let best = scored.sorted { $0.score < $1.score }.prefix(topN)
        
        // OCR su ciascuno
        var freq: [String: Int] = [:]
        var mapId: [String: (id: String, image: String)] = [:]
        for item in best {
            if let data = Data(base64Encoded: item.captcha.image),
               let uiImage = UIImage(data: data),
               let cgImage = uiImage.cgImage,
               let text = solveCaptchaWithVision(from: cgImage) {
                let norm = normalizeCaptcha(text)
                freq[norm, default: 0] += 1
                mapId[norm] = item.captcha
            }
        }
        
        // restituisci il più votato
        if let winner = freq.max(by: { $0.value < $1.value })?.key,
           let captcha = mapId[winner] {
            return (captcha.id, captcha.image, winner)
        }
        return nil
    }
    // MARK: - OCR helpers (Vision + CoreImage)
    private static let ciContext = CIContext()

    private static func solveCaptchaWithVision(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 5...9) -> String? {
        // Preprocessa l'immagine in più varianti
        let variants = preprocessCaptchaVariants(from: cgImage)
        var candidates: [(text: String, score: Double)] = []

        for variant in variants {
            let observations = recognizeObservations(on: variant)
            guard !observations.isEmpty else { continue }

            // 1) OCR sull'intera immagine
            let fullText = observations
                .compactMap { obs -> String? in
                    guard let cand = obs.topCandidates(1).first else { return nil }
                    return disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
                }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if !fullText.isEmpty {
                let normalized = normalizeCaptcha(fullText)
                let len = normalized.count
                let score = (expectedLength.contains(len) ? 0.2 : 0.0) + 0.8
                candidates.append((normalized, score))
            }

            // 2) OCR con bounding box dei singoli caratteri
            let chars = observations.compactMap { obs -> (String, CGFloat)? in
                guard let cand = obs.topCandidates(1).first else { return nil }
                let fixed = disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
                return (normalizeCaptcha(fixed), obs.boundingBox.minX)
            }
            let ordered = chars.sorted { $0.1 < $1.1 }.map { $0.0 }.joined()
            if !ordered.isEmpty {
                let len = ordered.count
                let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.9
                candidates.append((ordered, score))
            }

            // 3) Segmentazione verticale in blocchi fissi (fallback)
            let segmented = segmentAndRecognize(variant, parts: expectedLength.upperBound)
            if !segmented.isEmpty {
                let len = segmented.count
                let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.7
                candidates.append((segmented, score))
            }
            
            // 4) Segmentazione tramite proiezioni verticali (dinamica)
            let projSeg = segmentAndRecognizeByProjections(variant, minGapWidth: 2, minCharWidth: max(5, cgImage.width / 40))
            if !projSeg.isEmpty {
                let len = projSeg.count
                let score = (expectedLength.contains(len) ? 0.4 : 0.0) + 0.95
                candidates.append((projSeg, score))
            }
        }

        // Nuova logica di scelta del candidato
        let valid = candidates
            .map { $0.text }
            .filter { expectedLength.contains($0.count) }

        if !valid.isEmpty {
            let freq = Dictionary(grouping: valid, by: { $0 })
                .mapValues { $0.count }
            return freq.max(by: { $0.value < $1.value })?.key
        }

        return candidates.max(by: { $0.score < $1.score })?.text
    }
    
    private static func chooseBestCaptcha(_ captchas: [(id: String, image: String)]) -> (id: String, image: String)? {
        var best: (id: String, image: String)?
        var bestScore = Double.greatestFiniteMagnitude
        
        for captcha in captchas {
            guard let data = Data(base64Encoded: captcha.image),
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else { continue }
            
            let score = inkDensity(of: cgImage) // calcolo "quanto nero"
            if score < bestScore {
                bestScore = score
                best = captcha
            }
            let spacing = averageCharSpacing(of: cgImage) // calcolo "spazio medio tra i blocchi di nero"
            if score < bestScore || (score == bestScore && spacing > 0) {
                bestScore = score
               best = captcha
            }
        }
        return best
    }
    
    private static func leftmostInkPosition(of cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data? else { return Double(width) }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // Scansiona da sinistra verso destra finché trovi inchiostro
        for x in 0..<width {
            var sum = 0
            let xOffset = x * bytesPerPixel
            for y in 0..<height {
                let idx = y * bytesPerRow + xOffset
                let r = Int(data[idx + 0])
                let g = Int(data[idx + 1])
                let b = Int(data[idx + 2])
                let luma = (2126 * r + 7152 * g + 722 * b) / 10000
                sum += (255 - luma)
            }
            if sum > 20 { // soglia: se c’è abbastanza nero
                return Double(x)
            }
        }
        return Double(width)
    }

    private static func inkDensity(of cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data? else { return .infinity }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var sum = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(data[offset])
                let g = Int(data[offset+1])
                let b = Int(data[offset+2])
                let luma = (2126*r + 7152*g + 722*b) / 10000
                sum += (255 - luma) // più scuro → maggiore somma
            }
        }
        return Double(sum) / Double(width * height)
    }

    private static func averageCharSpacing(of cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data? else { return 0.0 }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // Calcola la proiezione verticale (inchiostro per colonna)
        var proj = [Int](repeating: 0, count: width)
        for x in 0..<width {
            var sum = 0
            let xOffset = x * bytesPerPixel
            for y in 0..<height {
                let idx = y * bytesPerRow + xOffset
                let r = Int(data[idx + 0])
                let g = Int(data[idx + 1])
                let b = Int(data[idx + 2])
                let luma = (2126 * r + 7152 * g + 722 * b) / 10000
                sum += (255 - luma)
            }
            proj[x] = sum
        }

        // Identifica i blocchi di nero (colonne con inchiostro > soglia)
        let threshold = (proj.max() ?? 0) / 5
        var lastBlackX: Int? = nil
        var spacings: [Int] = []
        for x in 0..<width {
            if proj[x] > threshold {
                if let last = lastBlackX {
                    let gap = x - last
                    if gap > 1 { spacings.append(gap) }
                }
                lastBlackX = x
            }
        }

        if spacings.isEmpty { return 0.0 }
        return Double(spacings.reduce(0, +)) / Double(spacings.count)
    }
    
    /// Segmenta l'immagine in N parti verticali e applica OCR su ciascuna.
    private static func segmentAndRecognize(_ cgImage: CGImage, parts: Int) -> String {
        let width = cgImage.width
        let height = cgImage.height
        var result = ""

        for i in 0..<parts {
            let rect = CGRect(x: width * i / parts, y: 0,
                              width: width / parts, height: height)
            if let cropped = cgImage.cropping(to: rect) {
                let obs = recognizeObservations(on: cropped, minTextHeight: 0.05)
                if let cand = obs.first?.topCandidates(1).first {
                    result.append(normalizeCaptcha(cand.string))
                }
            }
        }
        return result
    }
    
    /// Versione migliorata della segmentazione tramite proiezioni verticali
        private static func segmentAndRecognizeByProjections(
            _ cgImage: CGImage,
            minGapWidth: Int = 2,
            minCharWidth: Int = 8,
            aggressiveSeparation: Bool = true
        ) -> String {
            let width = cgImage.width
            let height = cgImage.height

            guard let dataProvider = cgImage.dataProvider,
                  let data = dataProvider.data as Data? else { return "" }

            let bytesPerPixel = cgImage.bitsPerPixel / 8
            let bytesPerRow = cgImage.bytesPerRow

            // 1. Calcola proiezione verticale con maggiore sensibilità
            var proj = [Int](repeating: 0, count: width)
            for x in 0..<width {
                var sum = 0
                let xOffset = x * bytesPerPixel
                for y in 0..<height {
                    let idx = y * bytesPerRow + xOffset
                    let r = Int(data[idx + 0])
                    let g = Int(data[idx + 1])
                    let b = Int(data[idx + 2])
                    let luma = (2126 * r + 7152 * g + 722 * b) / 10000
                    let ink = 255 - luma
                    // Amplifica l'inchiostro per migliorare la separazione
                    sum += ink > 50 ? ink * 2 : ink
                }
                proj[x] = sum
            }

            // 2. Smoothing più aggressivo per ridurre il rumore
            if width > 3 {
                var smooth = [Int](repeating: 0, count: width)
                let kernelSize = max(3, width / 100) // Kernel adattivo
                for x in 0..<width {
                    var s = 0, c = 0
                    let halfKernel = kernelSize / 2
                    for dx in -halfKernel...halfKernel {
                        let xx = x + dx
                        if xx >= 0 && xx < width {
                            s += proj[xx]
                            c += 1
                        }
                    }
                    smooth[x] = s / max(1, c)
                }
                proj = smooth
            }

            // 3. Segmentazione migliorata con soglie adattive
            let cuts = findCharacterBoundaries(proj, minGapWidth: minGapWidth, minCharWidth: minCharWidth, aggressiveSeparation: aggressiveSeparation)
            
            // 4. OCR per ogni segmento con preprocessing specifico
            var result = ""
            for i in 0..<(cuts.count - 1) {
                let x0 = cuts[i]
                let x1 = cuts[i + 1]
                
                if x1 - x0 < minCharWidth { continue }
                
                let rect = CGRect(x: x0, y: 0, width: x1 - x0, height: height)
                if let cropped = cgImage.cropping(to: rect) {
                    // Preprocessing specifico per carattere singolo
                    let processed = preprocessSingleCharacter(cropped)
                    let text = recognizeSingleCharacter(processed)
                    result.append(text)
                }
            }
            
            return result
        }
        
        /// Trova i confini dei caratteri con algoritmo migliorato
        private static func findCharacterBoundaries(
            _ projection: [Int],
            minGapWidth: Int,
            minCharWidth: Int,
            aggressiveSeparation: Bool
        ) -> [Int] {
            
            let width = projection.count
            guard width > minCharWidth else { return [0, width] }
            
            let maxVal = projection.max() ?? 1
            
            // Soglie dinamiche basate sulla distribuzione
            let baseThreshold = maxVal / 15  // Soglia base più bassa
            let aggressiveThreshold = maxVal / 25 // Soglia aggressiva per separazione forzata
            
            var cuts: [Int] = [0]
            var inGap = false
            var gapStart = 0
            var lastCharEnd = 0
            
            // 1. Prima passata: gaps evidenti
            for x in 0..<width {
                let currentThresh = aggressiveSeparation ? aggressiveThreshold : baseThreshold
                
                if projection[x] < currentThresh {
                    if !inGap {
                        inGap = true
                        gapStart = x
                    }
                } else if inGap {
                    inGap = false
                    let gapWidth = x - gapStart
                    if gapWidth >= minGapWidth {
                        let cutPoint = (gapStart + x) / 2
                        cuts.append(cutPoint)
                        lastCharEnd = x
                    }
                }
            }
            
            // 2. Seconda passata: separazione forzata per caratteri molto larghi
            if aggressiveSeparation {
                var newCuts: [Int] = []
                
                for i in 0..<(cuts.count - 1) {
                    let start = cuts[i]
                    let end = cuts[i + 1]
                    let segmentWidth = end - start
                    
                    newCuts.append(start)
                    
                    // Se il segmento è troppo largo, prova a dividerlo
                    if segmentWidth > minCharWidth * 3 {
                        let forcedCuts = forceSeparation(projection, start: start, end: end, minCharWidth: minCharWidth)
                        newCuts.append(contentsOf: forcedCuts)
                    }
                }
                
                newCuts.append(cuts.last!)
                cuts = newCuts.sorted()
            }
            
            // 3. Terza passata: separazione basata su minimi locali
            cuts = refineCutsWithLocalMinima(projection, cuts: cuts, minCharWidth: minCharWidth)
            
            if cuts.last != width {
                cuts.append(width)
            }
            
            return cuts.sorted()
        }
        
        /// Separazione forzata per segmenti troppo larghi
        private static func forceSeparation(
            _ projection: [Int],
            start: Int,
            end: Int,
            minCharWidth: Int
        ) -> [Int] {
            
            var cuts: [Int] = []
            let segmentWidth = end - start
            let expectedChars = max(2, segmentWidth / (minCharWidth + 2))
            
            if expectedChars <= 1 { return cuts }
            
            // Cerca minimi locali nell'area
            let segment = Array(projection[start..<end])
            let minima = findLocalMinima(segment, windowSize: max(3, segmentWidth / 20))
            
            // Seleziona i minimi più promettenti
            let sortedMinima = minima.sorted { $0.value < $1.value }
            let selectedCount = min(expectedChars - 1, sortedMinima.count)
            
            for i in 0..<selectedCount {
                let localPos = sortedMinima[i].index
                let globalPos = start + localPos
                
                // Verifica che il taglio sia ragionevole
                if globalPos > start + minCharWidth && globalPos < end - minCharWidth {
                    cuts.append(globalPos)
                }
            }
            
            return cuts
        }
        
        /// Trova minimi locali nell'array
        private static func findLocalMinima(_ array: [Int], windowSize: Int) -> [(index: Int, value: Int)] {
            var minima: [(index: Int, value: Int)] = []
            let halfWindow = windowSize / 2
            
            for i in halfWindow..<(array.count - halfWindow) {
                let currentValue = array[i]
                var isMinimum = true
                
                // Controlla se è un minimo locale
                for j in (i - halfWindow)...(i + halfWindow) {
                    if j != i && array[j] < currentValue {
                        isMinimum = false
                        break
                    }
                }
                
                if isMinimum {
                    minima.append((index: i, value: currentValue))
                }
            }
            
            return minima
        }
        
        /// Raffina i tagli usando minimi locali
        private static func refineCutsWithLocalMinima(
            _ projection: [Int],
            cuts: [Int],
            minCharWidth: Int
        ) -> [Int] {
            
            var refinedCuts: [Int] = []
            
            for i in 0..<cuts.count {
                let currentCut = cuts[i]
                
                if i == 0 || i == cuts.count - 1 {
                    refinedCuts.append(currentCut)
                    continue
                }
                
                let prevCut = cuts[i - 1]
                let nextCut = cuts[i + 1]
                
                // Cerca un minimo migliore nell'area intorno al taglio
                let searchStart = max(prevCut + minCharWidth / 2, currentCut - minCharWidth / 4)
                let searchEnd = min(nextCut - minCharWidth / 2, currentCut + minCharWidth / 4)
                
                if searchStart < searchEnd {
                    var bestCut = currentCut
                    var minValue = projection[currentCut]
                    
                    for x in searchStart..<searchEnd {
                        if projection[x] < minValue {
                            minValue = projection[x]
                            bestCut = x
                        }
                    }
                    
                    refinedCuts.append(bestCut)
                } else {
                    refinedCuts.append(currentCut)
                }
            }
            
            return refinedCuts
        }
        
        /// Preprocessing specifico per carattere singolo
        private static func preprocessSingleCharacter(_ cgImage: CGImage) -> CGImage {
            let ci = CIImage(cgImage: cgImage)
            
            // Pipeline di preprocessing per carattere singolo
            let processed = ci
                // Normalizza il contrasto
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 2.5,
                    kCIInputBrightnessKey: 0.1
                ])
                // Riduci il rumore
                .applyingFilter("CINoiseReduction", parameters: [
                    "inputNoiseLevel": 0.02,
                    "inputSharpness": 0.4
                ])
                // Migliora la nitidezza
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: 1.0,
                    kCIInputIntensityKey: 0.8
                ])
                // Morfologia per pulire i bordi
                .applyingFilter("CIMorphologyMinimum", parameters: [
                    kCIInputRadiusKey: 0.8
                ])
                .applyingFilter("CIMorphologyMaximum", parameters: [
                    kCIInputRadiusKey: 1.2
                ])
            
            return ciContext.createCGImage(processed, from: processed.extent) ?? cgImage
        }
        
        /// Riconosce un singolo carattere con parametri ottimizzati
        private static func recognizeSingleCharacter(_ cgImage: CGImage) -> String {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = false
            req.recognitionLanguages = ["en-US"]
            req.minimumTextHeight = 0.01 // Più basso per caratteri singoli
            req.customWords = [] // Nessun dizionario per evitare correzioni
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([req])
                
                if let observations = req.results, !observations.isEmpty {
                    // Prendi tutti i candidati e scegli il migliore
                    var allCandidates: [(text: String, confidence: Float)] = []
                    
                    for obs in observations {
                        for candidate in obs.topCandidates(3) {
                            let normalized = normalizeCaptcha(candidate.string)
                            if normalized.count == 1 { // Solo caratteri singoli
                                allCandidates.append((normalized, candidate.confidence))
                            }
                        }
                    }
                    
                    // Scegli il candidato con maggiore confidenza
                    if let best = allCandidates.max(by: { $0.confidence < $1.confidence }) {
                        return best.text
                    }
                }
            } catch {
                print("OCR error per carattere singolo: \(error)")
            }
            
            return ""
        }
        
        /// Versione aggiornata di solveCaptchaWithVision che usa la segmentazione migliorata
        private static func solveCaptchaWithVisionImproved(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 5...9) -> String? {
            let variants = preprocessCaptchaVariants(from: cgImage)
            var candidates: [(text: String, score: Double)] = []

            for variant in variants {
                // 1. OCR tradizionale sull'intera immagine
                let observations = recognizeObservations(on: variant)
                if !observations.isEmpty {
                    let fullText = observations
                        .compactMap { obs -> String? in
                            guard let cand = obs.topCandidates(1).first else { return nil }
                            return disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
                        }
                        .joined()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()
                    
                    if !fullText.isEmpty {
                        let normalized = normalizeCaptcha(fullText)
                        let len = normalized.count
                        let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.7
                        candidates.append((normalized, score))
                    }
                }
                
                // 2. Segmentazione migliorata (metodo principale)
                let segmented = segmentAndRecognizeByProjections(
                    variant,
                    minGapWidth: max(1, variant.width / 200),
                    minCharWidth: max(8, variant.width / 40),
                    aggressiveSeparation: true
                )
                
                if !segmented.isEmpty {
                    let len = segmented.count
                    let score = (expectedLength.contains(len) ? 0.5 : 0.0) + 1.0
                    candidates.append((segmented, score))
                }
                
                // 3. Segmentazione ancora più aggressiva come fallback
                let ultraAggressive = segmentAndRecognizeByProjections(
                    variant,
                    minGapWidth: 1,
                    minCharWidth: max(6, variant.width / 50),
                    aggressiveSeparation: true
                )
                
                if !ultraAggressive.isEmpty && ultraAggressive != segmented {
                    let len = ultraAggressive.count
                    let score = (expectedLength.contains(len) ? 0.4 : 0.0) + 0.9
                    candidates.append((ultraAggressive, score))
                }
                
                // 4. Post-processing con correzione pattern comuni
                for candidate in [segmented, ultraAggressive] {
                    if !candidate.isEmpty {
                        let corrected = correctCommonPatterns(candidate)
                        if corrected != candidate {
                            let len = corrected.count
                            let score = (expectedLength.contains(len) ? 0.6 : 0.0) + 0.95
                            candidates.append((corrected, score))
                        }
                    }
                }
            }

            // Selezione del migliore candidato con validazione aggiuntiva
            let validCandidates = candidates.filter {
                let text = $0.text
                return expectedLength.contains(text.count) && isValidCaptchaPattern(text)
            }
            
            if !validCandidates.isEmpty {
                // Raggruppa per frequenza e scegli il più comune con score alto
                let textFrequency = Dictionary(grouping: validCandidates, by: { $0.text })
                let mostCommon = textFrequency.max { first, second in
                    let firstScore = first.value.map { $0.score }.reduce(0, +) / Double(first.value.count)
                    let secondScore = second.value.map { $0.score }.reduce(0, +) / Double(second.value.count)
                    return firstScore < secondScore
                }
                return mostCommon?.key
            } else {
                // Altrimenti prendi il migliore in assoluto con post-processing
                if let best = candidates.max(by: { $0.score < $1.score }) {
                    return correctCommonPatterns(best.text)
                }
            }
            
            return nil
        }
        
        /// Corregge pattern comuni di errore OCR
        private static func correctCommonPatterns(_ text: String) -> String {
            var corrected = text
            
            // Pattern specifici per errori di segmentazione
            let corrections: [(pattern: String, replacement: String)] = [
                ("LEFATI", "UEFATI"),   // Caso specifico
                ("LIEFATI", "UEFATI"),  // Variante
                ("LEFA", "UEFA"),       // Pattern parziale
                ("LEFI", "UEFI"),       // Variante
                ("LEFRA", "UEFRA"),     // Con R
                ("CLEFA", "DUEFA"),     // CL → D + error
                ("RNEFA", "MEFA"),      // RN → M + error
                // Altri pattern comuni
                ("RN", "M"),            // rn → m
                ("CL", "D"),            // cl → d
                ("VV", "W"),            // vv → w
                ("NN", "M"),            // nn → m
                ("II", "U"),            // ii → u
                ("LI", "U"),            // li → u
                ("LE", "U")             // le → u (generico)
            ]
            
            for correction in corrections {
                corrected = corrected.replacingOccurrences(of: correction.pattern, with: correction.replacement)
            }
            
            return corrected
        }
        
        /// Valida se il pattern sembra un captcha valido
        private static func isValidCaptchaPattern(_ text: String) -> Bool {
            // Controlla che non ci siano troppi caratteri ripetuti
            let charCount = Dictionary(grouping: text, by: { $0 })
            let maxRepeats = charCount.values.map { $0.count }.max() ?? 0
            
            // Un carattere non dovrebbe ripetersi più di 2 volte in un captcha tipico
            if maxRepeats > 2 { return false }
            
            // Controlla che ci siano sia consonanti che vocali (per captcha alfabetici)
            let vowels = Set("AEIOU")
            let consonants = Set("BCDFGHJKLMNPQRSTVWXYZ")
            let textSet = Set(text)
            
            let hasVowels = !textSet.intersection(vowels).isEmpty
            let hasConsonants = !textSet.intersection(consonants).isEmpty
            
            // Per captcha corti, è OK avere solo consonanti o solo vocali
            if text.count <= 4 { return true }
            
            // Per captcha lunghi, dovrebbe esserci un mix ragionevole
            return hasVowels || hasConsonants
        }

    
    private static func applyLensSuppression(_ ci: CIImage, factor: CGFloat = 0.75) -> CIImage {
        let extent = ci.extent
        let cx = extent.midX
        let cy = extent.midY
        let radius0 = min(extent.width, extent.height) * 0.22
        let radius1 = min(extent.width, extent.height) * 0.45

        let blurred = ci
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.1,
                kCIInputBrightnessKey: -0.02
            ])

        // Maschera radiale: 1 al centro (usa blur), 0 ai bordi (usa originale)
        let grad = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: cx, y: cy),
            "inputRadius0": radius0,
            "inputRadius1": radius1,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: factor),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ])!.outputImage!.cropped(to: extent)

        // Fonde blurred (al centro) con originale (ai bordi)
        let blended = CIFilter(name: "CIBlendWithAlphaMask", parameters: [
            kCIInputImageKey: blurred,
            kCIInputBackgroundImageKey: ci,
            kCIInputMaskImageKey: grad
        ])!.outputImage!

        return blended
    }

    /// Preprocessa il captcha in più forme (grayscale, contrasto, median, morfologia) per aiutare l'OCR.
    private static func preprocessCaptchaVariants(from cgImage: CGImage) -> [CGImage] {
        let base = CIImage(cgImage: cgImage)

        // Variante 1: B/N + contrasto + median
        let v1 = base
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.6,
                kCIInputBrightnessKey: 0.0
            ])
            .applyingFilter("CIPhotoEffectNoir")
            .applyingFilter("CIMedianFilter")
        
        let vLens = applyLensSuppression(v1)

        // Variante 2: come v1 ma più contrasto
        let v2 = v1.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 4.0
        ])

        // Variante 3: esposizione leggermente aumentata
        let v3 = v1.applyingFilter("CIExposureAdjust", parameters: [
            kCIInputEVKey: 0.6
        ])

        // Variante 4: morfologia (erode + dilate) per ispessire/assottigliare
       // let v4 = v1
       //     .applyingFilter("CIMorphologyMinimum", parameters: [
       //         kCIInputRadiusKey: 0.9
       //     ])
       //     .applyingFilter("CIMorphologyMaximum", parameters: [
       //         kCIInputRadiusKey: 1.0
       //     ])
        
       


        // Converte CIImage -> CGImage
        var out: [CGImage] = []
        for ci in [v1, v2, v3, vLens,
                   v1.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 1.5]),
                   v1.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.5]),
                   v1.applyingFilter("CISharpenLuminance", parameters: ["inputSharpness": 0.6])
        ] {
            if let cg = ciContext.createCGImage(ci, from: ci.extent) {
                out.append(cg)
                // Variante con soppressione della linea orizzontale (captcha con linea centrale)
                let noLine = removeCentralLineArtifacts(cg, bandHalfHeight: max(2, Int(cg.height / 80)), thresholdRatio: 0.80)
                out.append(noLine)
            }
        }

        // Include sempre anche l'originale e la variante senza linea
        out.append(cgImage)
        let noLineOriginal = removeCentralLineArtifacts(cgImage, bandHalfHeight: max(2, Int(cgImage.height / 80)), thresholdRatio: 0.50)
        out.append(noLineOriginal)
        return out
    }

    /// Esegue Vision OCR sincrono su una singola immagine.
    private static func recognizeObservations(on cgImage: CGImage, minTextHeight: Float = 0.04) -> [VNRecognizedTextObservation] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"] // alfanumerico, nessun dizionario necessario
        req.minimumTextHeight = minTextHeight

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([req])
            return req.results ?? []
        } catch {
            return []
        }
    }

    /// Normalizza il testo captcha: uppercase, mappa caratteri ambigui e filtra secondo la modalità numerica o alfanumerica.
    /// - Parameters:
    ///   - s: Stringa da normalizzare
    ///   - digitsOnly: se true, il captcha è solo numerico (default true)
    private static func normalizeCaptcha(_ s: String, digitsOnly: Bool = false) -> String {
        let up = s.uppercased()
        var mapped = up.folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "O", with: "0")
            //.replacingOccurrences(of: "I", with: "1")
            //.replacingOccurrences(of: "L", with: "1")
            //.replacingOccurrences(of: "T", with: "7")
        if digitsOnly {
            // Se solo cifre (o lettere simili), mappa anche T → 1
            mapped = mapped.replacingOccurrences(of: "T", with: "1")
        }
        let allowed: CharacterSet = digitsOnly ? .decimalDigits : .alphanumerics
        let scalars = mapped.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
    
    private static func solveCaptchaWithVisionSimple(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 6...9) -> String? {
           
           // 1. Solo 2 preprocessing essenziali
           let variants = [
               cgImage, // Originale
               preprocessForOCR(cgImage) // Una sola variante preprocessata
           ]
           
           var bestResult: String?
           var bestScore = 0.0
           
           for variant in variants {
               // 2. Segmentazione precisa
               let segmented = segmentPrecisely(variant)
               
               if expectedLength.contains(segmented.count) {
                   let score = Double(segmented.count == 6 ? 1.0 : 0.8) // Preferisci lunghezza 6
                   if score > bestScore {
                       bestScore = score
                       bestResult = segmented
                   }
               }
               
               // 3. OCR tradizionale come fallback
               if bestResult == nil {
                   let traditional = recognizeTraditional(variant)
                   if !traditional.isEmpty && expectedLength.contains(traditional.count) {
                       bestResult = traditional
                   }
               }
           }
           
           // 4. Solo correzioni essenziali
           if let result = bestResult {
               return fixCriticalErrors(result)
           }
           
           return ""
       }
       
       /// Preprocessing minimo ma efficace
       private static func preprocessForOCR(_ cgImage: CGImage) -> CGImage {
           let ci = CIImage(cgImage: cgImage)
           
           let processed = ci
               .applyingFilter("CIColorControls", parameters: [
                   kCIInputSaturationKey: 0.0,      // B/N
                   kCIInputContrastKey: 2.0,        // Contrasto moderato
                   kCIInputBrightnessKey: 0.05      // Leggero schiarimento
               ])
               .applyingFilter("CIMedianFilter") // Riduce rumore
           let suppressed = applyLensSuppression(processed)
           return ciContext.createCGImage(suppressed, from: suppressed.extent) ?? cgImage
       }
       
       /// Segmentazione verticale precisa
       private static func segmentPrecisely(_ cgImage: CGImage) -> String {
           let width = cgImage.width
           let height = cgImage.height
           
           guard let dataProvider = cgImage.dataProvider,
                 let data = dataProvider.data as Data? else { return "" }
           
           let bytesPerPixel = cgImage.bitsPerPixel / 8
           let bytesPerRow = cgImage.bytesPerRow
           
           // Proiezione verticale semplice
           var projection = [Int](repeating: 0, count: width)
           for x in 0..<width {
               var sum = 0
               for y in 0..<height {
                   let offset = y * bytesPerRow + x * bytesPerPixel
                   let r = Int(data[offset])
                   let g = Int(data[offset + 1])
                   let b = Int(data[offset + 2])
                   let gray = (r + g + b) / 3
                   sum += (255 - gray) // Inchiostro
               }
               projection[x] = sum
           }
           
           // Trova tagli semplici
           let threshold = (projection.max() ?? 0) / 8
           let minCharWidth = width / 12 // ~8% della larghezza
           
           var cuts = [0]
           var inGap = false
           var gapStart = 0
           
           for x in 0..<width {
               if projection[x] < threshold {
                   if !inGap {
                       inGap = true
                       gapStart = x
                   }
               } else if inGap {
                   inGap = false
                   let gapWidth = x - gapStart
                   if gapWidth >= 2 { // Gap minimo di 2 pixel
                       cuts.append((gapStart + x) / 2)
                   }
               }
           }
           cuts.append(width)
           
           // OCR per ogni segmento
           var result = ""
           for i in 0..<(cuts.count - 1) {
               let x0 = cuts[i]
               let x1 = cuts[i + 1]
               
               if x1 - x0 >= minCharWidth {
                   let rect = CGRect(x: x0, y: 0, width: x1 - x0, height: height)
                   if let cropped = cgImage.cropping(to: rect) {
                       let char = recognizeSingleChar(cropped)
                       result.append(char)
                   }
               }
           }
           
           return result
       }
       
       /// OCR per singolo carattere
       private static func recognizeSingleChar(_ cgImage: CGImage) -> String {
           let request = VNRecognizeTextRequest()
           request.recognitionLevel = .accurate
           request.usesLanguageCorrection = false
           request.minimumTextHeight = 0.01
           
           let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
           
           do {
               try handler.perform([request])
               if let observation = request.results?.first,
                  let candidate = observation.topCandidates(1).first {
                   let text = candidate.string.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                   return String(text.prefix(1)) // Solo primo carattere
               }
           } catch {}
           
           return ""
       }
       
       /// OCR tradizionale sull'intera immagine
       private static func recognizeTraditional(_ cgImage: CGImage) -> String {
           let request = VNRecognizeTextRequest()
           request.recognitionLevel = .accurate
           request.usesLanguageCorrection = false
           
           let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
           
           do {
               try handler.perform([request])
               if let observation = request.results?.first,
                  let candidate = observation.topCandidates(1).first {
                   return candidate.string.uppercased()
                       .trimmingCharacters(in: .whitespacesAndNewlines)
                       .filter { $0.isLetter || $0.isNumber }
               }
           } catch {}
           
           return ""
       }
       
       /// Solo correzioni critiche e verificate
       private static func fixCriticalErrors(_ text: String) -> String {
           return text
               .replacingOccurrences(of: "O", with: "0")
               .replacingOccurrences(of: "I", with: "L")
               .replacingOccurrences(of: "LE", with: "U") // le → u (il tuo caso specifico)
               .replacingOccurrences(of: "LI", with: "U") // li → u
               .filter { $0.isLetter || $0.isNumber }// Solo lettere per captcha alfanumerici
       }

    private static var norautoClient: NorautoAPIClient?

// Funzione principale che raccoglie tutti i dati da fonti ufficåiali
public static func fetchPlateSummary(plate: String, completion: @escaping (Result<PlateData, Error>) -> Void) {
var plateData = PlateData(plate: plate)
    

    let apiURL = URL(string: "https://www.norauto.it/next-e-shop/car-selector/identification/reg-vin/external/GB241PT?shop=9904&reg-country=IT")!
    norautoClient = NorautoAPIClient()
    norautoClient?.fetchData(for: apiURL) { result in
        switch result {
        case .success(let response):
            print("✅ Risposta API:\n", response)
        case .failure(let error):
            print("❌ Errore:", error.localizedDescription)
        }
    }
        
    

// Step 1: Allianz API per dati base veicolo
fetchAllianzInfo(plate: plate) { result in
    switch result {
    case .success(let allianz):
        print(allianz)
        plateData.make = allianz["make"]
        plateData.model = allianz["model"]
        plateData.version = allianz["version"]
        plateData.powerKW = allianz["powerKW"]
        plateData.powerCV = allianz["powerCV"]
        plateData.fuelType = allianz["fuelType"]
        plateData.displacementCC = allianz["displacementCC"]
        plateData.registrationDate = allianz["registrationDate"]
        plateData.modelDetails = allianz["modelDetail"]
    case .failure(let error):
        print("Allianz error: \(error)")
    }
    
    // Step 2: RCA dal Portale
    fetchCoperturaRC(plate: plate) { rcaResult in
        switch rcaResult {
        case .success(let rca):
            // Extra fields
            plateData.rcaCompany = rca["company"]
            if let expiryStr = rca["expiry"] {
                let inputFormatter = DateFormatter()
                inputFormatter.locale = Locale(identifier: "it_IT")
                inputFormatter.dateFormat = "yyyy-MM-ddZZZZZ"

                if let date = inputFormatter.date(from: expiryStr) {
                    plateData.rcaExpiry = date

                    // Se vuoi anche salvare una stringa leggibile
                    let outputFormatter = DateFormatter()
                    outputFormatter.locale = Locale(identifier: "it_IT")
                    outputFormatter.dateFormat = "dd/MM/yyyy"
                    let formatted = outputFormatter.string(from: date)

                }
            }
            plateData.rcaPolicyNumber = rca["policyNumber"]
            plateData.rcaInsurancePresent = (rca["insurancePresent"] as NSString?)?.boolValue
        case .failure(let error):
            print("RCA error: \(error)")
        }
        
        // Step 3: Classe ambientale
        fetchClasseAmbientale(plate: plate) { classeResult in
            switch classeResult {
            case .success(let classe):
                plateData.classeAmbientale = classe
            case .failure(let error):
                print("Classe error: \(error)")
            }
            
            // Step 4: Revisioni
            fetchRevisioniSecure(plate: plate) { revResult in
                switch revResult {
                case .success(let revisions):
                    print(revisions)
                case .failure(let error):
                    print("Revisioni error: \(error)")
                }
                
                // Step 5: Tyre Blackcircles
                fetchTyreBlackcircles(plate: plate) { tyreResult in
                    switch tyreResult {
                    case .success(let tyreData):
                        print("Tyre Blackcircles:", tyreData)
                        plateData.tyres = tyreData
                    case .failure(let error):
                        print("Tyre Blackcircles error: \(error)")
                    }
                    completion(.success(plateData))
                }
            }
        }
    }
}
}
    
    

// MARK: - Allianz
private static func fetchAllianzInfo(plate: String, completion: @escaping (Result<[String:String], Error>) -> Void) {
let urlString = "https://pro-edp.apis.allianz.com/prod/sales-service/quotebundles?flow=SFQ"
guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 1, userInfo: nil)))
    return
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("motor", forHTTPHeaderField: "line-of-business")
request.setValue("IT", forHTTPHeaderField: "backend-tenant")
request.setValue("it-IT", forHTTPHeaderField: "mapped-lang")
request.setValue(randomSessionId(length: 16), forHTTPHeaderField: "session-id")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

// Generate dateOfBirth as a random string in the format "YYYY-MM-DD"
let year = Int.random(in: 1952...2004)
let month = Int.random(in: 1...12)
let day = Int.random(in: 1...28)
let generatedDate = String(format: "%04d-%02d-%02d", year, month, day)

let bodyDict: [String: Any] = [
    "customerData": [
        "insuredProperty": [
            "type": "car",
            "usage": "KFZ01",
            "multipleOwners": false,
            "licensePlate": plate,
            "licensePlateType": "01",
            "driverCircle": ["mainDriverType": "E"],
            "mileage": "19999",
            "parkingAvailable": true,
            "usageDetail": "PR"
        ],
        "paymentFrequency": "ANNUALLY",
        "carOwner": [
            "type": "person",
            "dateOfBirth": generatedDate
        ],
        "deviceType": "mobile"
    ]
]

do {
    request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
} catch {
    completion(.failure(error))
    return
}

URLSession.shared.dataTask(with: request) { data, _, error in
    if let error = error { completion(.failure(error)); return }
    guard let data = data else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 2, userInfo: nil)))
        return
    }
    var dict: [String:String] = [:]
    if let raw = String(data: data, encoding: .utf8),
       let fixedData = raw.data(using: .utf8) {
        do {
            if let json = try JSONSerialization.jsonObject(with: fixedData) as? [String: Any],
               let customerData = json["customerData"] as? [String: Any],
               let insuredProperty = customerData["insuredProperty"] as? [String: Any],
               let details = insuredProperty["details"] as? [String: Any] {
                
                if let brand = details["brand"] as? String {
                    dict["make"] = brand
                }
                if let model = details["model"] as? String {
                    let cleanModel = model.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? model
                    let normalized = cleanModel.folding(options: .diacriticInsensitive, locale: .current)
                    dict["model"] = normalized
                }
                if let fuelType = details["fuelType"] as? String {
                    var fuel = fuelType
                    switch fuelType {
                    case "D": fuel = "Diesel"
                    case "B": fuel = "Benzina"
                    case "I", "H": fuel = "Ibrida"
                    case "E": fuel = "Elettrica"
                    case "G", "L": fuel = "GPL"
                    case "M": fuel = "Metano"
                    default: break
                    }
                    dict["fuelType"] = fuel
                }
                if let power = details["power"] {
                    if let powerStr = power as? String {
                        dict["powerKW"] = powerStr
                        if let kw = Double(powerStr) {
                            dict["powerCV"] = String(Int(round(kw / 0.73549875)))
                        }
                    }
                }
                if let cubicCapacity = details["cubicCapacity"] as? String {
                    dict["displacementCC"] = cubicCapacity
                }
                if let firstRegistrationDate = details["firstRegistrationDate"] as? String {
                    let parts = firstRegistrationDate.split(separator: "-")
                    if parts.count == 3 {
                        dict["registrationDate"] = "\(parts[1])/\(parts[0])"
                    } else {
                        dict["registrationDate"] = firstRegistrationDate
                    }
                }
                
                if let modelDetails = details["modelDetail"] as? String{
                    let cleanModelDetails = modelDetails.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? modelDetails
                    let normalized = cleanModelDetails.folding(options: .diacriticInsensitive, locale: .current)
                    dict["modelDetail"] = normalized
                }
            }
            completion(.success(dict))
        } catch {
            completion(.failure(error))
            return
        }
    } else {
        completion(.success(dict))
    }
}.resume()
}

private static func randomSessionId(length: Int) -> String {
let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
return String((0..<length).map{ _ in letters.randomElement()! })
}
// RCA
private static func fetchCoperturaRC(plate: String, tipoVeicolo: String = "A", completion: @escaping (Result<[String:String], Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/eai/AreaVeicolo-ws/services/secure/coperturaRCNew"
guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "CoperturaRC", code: 1, userInfo: nil)))
    return
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("text/xml;charset=utf-8", forHTTPHeaderField: "Content-Type")
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

let soapBody = """
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:veic="http://www.dtt.it/xsd/Veicolo">
   <soapenv:Header>
      <wsse:Security soapenv:mustUnderstand="1"
                     xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
         <wsse:UsernameToken wsu:Id="UsernameToken-1"
             xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <wsse:Username>PUBLIC</wsse:Username>
            <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">PUBLIC</wsse:Password>
         </wsse:UsernameToken>
      </wsse:Security>
   </soapenv:Header>
   <soapenv:Body>
      <veic:CoperturaRCVeicoloSecureNewRequest>
         <veic:tipoVeicolo>\(tipoVeicolo)</veic:tipoVeicolo>
         <veic:targa>\(plate)</veic:targa>
      </veic:CoperturaRCVeicoloSecureNewRequest>
   </soapenv:Body>
</soapenv:Envelope>
"""

request.httpBody = soapBody.data(using: .utf8)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        completion(.failure(error))
        return
    }
    guard let data = data else {
        completion(.failure(NSError(domain: "CoperturaRC", code: 2, userInfo: nil)))
        return
    }
    let parser = SimpleXMLParser(data: data)
    let rcaDict = parser.parseRCA()
    completion(.success(rcaDict))
}.resume()
}

// MARK: - Classe Ambientale
private static func fetchClasseAmbientale(plate: String, tipoVeicolo: String = "A", completion: @escaping (Result<String, Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/eai/AreaVeicolo-ws/services/secure/verificaClasseAmbientaleVeicolo"
guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 5, userInfo: nil)))
    return
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("text/xml;charset=utf-8", forHTTPHeaderField: "Content-Type")
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
request.setValue("\"VerificaClasseAmbientaleVeicoloSecure\"", forHTTPHeaderField: "SOAPAction")
request.setValue("text/xml", forHTTPHeaderField: "Accept")

let soapBody = """
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Header>
      <wsse:Security soapenv:mustUnderstand="0" soapenv:actor="http://schemas.xmlsoap.org/soap/actor/next"
          xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
         <wsse:UsernameToken wsu:Id="XWSSGID-1253605895203984534550"
             xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <wsse:Username>PUBLIC</wsse:Username>
            <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">PUBLIC</wsse:Password>
         </wsse:UsernameToken>
      </wsse:Security>
   </soapenv:Header>
   <soapenv:Body>
      <VerificaClasseAmbientaleVeicoloSecureRequest xmlns="http://www.dtt.it/xsd/Veicolo">
         <datiVeicolo>
            <tipoVeicolo>\(tipoVeicolo)</tipoVeicolo>
            <targa>\(plate)</targa>
         </datiVeicolo>
      </VerificaClasseAmbientaleVeicoloSecureRequest>
   </soapenv:Body>
</soapenv:Envelope>
"""
request.httpBody = soapBody.data(using: .utf8)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error { completion(.failure(error)); return }
    guard let data = data else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 6, userInfo: nil)))
        return
    }
    let parser = SimpleXMLParser(data: data)
    let classe = parser.parseClasse()
    completion(.success(classe))
}.resume()
}

// MARK: - Pneumatici compatibili
public static func fetchTyreCompatibili(plate: String, completion: @escaping (Result<[String], Error>) -> Void) {
    let urlString = "https://api.example.com/tires?plate=\(plate)"
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 9001, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
            return
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let tires = json["compatibleTires"] as? [String] {
                completion(.success(tires))
            } else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 9003, userInfo: [NSLocalizedDescriptionKey: "Risposta senza compatibleTires"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

    public static func fetchTyreBlackcircles(plate: String, completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        guard let url = URL(string: "https://www.blackcircles.it/find") else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 9101, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Generate X-XSRF-TOKEN value
        let xsrfToken = generateBlackcirclesToken()
        // Headers richiesti
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(xsrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
        request.setValue("https://www.blackcircles.it", forHTTPHeaderField: "Origin")
        request.setValue("https://www.blackcircles.it/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        // Corpo form-urlencoded
        let params: [String: String] = [
            "searchByNumberplateMode": "searchByNumberplateMode",
            "numberplate": plate
        ]
        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 9102, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
                return
            }
            guard let htmlString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 9104, userInfo: [NSLocalizedDescriptionKey: "Impossibile convertire dati in stringa"])))
                return
            }
            // Regex pattern to match the required fields inside div.custom-control
            // We look for: <div class="custom-control ..."><input ... id="..." value="..." data-width="..." ...><label ...><span class="size-label">...</span></label>
            let pattern = #"<div[^>]*class="[^"]*custom-control[^"]*"[^>]*>.*?<input[^>]*\sid="([^"]*)"[^>]*\svalue="([^"]*)"[^>]*\sdata-width="([^"]*)"[^>]*\sdata-diameter="([^"]*)"[^>]*\sdata-ratio="([^"]*)"[^>]*\sdata-speedindex="([^"]*)"[^>]*\sdata-loadindex="([^"]*)"[^>]*>.*?<label[^>]*>.*?<span[^>]*class="size-label"[^>]*>(.*?)</span>"#
            // Options: allow dot to match newlines
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
                let nsrange = NSRange(htmlString.startIndex..<htmlString.endIndex, in: htmlString)
                let matches = regex.matches(in: htmlString, options: [], range: nsrange)
                var results: [[String: String]] = []
                for match in matches {
                    guard match.numberOfRanges == 9 else { continue }
                    var dict: [String: String] = [:]
                    let keys = ["id", "value", "data-width", "data-diameter", "data-ratio", "data-speedindex", "data-loadindex", "size-label"]
                    for idx in 1..<match.numberOfRanges {
                        if let range = Range(match.range(at: idx), in: htmlString) {
                            dict[keys[idx-1]] = String(htmlString[range])
                        }
                    }
                    if !dict.isEmpty {
                        results.append(dict)
                    }
                }
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

private static func generateBlackcirclesToken() -> String {
    // Helper to generate n hex chars
    func randomHex(_ count: Int) -> String {
        let hexChars = "0123456789abcdef"
        return String((0..<count).map { _ in hexChars.randomElement()! })
    }
    return "\(randomHex(8))-\(randomHex(4))-\(randomHex(4))-\(randomHex(4))-\(randomHex(7))"
}

// MARK: - Revisioni
private static func fetchRevisioni(plate: String, completion: @escaping (Result<[String], Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/portale/api/storicorevisioni?plate=\(plate)"
guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 7, userInfo: nil)))
    return
}
URLSession.shared.dataTask(with: url) { data, _, error in
    if let error = error { completion(.failure(error)); return }
    guard let data = data else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 8, userInfo: nil)))
        return
    }
    let parser = SimpleXMLParser(data: data)
    let revisions = parser.parseRevisioni()
    completion(.success(revisions))
}.resume()
}
}

// Parser XML semplice
class SimpleXMLParser: NSObject, XMLParserDelegate {
private let data: Data
private var currentElement = ""
private var currentValue = ""
private var results: [String: String] = [:]
private var revisions: [String] = []

// Proprietà RCA
private var rcaCompany: String?
private var rcaPolicyNumber: String?
private var rcaInsurancePresent: String?
private var rcaExpiry: String?

init(data: Data) { self.data = data }

func parseRCA() -> [String: String] {
// Reset RCA properties
rcaCompany = nil
rcaPolicyNumber = nil
rcaInsurancePresent = nil
rcaExpiry = nil
let parser = XMLParser(data: data)
parser.delegate = self
parser.parse()
var dict: [String: String] = [:]
if let company = rcaCompany { dict["company"] = company }
if let policyNumber = rcaPolicyNumber { dict["policyNumber"] = policyNumber }
if let insurancePresent = rcaInsurancePresent { dict["insurancePresent"] = insurancePresent }
if let expiry = rcaExpiry { dict["expiry"] = expiry }
return dict
}

func parseClasse() -> String {
let parser = XMLParser(data: data)
parser.delegate = self
let ok = parser.parse()
if !ok {
    print("XMLParser error:", parser.parserError?.localizedDescription ?? "unknown")
}
return results["veic:categoriaAmbientale"] ?? results["classe"] ?? ""
}

func parseRevisioni() -> [String] {
let parser = XMLParser(data: data)
parser.delegate = self
parser.parse()
return revisions
}

// MARK: - XMLParserDelegate
func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
currentElement = elementName
currentValue = ""
}

func parser(_ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?) {
let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
// RCA parsing
if !value.isEmpty {
    switch elementName {
    case "veic:compagniaAssicurativa":
        rcaCompany = value
    case "veic:numeroPolizza":
        rcaPolicyNumber = value
    case "veic:assicurazionePresente":
        rcaInsurancePresent = value
    case "veic:dataScadenzaPolizza":
        rcaExpiry = value
    default:
        break
    }
    results[elementName] = value
}
currentValue = ""
}

func parser(_ parser: XMLParser, foundCharacters string: String) {
currentValue += string
}
}
