import CoreGraphics
import Vision
import UIKit

extension UIImage {
    /// Returns a copy of the image cropped to the bounding box of non-transparent pixels.
    /// - Parameter threshold: Pixels with alpha greater than this threshold are considered opaque (0-255).
    func trimmedTransparentPixels(threshold: UInt8 = 0) -> UIImage {
        guard let cgImage = self.cgImage else { return self }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var rawData = [UInt8](repeating: 0, count: Int(height * bytesPerRow))
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        // Draw the image into our RGBA buffer
        let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: drawRect)

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var foundAllBounds = false

        var y = 0
        while y < height && !foundAllBounds {
            let row = y * bytesPerRow
            var x = 0
            while x < width {
                let idx = row + x * bytesPerPixel
                let alpha = rawData[idx + 3]
                if alpha > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                    if minX == 0 && maxX == width - 1 && minY == 0 && maxY == height - 1 {
                        foundAllBounds = true
                        break
                    }
                }
                x += 1
            }
            y += 1
        }

        // If the image is fully transparent or already tight, return original
        if minX > maxX || minY > maxY { return self }

        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        // Create a CGImage from the context (matches our scan orientation), then crop
        guard let drawn = context.makeImage(), let cropped = drawn.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cropped, scale: self.scale, orientation: .up)
    }
    
    /// Attempts to detect and mask a license plate. Prefers OCR of the word "IMAG"; falls back to rectangles.
    func maskLicensePlate() -> UIImage {
        guard let cgImage = self.cgImage else { return self }

        // 1) Try OCR for the word "IMAG" (case-insensitive)
        let ocrRects = self.textBoxes(containing: "IMAG")
        if !ocrRects.isEmpty {
            return self.drawBoxes(ocrRects)
        }

        // 2) Fallback: rectangles (bottom-biased) if OCR didn't find anything
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.22
        request.maximumAspectRatio = 0.5
        request.minimumSize = 0.05
        request.maximumObservations = 8
        request.minimumConfidence = 0.3

        let cgOrientation = CGImagePropertyOrientation(self.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
        do {
            try handler.perform([request])
        } catch { return self }

        guard let results = request.results, !results.isEmpty else { return self }

        let filtered = results.filter { r in
            r.boundingBox.minY < 0.5 &&
            r.boundingBox.width >= 0.15 && r.boundingBox.width <= 0.8 &&
            r.boundingBox.height >= 0.03 && r.boundingBox.height <= 0.22
        }
        guard !filtered.isEmpty else { return self }

        let w = self.size.width, h = self.size.height
        let rects = filtered.map { box -> CGRect in
            CGRect(x: box.boundingBox.minX * w,
                   y: (1 - box.boundingBox.maxY) * h,
                   width: box.boundingBox.width * w,
                   height: box.boundingBox.height * h)
        }
        return self.drawBoxes(rects)
    }
    
    /// Finds bounding boxes (in image pixel coordinates) of text observations that contain a given term.
    private func textBoxes(containing term: String, minConfidence: VNConfidence = 0.5) -> [CGRect] {
        guard let cgImage = self.cgImage else { return [] }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US", "it-IT"]
        let orientation = CGImagePropertyOrientation(self.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do { try handler.perform([req]) } catch { return [] }
        guard let results = req.results, !results.isEmpty else { return [] }

        let target = term.uppercased()
        let w = self.size.width, h = self.size.height
        var rects: [CGRect] = []
        for obs in results {
            guard let top = obs.topCandidates(1).first, top.confidence >= minConfidence else { continue }
            if top.string.uppercased().contains(target) {
                // Convert normalized Vision box to UIKit coordinates
                let b = obs.boundingBox
                var r = CGRect(x: b.minX * w,
                               y: (1 - b.maxY) * h,
                               width: b.width * w,
                               height: b.height * h)
                // Expand horizontally a moderate amount to cover logo + extra text, but not too much
                let expansionX = max(15, r.width * 1.8) // about 80% wider than detected text
                let expansionY = max(8, r.height * 1.2) // slightly taller than detected text
                r = r.insetBy(dx: -expansionX, dy: -expansionY)
                // Clamp to image bounds
                let clamped = r.intersection(CGRect(origin: .zero, size: CGSize(width: w, height: h)))
                rects.append(clamped)
            }
        }
        return rects
    }

    /// Draws opaque black rounded rectangles over the given rects and returns the new image.
    private func drawBoxes(_ rects: [CGRect]) -> UIImage {
        guard !rects.isEmpty else { return self }
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: self.size, format: fmt)
        return renderer.image { ctx in
            self.draw(in: CGRect(origin: .zero, size: self.size))
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            for r in rects {
                let rr = UIBezierPath(roundedRect: r.integral, cornerRadius: 6)
                ctx.cgContext.addPath(rr.cgPath)
                ctx.cgContext.fillPath()
            }
        }
    }
    
    private func containsOrange(in rect: VNRectangleObservation, image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let w = image.size.width
        let h = image.size.height
        let cropRect = CGRect(x: rect.boundingBox.minX * w,
                              y: (1 - rect.boundingBox.maxY) * h,
                              width: rect.boundingBox.width * w,
                              height: rect.boundingBox.height * h).integral
        guard cropRect.width > 2, cropRect.height > 2, let cropped = cgImage.cropping(to: cropRect) else { return false }

        let width = cropped.width
        let height = cropped.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(data: &rawData,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        var orangeCount = 0
        var sampleCount = 0
        let step = max(1, min(width, height) / 60) // subsample for speed
        for y in stride(from: 0, to: height, by: step) {
            let row = y * bytesPerRow
            for x in stride(from: 0, to: width, by: step) {
                let idx = row + x * bytesPerPixel
                let r = Float(rawData[idx]) / 255
                let g = Float(rawData[idx + 1]) / 255
                let b = Float(rawData[idx + 2]) / 255
                let maxV = max(r, g, b)
                let minV = min(r, g, b)
                let d = maxV - minV
                var hDeg: Float = 0
                var s: Float = 0
                let v = maxV
                if d != 0 {
                    s = d / maxV
                    if maxV == r { hDeg = 60 * fmodf(((g - b) / d), 6) }
                    else if maxV == g { hDeg = 60 * (((b - r) / d) + 2) }
                    else { hDeg = 60 * (((r - g) / d) + 4) }
                    if hDeg < 0 { hDeg += 360 }
                }
                // Orange gate: hue ~15..45°, sufficiently saturated/bright
                if hDeg >= 15 && hDeg <= 45 && s > 0.4 && v > 0.4 { orangeCount += 1 }
                sampleCount += 1
            }
        }
        guard sampleCount > 0 else { return false }
        return Float(orangeCount) / Float(sampleCount) > 0.01 // 1% orange is enough
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
