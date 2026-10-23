//
//  VisionBuiltInClassifier.swift
//  neighbourly
//
//  Vision's own scene classifier (`VNClassifyImageRequest`). It is only a fallback
//  for when the Core ML model can't load, and only on a physical device: the
//  Simulator's version doesn't read the image (it returns the same "night sky / moon"
//  labels for every photo), so it reports "unavailable" there instead.
//

import Foundation
import OSLog
import Vision

nonisolated struct VisionBuiltInClassifier: ImageClassifying {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "VisionClassify")

    /// nil on the Simulator, where this classifier can't be trusted.
    static var ifSupported: VisionBuiltInClassifier? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return VisionBuiltInClassifier()
        #endif
    }

    func classify(imageData: Data) async throws -> [ClassifiedLabel] {
        try await Task.detached(priority: .userInitiated) {
            try classifySynchronously(imageData)
        }.value
    }

    private func classifySynchronously(_ data: Data) throws -> [ClassifiedLabel] {
        #if targetEnvironment(simulator)
        throw VisionAssistError.unavailable
        #else
        var passes: [[ClassifiedLabel]] = []
        var lastError: Error?

        for image in try ClassificationImage.regions(from: data, includeCorners: true) {
            try Task.checkCancellation()
            do {
                let request = VNClassifyImageRequest()
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                passes.append((request.results ?? []).map { observation in
                    // Raw confidences aren't comparable between labels; Vision's own
                    // precision/recall check says which ones are trustworthy.
                    var confidence = observation.confidence
                    if observation.hasMinimumPrecision(0.1, forRecall: 0.7) {
                        confidence = max(confidence, SuggestionBuilder.minimumLabelConfidence * 2)
                    }
                    return ClassifiedLabel(identifier: observation.identifier, confidence: confidence)
                })
            } catch {
                lastError = error
            }
        }

        guard !passes.isEmpty else {
            Self.logger.error("Vision classification failed: \(lastError?.localizedDescription ?? "no results", privacy: .public)")
            throw VisionAssistError.classifierFailed(reason: lastError.map { "\($0)" } ?? "no results")
        }
        return ClassificationImage.merge(passes)
        #endif
    }
}
