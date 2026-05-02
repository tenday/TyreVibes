//
//  TyreTextAreaDetectorService.swift
//  TyreVibes
//
//  Created by AI Assistant on 02/05/2026.
//

import CoreGraphics
import CoreML
import Foundation
import Vision

struct TyreTextAreaDetection: Equatable {
    let boundingBox: CGRect
    let confidence: Double
    let category: TyreSidewallTextCategory
}

enum TyreSidewallTextCategory: String, CaseIterable {
    case brand
    case dot
    case model
    case size
    case textArea
    case unknown

    init(label: String) {
        let normalized = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "brand":
            self = .brand
        case "dot":
            self = .dot
        case "model":
            self = .model
        case "size":
            self = .size
        case "text-area", "text-area-6020":
            self = .textArea
        default:
            self = .unknown
        }
    }

    init(classIndex: Int) {
        switch classIndex {
        case 0:
            self = .brand
        case 1:
            self = .dot
        case 2:
            self = .model
        case 3:
            self = .size
        default:
            self = .unknown
        }
    }
}

final class TyreTextAreaDetectorService {
    static let shared = TyreTextAreaDetectorService()

    private let modelName = "TyreTextAreaDetector"
    private let queue = DispatchQueue(label: "com.tyrevibes.tyre-text-area-detector", qos: .userInitiated)
    private lazy var visionModel: VNCoreMLModel? = loadVNModel(named: modelName)

    private init() {}

