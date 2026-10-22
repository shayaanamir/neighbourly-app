//
//  VisionAssistService.swift
//  neighbourly
//
//  On-device image classification and OCR using Apple's Vision framework.
//  Nothing leaves the device; no API key or network is involved.
//

import Foundation
import ImageIO
import Vision

nonisolated struct VisionAssistService: VisionAssisting {
    func analyze(imageData: Data) async throws -> ImageSuggestions {
        // Vision's perform(_:) is synchronous and slow; keep it off the main actor.
        try await Task.detached(priority: .userInitiated) {
            try Self.analyzeSynchronously(imageData)
        }.value
    }

    private static func analyzeSynchronously(_ data: Data) throws -> ImageSuggestions {
        guard CGImageSourceCreateWithData(data as CFData, nil) != nil else {
            throw VisionAssistError.unreadableImage
        }

        // Run the two requests independently so one failing (e.g. classification
        // on an unsupported device) doesn't discard the other's result.
        var labels: [ClassifiedLabel]?
        var text: [String]?

        do {
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            labels = (request.results ?? []).map {
                ClassifiedLabel(identifier: $0.identifier, confidence: $0.confidence)
            }
        } catch {
            labels = nil
        }

        try Task.checkCancellation()

        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            text = (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.5 else {
                    return nil
                }
                return candidate.string
            }
        } catch {
            text = nil
        }

        if labels == nil && text == nil {
            throw VisionAssistError.unavailable
        }
        return SuggestionBuilder.make(labels: labels ?? [], recognizedText: text ?? [])
    }
}
