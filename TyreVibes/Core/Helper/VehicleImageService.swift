import Foundation
import SwiftUI
import Vision


class VehicleImageService {
    struct VehicleImageOptions {
        var customer: String = "img"
        var angle: Int = 12
        var fileType: String = "webp"
        var safeMode: Bool = false
        var origin: String = "https://docs.imagin.studio"
        var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"
        var accept: String = "*/*"
        var zoomType: String = "relative"
    }

    static let defaultAngles: [Int] = Array(200...231)
    private static let cache = NSCache<NSNumber, UIImage>()

    /// Normalizza il colore proveniente dall'API (spesso in italiano o con spazi) verso un paintId accettato da imagin.studio.
    /// Mantiene eventuali codici già compatibili (es. pspc****) e riduce a una palette base altrimenti.
    static func normalizedPaintId(from raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "BLACK"
        }

        let upper = raw.folding(options: .diacriticInsensitive, locale: .current).uppercased()

        // Se è un codice immagin (pspc****) o un codice esadecimale già formattato lo manteniamo
        if upper.range(of: #"^(PSPC|MZ|NZ)[A-Z0-9]*$"#, options: .regularExpression) != nil {
            return upper
        }
        let hex = upper.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.range(of: #"^[A-F0-9]{6}$"#, options: .regularExpression) != nil {
            return hex
        }

        let normalized = upper.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let palette: [(keywords: [String], paint: String)] = [
            (["BIANCO", "WHITE", "PERLA", "PEARL"], "WHITE"),
            (["NERO", "BLACK", "NOIR"], "BLACK"),
            (["GRIGIO", "GREY", "GRAY", "ARGENTO", "SILVER", "ANTRACITE"], "GRAY"),
            (["ROSSO", "RED", "BORDEAUX", "RUBINO"], "RED"),
            (["BLU", "BLUE", "AZZURRO", "NAVY"], "BLUE"),
            (["VERDE", "GREEN"], "GREEN"),
            (["GIALLO", "YELLOW"], "YELLOW"),
            (["ARANCIO", "ARANCIONE", "ORANGE"], "ORANGE"),
            (["MARRONE", "BROWN", "BRONZO"], "BROWN"),
            (["BEIGE", "CREMA", "SABBIA"], "BEIGE"),
            (["ORO", "GOLD"], "GOLD"),
            (["VIOLA", "PURPLE", "LILLA"], "PURPLE")
        ]

        for entry in palette {
            if entry.keywords.contains(where: { normalized.contains($0) }) {
                return entry.paint
            }
        }

