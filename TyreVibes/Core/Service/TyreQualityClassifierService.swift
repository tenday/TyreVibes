//
//  TyreQualityClassifierService.swift
//  TyreVibes
//
//  Created by AI Assistant on 02/05/2026.
//

import CoreML
import Foundation
@preconcurrency import Vision

struct TyreQualityPrediction: Equatable {
    let label: String
    let confidence: Double
    let probabilities: [String: Double]

    var isDefective: Bool {
        label.lowercased() == "defective"
    }

    var displayName: String {
        isDefective ? "Difetto rilevato" : "Gomma OK"
    }

    var confidencePercentage: Int {
        Int((confidence * 100).rounded())
    }
}

enum TyreQualityClassifierError: LocalizedError {
    case modelNotFound
    case invalidResults

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Modello TyreQualityClassifier non trovato nel bundle"
        case .invalidResults:
            return "Risultato classificazione non valido"
        }
    }
}

final class TyreQualityClassifierService {
    static let shared = TyreQualityClassifierService()

    private let modelName = "TyreQualityClassifier"
    private let queue = DispatchQueue(label: "com.tyrevibes.tyre-quality-classifier", qos: .userInitiated)
    private lazy var visionModel: VNCoreMLModel? = loadVNModel(named: modelName)

    private init() {}

    func classify(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right
    ) async throws -> TyreQualityPrediction {
        guard let visionModel else {
            throw TyreQualityClassifierError.modelNotFound
        }
        nonisolated(unsafe) let requestPixelBuffer = pixelBuffer

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let request = VNCoreMLRequest(model: visionModel) { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let observations = request.results as? [VNClassificationObservation],
                          let best = observations.first else {
                        continuation.resume(throwing: TyreQualityClassifierError.invalidResults)
                        return
                    }

                    let probabilities = Dictionary(
                        uniqueKeysWithValues: observations.map {
                            ($0.identifier, Double($0.confidence))
                        }
                    )

                    continuation.resume(returning: TyreQualityPrediction(
                        label: best.identifier,
                        confidence: Double(best.confidence),
                        probabilities: probabilities
                    ))
                }
                request.imageCropAndScaleOption = .scaleFill

                do {
                    let handler = VNImageRequestHandler(
                        cvPixelBuffer: requestPixelBuffer,
                        orientation: orientation,
                        options: [:]
                    )
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadVNModel(named name: String) -> VNCoreMLModel? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        if let compiledURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            do {
                let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
                return try VNCoreMLModel(for: model)
            } catch {
                print("[TyreQuality] Impossibile caricare \(name).mlmodelc: \(error)")
            }
        }

        if let packageURL = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
            do {
                let model = try MLModel(contentsOf: packageURL, configuration: configuration)
                return try VNCoreMLModel(for: model)
            } catch {
                print("[TyreQuality] Impossibile caricare \(name).mlpackage: \(error)")
            }
        }

        print("[TyreQuality] Modello \(name) non trovato in .mlmodelc né .mlpackage")
        return nil
    }
}
