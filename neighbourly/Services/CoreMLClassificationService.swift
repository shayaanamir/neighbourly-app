//
//  CoreMLClassificationService.swift
//  neighbourly
//
//  Classifies photos with a pretrained Core ML image classifier bundled in the app
//  (MobileNetV2, ImageNet labels). It runs entirely on device, including in the
//  Simulator (on the CPU), and needs no network or API key.
//
//  The model is loaded by name at runtime rather than through Xcode's generated
//  class, so the project builds even before the model file is added; a missing
//  model just makes classification report "unavailable".
//

import CoreML
import Foundation
import OSLog
import Vision

nonisolated struct CoreMLClassificationService: ImageClassifying {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "CoreML")

    /// Compiled model resource name (the `.mlmodel` file's name without extension).
    static let defaultModelName = "MobileNetV2"

    let modelName: String
    let bundle: Bundle

    init(modelName: String = CoreMLClassificationService.defaultModelName, bundle: Bundle = .main) {
        self.modelName = modelName
        self.bundle = bundle
    }

    /// True if the compiled model is present in the bundle.
    var isModelAvailable: Bool {
        bundle.url(forResource: modelName, withExtension: "mlmodelc") != nil
    }

    func classify(imageData: Data) async throws -> [ClassifiedLabel] {
        // Core ML and Vision are synchronous and slow; keep them off the main actor.
        try await Task.detached(priority: .userInitiated) {
            try classifySynchronously(imageData)
        }.value
    }

    private func classifySynchronously(_ data: Data) throws -> [ClassifiedLabel] {
        let model = try Self.cache.model(named: modelName, in: bundle)

        var passes: [[ClassifiedLabel]] = []
        var lastError: Error?
        for image in try ClassificationImage.regions(from: data, includeCorners: false) {
            try Task.checkCancellation()
            do {
                let request = VNCoreMLRequest(model: model)
                // Letterbox instead of centre-cropping so items near the edges aren't cut off.
                request.imageCropAndScaleOption = .scaleFit
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

                let observations = (request.results as? [VNClassificationObservation]) ?? []
                guard !observations.isEmpty else {
                    // The request ran but produced nothing usable (for example a different
                    // observation type); don't count this pass as a success.
                    let kinds = (request.results ?? []).map { String(describing: type(of: $0)) }
                    lastError = VisionAssistError.classifierFailed(reason: "no classifications; got \(kinds)")
                    continue
                }
                passes.append(observations.prefix(10).map {
                    ClassifiedLabel(identifier: $0.identifier, confidence: $0.confidence)
                })
            } catch {
                lastError = error
            }
        }

        guard !passes.isEmpty else {
            Self.logger.error("Core ML classification failed: \(lastError?.localizedDescription ?? "no results", privacy: .public)")
            throw VisionAssistError.classifierFailed(reason: lastError.map { "\($0)" } ?? "no results")
        }

        let labels = ClassificationImage.merge(passes)
        let top = labels.prefix(5)
            .map { "\($0.identifier)=\(String(format: "%.2f", $0.confidence))" }
            .joined(separator: " | ")
        Self.logger.info("Core ML top labels: \(top, privacy: .public)")
        return labels
    }

    // MARK: - Model cache

    /// Loading a model takes noticeable time, so each model is loaded once per launch.
    private static let cache = ModelCache()

    private final class ModelCache: @unchecked Sendable {
        private let lock = NSLock()
        private var models: [String: VNCoreMLModel] = [:]

        func model(named name: String, in bundle: Bundle) throws -> VNCoreMLModel {
            lock.lock()
            defer { lock.unlock() }

            let key = "\(bundle.bundleURL.path)/\(name)"
            if let cached = models[key] { return cached }

            guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else {
                CoreMLClassificationService.logger.error("Model \(name, privacy: .public).mlmodelc not found in bundle")
                throw VisionAssistError.modelUnavailable
            }
            do {
                let configuration = MLModelConfiguration()
                #if targetEnvironment(simulator)
                // The Simulator has no Neural Engine; CPU-only is the reliable path there.
                configuration.computeUnits = .cpuOnly
                #endif
                let mlModel = try MLModel(contentsOf: url, configuration: configuration)
                let model = try VNCoreMLModel(for: mlModel)
                models[key] = model
                return model
            } catch {
                CoreMLClassificationService.logger.error("Model load failed: \(error.localizedDescription, privacy: .public)")
                throw VisionAssistError.modelUnavailable
            }
        }
    }
}