        // Fallback: rimuovi spazi/punteggiatura, usa valore maiuscolo
        let trimmed = normalized.components(separatedBy: .whitespacesAndNewlines).joined()
        return trimmed.isEmpty ? "BLACK" : trimmed
    }

    /// Builds the CDN URL for a specific angle (without performing the request)
    private static func buildURL(make: String,
                                 modelFamily: String,
                                 year: String,
                                 paintId: String,
                                 angle: Int,
                                 options: VehicleImageOptions) -> URL? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "cdn.imagin.studio"
        comps.path = "/getImage"
        comps.queryItems = [
            URLQueryItem(name: "customer", value: options.customer),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: modelFamily),
            URLQueryItem(name: "paintId", value: normalizedPaintId(from: paintId)),
            URLQueryItem(name: "angle", value: String(angle)),
            URLQueryItem(name: "modelYear", value: String(year)),
            URLQueryItem(name: "fileType", value: options.fileType),
            URLQueryItem(name: "zoomType", value: options.zoomType),
            URLQueryItem(name: "tailoring", value: "empty")
        ]
        return comps.url
    }

    /// Fetch a single vehicle image for a specific angle with simple in-memory caching.
    static func fetchVehicleImage(make: String,
                                  modelFamily: String,
                                  year: String,
                                  paintId: String,
                                  angle: Int,
                                  options: VehicleImageOptions = VehicleImageOptions(),
                                  plate: String,
                                  completion: @escaping (Result<UIImage, Error>) -> Void) {
      //  let cacheKey = NSNumber(value: angle)
      //  if let cached = cache.object(forKey: cacheKey) {
      //      completion(.success(cached))
      //      return
      //  }
        var opt = options
        opt.angle = angle
        fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, options: opt, plate: plate) { result in
            //if case .success(let img) = result {
            //cache.setObject(img, forKey: cacheKey)
           // }
            completion(result)
        }
    }

    static func fetchVehicleImage(make: String, modelFamily: String, year: String, paintId: String, options: VehicleImageOptions ,plate : String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "cdn.imagin.studio"
        comps.path = "/getImage"
        comps.queryItems = [
            URLQueryItem(name: "customer", value: options.customer),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: modelFamily),
            URLQueryItem(name: "paintId", value: normalizedPaintId(from: paintId)),
            URLQueryItem(name: "angle", value: String(options.angle)),
            URLQueryItem(name: "modelYear", value: String(year)),
            URLQueryItem(name: "fileType", value: options.fileType),
        ]
        guard let url = comps.url else {
            completion(.failure(NSError(domain: "VehicleImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(options.accept, forHTTPHeaderField: "Accept")
        // NON modificare il Referer: mantieni quello attuale
        request.setValue("https://docs.imagin.studio/api-integration/apis", forHTTPHeaderField: "Referer")
        request.setValue(options.origin, forHTTPHeaderField: "Origin")
        request.setValue(options.userAgent, forHTTPHeaderField: "User-Agent")

        let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let msg = "HTTP \(http.statusCode) for URL: \(url.absoluteString)"
                completion(.failure(NSError(domain: "VehicleImageService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])));
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "VehicleImageService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])))
                return
            }
            
            completion(.success(image))
                
         //   if let ciImage = CIImage(image: image) {
         //       do {
         //           let model = try VNCoreMLModel(for: LicensePlateDetector().model)
         //           let request = VNCoreMLRequest(model: model) { request, error in
         //               var annotatedImage = image
         //               if let results = request.results as? [VNRecognizedObjectObservation] {
         //                   annotatedImage = Self.drawBoundingBoxes(on: image, results: results,plate: plate)
         //               }
         //               completion(.success(annotatedImage))
         //           }
         //           let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
         //           try handler.perform([request])
         //       } catch {
                 //   completion(.failure(error))
              //  }
         //   } else {
          //      completion(.success(image)) // fallback se non riesce a creare CIImage
          //  }
        }
        task.resume()
    }

    /// Preload a sequence of angles (default 200...231) and report progress.
    /// - Parameters:
    ///   - angles: Angles list. Defaults to `defaultAngles`.
    ///   - progress: Called on the main thread with (completed, total) as items finish.
    ///   - completion: Called on the main thread with an ordered array of images aligned to `angles`.
    static func preloadImages(make: String,
                              modelFamily: String,
                              year: String,
                              paintId: String,
                              angles: [Int] = defaultAngles,
                              options: VehicleImageOptions = VehicleImageOptions(),
                              progress: ((Int, Int) -> Void)? = nil,
                              plate: String,
                              completion: @escaping ([UIImage?]) -> Void) {
        let resolvedPaint = normalizedPaintId(from: paintId)
        let total = angles.count
        if total == 0 { completion([]); return }

        var results: [Int: UIImage] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for angle in angles {
            group.enter()
            fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: resolvedPaint, angle: angle, options: options, plate: plate) { result in
                if case .success(let img) = result {
                    lock.lock(); results[angle] = img; lock.unlock()
                }
                let done = results.count
                DispatchQueue.main.async { progress?(done, total) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // Map results back to the requested order; missing items become nil
            let ordered = angles.map { results[$0] }
            completion(ordered)
        }
    }

    static func fetchVehicleImage(make: String, modelFamily: String,year : String, paintId: String, plate: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let options = VehicleImageOptions()
        fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, options: options,plate: plate, completion: completion)
    }

    /// Clears the in-memory image cache (useful when switching car/paint).
    static func clearCache() {
        cache.removeAllObjects()
    }
    // Utility per disegnare i bounding box delle targhe rilevate
    private static func drawBoundingBoxes(on image: UIImage, results: [VNRecognizedObjectObservation], plate: String) -> UIImage {
        // Imposta la dimensione finale
        let targetSize = CGSize(width: 280, height: 180)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!

        // Calcola aspectFit: dimensione di disegno e offset centrato
        let imageSize = image.size
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawOrigin = CGPoint(x: (targetSize.width - drawSize.width) / 2,
                                 y: (targetSize.height - drawSize.height) / 2)

        // Disegna l’immagine preservando il rapporto
        image.draw(in: CGRect(origin: drawOrigin, size: drawSize))

        // Stile box
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(1.0)

        for r in results {
            let bb = r.boundingBox // normalizzato (0..1) in coordinate Vision (origine in basso a sinistra)

            // Rettangolo in coordinate "pixel" dell'immagine originale
            let rectInImage = CGRect(
                x: bb.origin.x * imageSize.width,
                y: (1 - bb.origin.y - bb.height) * imageSize.height,
                width: bb.width * imageSize.width,
                height: bb.height * imageSize.height
            )

            // Proietta nel contesto tenendo conto di scala uniforme e offset (letterboxing)
            let rect = CGRect(
                x: drawOrigin.x + rectInImage.origin.x * scale,
                y: drawOrigin.y + rectInImage.origin.y * scale,
                width: rectInImage.width * scale,
                height: rectInImage.height * scale
            )

            // Espansione proporzionale
            let expandFactorX: CGFloat = 0.02
            let expandFactorY: CGFloat = 0.05
            let expanded = rect.insetBy(dx: -rect.width * expandFactorX,
                                        dy: -rect.height * expandFactorY)

            context.setFillColor(UIColor.white.cgColor)
            context.fill(expanded)

            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(1.0)
            context.stroke(expanded)

            // --- Testo e icona ---
            let plateText = plate
            let iconSize = CGSize(width: expanded.height * 0.6, height: expanded.height * 0.6)
            let availableWidth = expanded.width - iconSize.width - 24
            var fontSize = expanded.height * 0.5
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            var textSize = plateText.size(withAttributes: attributes)
            while textSize.width > availableWidth && fontSize > 1 {
                fontSize -= 1
                attributes[.font] = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
                textSize = plateText.size(withAttributes: attributes)
            }

            if let icon = UIImage(named: "LogoImage") {
                let iconRect = CGRect(
                    x: expanded.minX + 8,
                    y: expanded.midY - iconSize.height / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                icon.draw(in: iconRect)

                let textRect = CGRect(
                    x: iconRect.maxX + 8,
                    y: expanded.midY - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                plateText.draw(in: textRect, withAttributes: attributes)
            } else {
                let textRect = CGRect(
                    x: expanded.midX - textSize.width / 2,
                    y: expanded.midY - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                plateText.draw(in: textRect, withAttributes: attributes)
            }
        }

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? image
    }
}
