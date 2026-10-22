//
//  ImageClassifying.swift
//  neighbourly
//
//  A classifier turns photo bytes into scored labels. The Core ML model is the
//  primary implementation; Vision's built-in classifier is a device-only fallback.
//

import CoreGraphics
import Foundation
import ImageIO

nonisolated protocol ImageClassifying: Sendable {
    /// Labels for the photo, most confident first. Throws if classification can't run.
    func classify(imageData: Data) async throws -> [ClassifiedLabel]
}

nonisolated enum ClassificationImage {
    /// Longest edge, in pixels, of the image handed to a classifier. Plenty for object labels.
    static let maxPixelSize = 1024

    /// The photo (rotated upright and downscaled) followed by overlapping crops.
    ///
    /// Classifiers describe the whole frame, so a small item in a busy photo (a book on a
    /// table next to a candle) can be drowned out. Classifying the centre, and optionally
    /// the corners, lets the item dominate at least one pass.
    static func regions(from data: Data, includeCorners: Bool) throws -> [CGImage] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true, // apply EXIF rotation
                  kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
              ] as CFDictionary)
        else { throw VisionAssistError.unreadableImage }

        func crop(_ x: Double, _ y: Double) -> CGImage? {
            image.cropping(to: CGRect(
                x: (Double(image.width) * x).rounded(),
                y: (Double(image.height) * y).rounded(),
                width: (Double(image.width) * 0.6).rounded(),
                height: (Double(image.height) * 0.6).rounded()
            ))
        }

        var regions = [image]
        if let centre = crop(0.2, 0.2) { regions.append(centre) }
        if includeCorners {
            regions += [crop(0, 0), crop(0.4, 0), crop(0, 0.4), crop(0.4, 0.4)].compactMap { $0 }
        }
        return regions
    }

    /// One entry per label, keeping its best confidence across passes, most confident first.
    static func merge(_ passes: [[ClassifiedLabel]]) -> [ClassifiedLabel] {
        var best: [String: Float] = [:]
        for label in passes.joined() {
            best[label.identifier] = max(best[label.identifier] ?? 0, label.confidence)
        }
        return best
            .map { ClassifiedLabel(identifier: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
    }
}