    func detect(
        in image: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        minimumConfidence: Float = 0.25,
        maxDetections: Int = 8
    ) async -> [TyreTextAreaDetection] {
        guard let visionModel else {
            return []
        }

        return await withCheckedContinuation { continuation in
            queue.async {
                let request = VNCoreMLRequest(model: visionModel) { request, _ in
                    if let objectObservations = request.results as? [VNRecognizedObjectObservation] {
                        continuation.resume(returning: Self.mapObjectObservations(
                            objectObservations,
                            minimumConfidence: minimumConfidence,
                            maxDetections: maxDetections
                        ))
                        return
                    }

                    let featureObservations = (request.results as? [VNCoreMLFeatureValueObservation]) ?? []
                    continuation.resume(returning: Self.mapNMSFeatureObservations(
                        featureObservations,
                        minimumConfidence: minimumConfidence,
                        maxDetections: maxDetections
                    ))
                }
                request.imageCropAndScaleOption = .scaleFill

                do {
                    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
                    try handler.perform([request])
                } catch {
                    print("⚠️ [TyreTextArea] Detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private static func mapObjectObservations(
        _ observations: [VNRecognizedObjectObservation],
        minimumConfidence: Float,
        maxDetections: Int
    ) -> [TyreTextAreaDetection] {
        observations
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxDetections)
            .map {
                        TyreTextAreaDetection(
                            boundingBox: $0.boundingBox,
                            confidence: Double($0.confidence),
                            category: TyreSidewallTextCategory(
                                label: $0.labels.first?.identifier ?? ""
                            )
                        )
            }
    }

    private static func mapNMSFeatureObservations(
        _ observations: [VNCoreMLFeatureValueObservation],
        minimumConfidence: Float,
        maxDetections: Int
    ) -> [TyreTextAreaDetection] {
        guard let confidenceArray = observations.first(where: { $0.featureName == "confidence" })?.featureValue.multiArrayValue,
              let coordinatesArray = observations.first(where: { $0.featureName == "coordinates" })?.featureValue.multiArrayValue else {
            return []
        }

        let boxCount = coordinatesArray.count / 4
        guard boxCount > 0 else { return [] }

        let classCount = max(1, confidenceArray.count / boxCount)
        var detections: [TyreTextAreaDetection] = []

        for index in 0..<boxCount {
            var bestConfidence: Float = 0
            for classIndex in 0..<classCount {
                guard let confidence = confidenceValue(
                    in: confidenceArray,
                    boxIndex: index,
                    classIndex: classIndex,
                    boxCount: boxCount,
                    classCount: classCount
                ) else { continue }

                bestConfidence = max(bestConfidence, confidence)
            }

            guard bestConfidence >= minimumConfidence else { continue }
            let bestClassIndex = bestClassIndex(
                in: confidenceArray,
                boxIndex: index,
                boxCount: boxCount,
                classCount: classCount
            )

            let coordinateIndex = index * 4
            guard coordinateIndex + 3 < coordinatesArray.count else { continue }

            let centerX = CGFloat(coordinatesArray[coordinateIndex].doubleValue)
            let centerY = CGFloat(coordinatesArray[coordinateIndex + 1].doubleValue)
            let width = CGFloat(coordinatesArray[coordinateIndex + 2].doubleValue)
            let height = CGFloat(coordinatesArray[coordinateIndex + 3].doubleValue)

            let box = CGRect(
                x: centerX - width / 2,
                y: centerY - height / 2,
                width: width,
                height: height
            ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

            guard !box.isNull, box.width > 0, box.height > 0 else { continue }
            detections.append(TyreTextAreaDetection(
                boundingBox: box,
                confidence: Double(bestConfidence),
                category: TyreSidewallTextCategory(classIndex: bestClassIndex)
            ))
        }

        return Array(detections
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxDetections))
    }

    private static func bestClassIndex(
        in confidenceArray: MLMultiArray,
        boxIndex: Int,
        boxCount: Int,
        classCount: Int
    ) -> Int {
        guard classCount > 1 else { return 0 }

        var bestIndex = 0
        var bestConfidence: Float = 0

        for classIndex in 0..<classCount {
            guard let confidence = confidenceValue(
                in: confidenceArray,
                boxIndex: boxIndex,
                classIndex: classIndex,
                boxCount: boxCount,
                classCount: classCount
            ) else { continue }

            if confidence > bestConfidence {
                bestConfidence = confidence
                bestIndex = classIndex
            }
        }

        return bestIndex
    }

    private static func confidenceValue(
        in confidenceArray: MLMultiArray,
        boxIndex: Int,
        classIndex: Int,
        boxCount: Int,
        classCount: Int
    ) -> Float? {
        let shape = confidenceArray.shape.map(\.intValue)
        let strides = confidenceArray.strides.map(\.intValue)

        if shape.count >= 2, strides.count >= 2 {
            if shape[0] == boxCount, classIndex < shape[1] {
                let index = boxIndex * strides[0] + classIndex * strides[1]
                guard index < confidenceArray.count else { return nil }
                return confidenceArray[index].floatValue
            }

            if shape[1] == boxCount, classIndex < shape[0] {
                let index = classIndex * strides[0] + boxIndex * strides[1]
                guard index < confidenceArray.count else { return nil }
                return confidenceArray[index].floatValue
            }
        }

        let rowMajorIndex = boxIndex * classCount + classIndex
        if rowMajorIndex < confidenceArray.count {
            return confidenceArray[rowMajorIndex].floatValue
        }

        let columnMajorIndex = classIndex * boxCount + boxIndex
        guard columnMajorIndex < confidenceArray.count else { return nil }
        return confidenceArray[columnMajorIndex].floatValue
    }

    private func loadVNModel(named name: String) -> VNCoreMLModel? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        if let compiledURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            do {
                let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
                return try VNCoreMLModel(for: model)
            } catch {
                print("[TyreTextArea] Impossibile caricare \(name).mlmodelc: \(error)")
            }
        }

        if let packageURL = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
            do {
                let model = try MLModel(contentsOf: packageURL, configuration: configuration)
                return try VNCoreMLModel(for: model)
            } catch {
                print("[TyreTextArea] Impossibile caricare \(name).mlpackage: \(error)")
            }
        }

        print("[TyreTextArea] Modello \(name) non trovato in .mlmodelc né .mlpackage")
        return nil
    }
}
