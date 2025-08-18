import UIKit // Per la manipolazione delle immagini (UIImage) e Core Graphics
import Vision // Per il framework di visione artificiale

// MARK: - Funzione per Identificare e Evidenziare un Rettangolo Bianco

/// Identifica i rettangoli in una data immagine, verifica se sono bianchi e li evidenzia.
///
/// - Parameters:
///   - inputImage: L'immagine `UIImage` su cui eseguire l'identificazione.
///   - completion: Un closure che viene chiamato al termine dell'operazione,
///                 passando l'immagine risultante con il rettangolo bianco evidenziato, o `nil` in caso di errore.
func identifyAndHighlightWhiteRectangle(inputImage: UIImage, completion: @escaping (UIImage?) -> Void) {

    // 1. Converti UIImage in CIImage per l'elaborazione Vision
    guard let ciImage = CIImage(image: inputImage) else {
        print("Errore: Impossibile creare CIImage dall'immagine di input.")
        completion(nil)
        return
    }

    // 2. Crea una richiesta Vision per rilevare i rettangoli
    let rectangleDetectionRequest = VNDetectRectanglesRequest { (request, error) in
        // Questo blocco viene eseguito quando la richiesta di Vision è completata.

        if let error = error {
            print("Errore nella richiesta Vision per il rilevamento rettangoli: \(error.localizedDescription)")
            completion(nil)
            return
        }

        // Recupera i risultati del rilevamento.
        guard let observations = request.results as? [VNRectangleObservation] else {
            print("Nessun rettangolo rilevato.")
            completion(inputImage) // Restituisce l'immagine originale se nessun rettangolo è trovato
            return
        }

        // 3. Prepara un contesto grafico per disegnare sull'immagine originale
        UIGraphicsBeginImageContextWithOptions(inputImage.size, false, inputImage.scale)
        inputImage.draw(at: .zero) // Disegna l'immagine originale come sfondo

        guard let context = UIGraphicsGetCurrentContext() else {
            print("Errore: Impossibile ottenere il contesto grafico.")
            UIGraphicsEndImageContext()
            completion(nil)
            return
        }

        let imageWidth = inputImage.size.width
        let imageHeight = inputImage.size.height

        var foundWhiteRectangle = false

        // 4. Itera sui rettangoli rilevati
        for observation in observations {
            // Ottieni la bounding box normalizzata (Vision usa coordinate da 0 a 1, origine in basso a sinistra)
            let boundingBox = observation.boundingBox

            // Converti la bounding box normalizzata in coordinate dell'immagine (origine in alto a sinistra)
            let rectX = boundingBox.origin.x * imageWidth
            let rectHeight = boundingBox.size.height * imageHeight
            let rectY = (1 - boundingBox.origin.y - boundingBox.size.height) * imageHeight // Le coordinate Y di Vision sono invertite
            let rectWidth = boundingBox.size.width * imageWidth

            let convertedRect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)

            // 5. Estrai la regione del rettangolo dall'immagine originale per analizzare il colore
            if let cgImage = inputImage.cgImage,
               let croppedCGImage = cgImage.cropping(to: convertedRect) {

                let averageColor = UIImage(cgImage: croppedCGImage).averageColor()

                // 6. Controlla se il colore medio è "bianco"
                // Definiamo "bianco" come una media alta di tutti i componenti RGB.
                // Puoi aggiustare queste soglie a seconda di quanto "bianco" deve essere.
                if let color = averageColor,
                   color.red > 0.85 && color.green > 0.85 && color.blue > 0.85 { // Soglie per il bianco
                    
                    foundWhiteRectangle = true
                    // 7. Disegna un bordo attorno al rettangolo bianco trovato
                    context.setStrokeColor(UIColor.green.cgColor) // Colore del bordo (verde per i rettangoli bianchi)
                    context.setLineWidth(5.0) // Spessore del bordo
                    context.stroke(convertedRect) // Disegna il rettangolo
                    print("Rettangolo bianco identificato: \(convertedRect), Confidenza: \(observation.confidence)")
                } else {
                    // Optional: Disegna un bordo diverso per i rettangoli non bianchi (per debug)
                    // context.setStrokeColor(UIColor.blue.cgColor)
                    // context.setLineWidth(2.0)
                    // context.stroke(convertedRect)
                    // print("Rettangolo non bianco rilevato: \(convertedRect)")
                }
            }
        }

        // 8. Ottieni l'immagine finale dal contesto grafico
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()

        // 9. Chiudi il contesto grafico
        UIGraphicsEndImageContext()

        if !foundWhiteRectangle {
            print("Nessun rettangolo bianco significativo trovato nell'immagine.")
        }
        completion(finalImage)
    }

    // 10. Esegui la richiesta Vision su un thread in background
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            try handler.perform([rectangleDetectionRequest])
        } catch {
            print("Errore durante l'esecuzione della richiesta Vision: \(error.localizedDescription)")
            completion(nil)
        }
    }
}

// MARK: - Estensione UIImage per Calcolare il Colore Medio (Helper)

/// Estensione per calcolare il colore medio di un'immagine.
extension UIImage {
    func averageColor() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard let cgImage = self.cgImage else { return nil }

        // Crea un contesto grafico per l'immagine
        let context = CGContext(data: nil,
                                width: cgImage.width,
                                height: cgImage.height,
                                bitsPerComponent: 8,
                                bytesPerRow: cgImage.width * 4, // 4 byte per pixel (RGBA)
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) // RGBA

        guard let ctx = context else { return nil }

        // Disegna l'immagine nel contesto
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        // Ottieni i dati dei pixel
        guard let pixelData = ctx.data else { return nil }
        let data = pixelData.assumingMemoryBound(to: UInt8.self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        let pixelCount = cgImage.width * cgImage.height
        if pixelCount == 0 { return nil }

        // Somma i valori dei componenti RGB di tutti i pixel
        for i in 0..<pixelCount {
            red += CGFloat(data[i * 4])
            green += CGFloat(data[i * 4 + 1])
            blue += CGFloat(data[i * 4 + 2])
            alpha += CGFloat(data[i * 4 + 3])
        }

        // Calcola la media
        red /= CGFloat(pixelCount * 255)
        green /= CGFloat(pixelCount * 255)
        blue /= CGFloat(pixelCount * 255)
        alpha /= CGFloat(pixelCount * 255)

        return (red, green, blue, alpha)
    }
}
