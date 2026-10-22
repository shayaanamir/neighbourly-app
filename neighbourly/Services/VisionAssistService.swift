//
//  VisionAssistService.swift
//  neighbourly
//
//  On-device photo assistance for Create Listing: an item-type guess from a
//  classifier (bundled Core ML model first, Vision's classifier as a device-only
//  fallback) plus text recognition with Vision OCR. Nothing leaves the device;
//  no network or API key is involved.
//

import Foundation
import ImageIO
import OSLog
import Vision

nonisolated struct VisionAssistService: VisionAssisting {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "VisionAssist")

    private let primary: any ImageClassifying
    private let fallback: (any ImageClassifying)?

    init(
        primary: any ImageClassifying = CoreMLClassificationService(),
        fallback: (any ImageClassifying)? = VisionBuiltInClassifier.ifSupported
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func analyze(imageData: Data) async throws -> ImageSuggestions {
        guard CGImageSourceCreateWithData(imageData as CFData, nil) != nil else {
            throw VisionAssistError.unreadableImage
        }

        // Classification and OCR are independent: one failing must not discard the other.
        let labels = await classify(imageData)
        try Task.checkCancellation()
        let text = await Self.recognizeText(in: imageData)

        if labels == nil && text == nil {
            throw VisionAssistError.unavailable
        }
        return SuggestionBuilder.make(
            labels: labels ?? [],
            recognizedText: text ?? [],
            classificationAvailable: labels != nil
        )
    }

    /// Core ML first; if that can't run, the Vision fallback; nil if neither works.
    private func classify(_ data: Data) async -> [ClassifiedLabel]? {
        do {
            return try await primary.classify(imageData: data)
        } catch {
            Self.logger.error("Primary classifier failed: \(error.localizedDescription, privacy: .public)")
        }
        guard let fallback else { return nil }
        do {
            return try await fallback.classify(imageData: data)
        } catch {
            Self.logger.error("Fallback classifier failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Recognised lines, or nil if text recognition itself failed.
    private static func recognizeText(in data: Data) async -> [String]? {
        await Task.detached(priority: .userInitiated) { () -> [String]? in
            do {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try VNImageRequestHandler(data: data, options: [:]).perform([request])
                return (request.results ?? []).compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.5 else {
                        return nil
                    }
                    return candidate.string
                }
            } catch {
                Self.logger.error("Text recognition failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }.value
    }
}
