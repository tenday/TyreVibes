import UIKit
import Vision
import CoreImage

/// Helper per offuscare le targhe nelle immagini dei veicoli
class LicensePlateBlurHelper {

    /// Applica un blur sulla targa rilevata nell'immagine
    /// - Parameter image: L'immagine originale del veicolo
    /// - Returns: L'immagine con la targa offuscata, oppure l'immagine originale se non viene rilevata alcuna targa
    static func blurLicensePlate(in image: UIImage) -> UIImage {
        // Rileva la targa nell'immagine
        guard let plateRegion = detectLicensePlate(in: image) else {
            // Se non trova la targa, restituisce l'immagine originale
            return image
        }

        // Applica il blur alla regione della targa
        return applyBlur(to: image, in: plateRegion)
    }

    /// Rileva la posizione della targa nell'immagine usando Vision
    private static func detectLicensePlate(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        var detectedRect: CGRect?
        let semaphore = DispatchSemaphore(value: 0)

        // Usa Vision per rilevare testo nell'immagine
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                semaphore.signal()
                return
            }

            // Cerca pattern di targa (lettere e numeri)
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string.uppercased()
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")

                // Pattern per targhe italiane (es: AB123CD) o europee
                if isLicensePlatePattern(text) {
                    // Converti coordinate Vision (0,0 in basso a sinistra) in UIKit (0,0 in alto a sinistra)
                    let imageHeight = CGFloat(cgImage.height)
                    let imageWidth = CGFloat(cgImage.width)

                    let boundingBox = observation.boundingBox

                    // Espandi leggermente il rettangolo per assicurarsi di coprire tutta la targa
                    let expandedBox = CGRect(
                        x: max(0, boundingBox.origin.x - 0.02),
                        y: max(0, boundingBox.origin.y - 0.05),
                        width: min(1.0, boundingBox.width + 0.04),
                        height: min(1.0, boundingBox.height + 0.10)
                    )

                    // Converti da coordinate normalizzate a pixel
                    let rect = VNImageRectForNormalizedRect(
                        expandedBox,
                        Int(imageWidth),
                        Int(imageHeight)
                    )

                    // Inverti Y per coordinate UIKit
                    detectedRect = CGRect(
                        x: rect.origin.x,
                        y: imageHeight - rect.origin.y - rect.height,
                        width: rect.width,
                        height: rect.height
                    )
                    break
                }
            }

            semaphore.signal()
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            _ = semaphore.wait(timeout: .now() + 3.0)
        } catch {
            print("Error detecting license plate: \(error)")
        }

        return detectedRect
    }

    /// Verifica se il testo corrisponde a un pattern di targa
    private static func isLicensePlatePattern(_ text: String) -> Bool {
        // Pattern targa italiana: 2 lettere, 3 numeri, 2 lettere (es: AB123CD)
        let italianPattern = "^[A-Z]{2}[0-9]{3}[A-Z]{2}$"

        // Pattern generico europeo: mix di lettere e numeri, lunghezza 5-8
        let europeanPattern = "^(?=.*[A-Z])(?=.*[0-9])[A-Z0-9]{5,8}$"

        let italianRegex = try? NSRegularExpression(pattern: italianPattern)
        let europeanRegex = try? NSRegularExpression(pattern: europeanPattern)

        let range = NSRange(location: 0, length: text.count)

        if italianRegex?.firstMatch(in: text, range: range) != nil {
            return true
        }

        if europeanRegex?.firstMatch(in: text, range: range) != nil {
            return true
        }

        return false
    }

    /// Applica un effetto blur alla regione specificata dell'immagine
    private static func applyBlur(to image: UIImage, in region: CGRect) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            return image
        }

        let context = CIContext()

        // Crea un'immagine pixellata (più privacy-friendly del semplice blur)
        let pixellateFilter = CIFilter(name: "CIPixellate")
        pixellateFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        pixellateFilter?.setValue(max(region.width / 15, 8.0), forKey: kCIInputScaleKey)

        guard let pixellatedImage = pixellateFilter?.outputImage else {
            return image
        }

        // Applica anche un blur gaussiano per rendere ancora più difficile la lettura
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(pixellatedImage, forKey: kCIInputImageKey)
        blurFilter?.setValue(10.0, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurFilter?.outputImage else {
            return image
        }

        // Crea una maschera per la regione da offuscare
        let maskFilter = CIFilter(name: "CIBlendWithMask")
        maskFilter?.setValue(blurredImage, forKey: kCIInputImageKey)
        maskFilter?.setValue(ciImage, forKey: kCIInputBackgroundImageKey)

        // Crea una maschera rettangolare
        let maskImage = createRoundedRectMask(for: region, imageSize: ciImage.extent.size)
        maskFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)

        guard let outputImage = maskFilter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Crea una maschera rettangolare con bordi arrotondati
    private static func createRoundedRectMask(for rect: CGRect, imageSize: CGSize) -> CIImage {
        // Crea un contesto grafico
        let size = imageSize
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return CIImage()
        }

        // Riempi tutto di nero (trasparente)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Disegna un rettangolo bianco arrotondato nella regione da offuscare
        context.setFillColor(UIColor.white.cgColor)
        let roundedRect = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.2)
        roundedRect.fill()

        let maskImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return CIImage(image: maskImage ?? UIImage()) ?? CIImage()
    }
}
