//
//  VisionAssistService.swift
//  neighbourly
//
//  On-device image classification and OCR using Apple's Vision framework.
//  Nothing leaves the device; no API key or network is involved.
//

import CoreML
import Foundation
import ImageIO
import OSLog
import Vision

nonisolated struct VisionAssistService: VisionAssisting {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "VisionAssist")

    /// Longest edge, in pixels, of the image Vision classifies. Plenty for scene/object labels.
    private static let classificationSize = 1024

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
            labels = try classify(data)
        } catch {
            Self.logger.error("Classification failed: \(error.localizedDescription, privacy: .public)")
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
            Self.logger.error("Text recognition failed: \(error.localizedDescription, privacy: .public)")
            text = nil
        }

        if labels == nil && text == nil {
            throw VisionAssistError.unavailable
        }
        return SuggestionBuilder.make(
            labels: labels ?? [],
            recognizedText: text ?? [],
            classificationAvailable: labels != nil
        )
    }

    // MARK: - Classification

    /// Vision's classifier labels the whole scene, so an item sitting in a busy or dark
    /// photo (a book next to a candle, say) can be drowned out. To counter that, classify
    /// the full image plus overlapping crops and keep each label's best confidence.
    private static func classify(_ data: Data) throws -> [ClassifiedLabel] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true, // apply EXIF rotation
                  kCGImageSourceThumbnailMaxPixelSize: classificationSize,
              ] as CFDictionary)
        else { throw VisionAssistError.unreadableImage }

        var best: [String: Float] = [:]
        var succeeded = false
        var lastError: Error?

        for crop in cropRegions(width: image.width, height: image.height) {
            try Task.checkCancellation()
            guard let cropped = crop == nil ? image : image.cropping(to: crop!) else { continue }
            do {
                let request = makeClassifyRequest()
                try VNImageRequestHandler(cgImage: cropped, options: [:]).perform([request])
                succeeded = true
                for observation in request.results ?? [] {
                    best[observation.identifier] = max(best[observation.identifier] ?? 0, observation.confidence)
                }
            } catch {
                lastError = error
            }
        }

        if !succeeded, let lastError { throw lastError }
        return best.map { ClassifiedLabel(identifier: $0.key, confidence: $0.value) }
    }

    /// nil means "the whole image"; the rest are the centre and four overlapping corners,
    /// each covering 60% of the width and height.
    private static func cropRegions(width: Int, height: Int) -> [CGRect?] {
        func region(_ x: Double, _ y: Double) -> CGRect {
            CGRect(
                x: (Double(width) * x).rounded(),
                y: (Double(height) * y).rounded(),
                width: (Double(width) * 0.6).rounded(),
                height: (Double(height) * 0.6).rounded()
            )
        }
        return [nil, region(0.2, 0.2), region(0, 0), region(0.4, 0), region(0, 0.4), region(0.4, 0.4)]
    }

    private static func makeClassifyRequest() -> VNClassifyImageRequest {
        let request = VNClassifyImageRequest()
        #if targetEnvironment(simulator)
        // The Simulator has no Neural Engine/GPU path for classification; use the CPU.
        if let cpu = MLComputeDevice.allComputeDevices.first(where: { device in
            if case .cpu = device { return true }
            return false
        }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        return request
    }
}
