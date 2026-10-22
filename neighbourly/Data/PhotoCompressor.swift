//
//  PhotoCompressor.swift
//  neighbourly
//
//  Shrinks photos so they fit in Firestore documents (1 MiB limit) on the free
//  plan, where Cloud Storage isn't available. Full photos target about 150 KB and
//  card thumbnails about 25 KB.
//

import Foundation
import UIKit

nonisolated enum PhotoCompressor {
    static let fullPhotoMaxBytes = 150_000
    static let fullPhotoMaxEdge: CGFloat = 1200
    static let thumbnailMaxBytes = 25_000
    static let thumbnailMaxEdge: CGFloat = 300

    /// A JPEG of the photo no larger than `maxBytes`, or nil if the data isn't an image
    /// or can't be made small enough.
    static func jpeg(from imageData: Data, maxEdge: CGFloat, maxBytes: Int) -> Data? {
        guard let source = UIImage(data: imageData) else { return nil }

        // Try gentler settings first; each round lowers quality, and when quality bottoms
        // out the picture itself gets smaller.
        var edge = maxEdge
        for _ in 0..<6 {
            let resized = resized(source, longestEdge: edge)
            for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
                if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
                    return data
                }
            }
            edge *= 0.75
        }
        return nil
    }

    static func fullPhoto(from imageData: Data) -> Data? {
        jpeg(from: imageData, maxEdge: fullPhotoMaxEdge, maxBytes: fullPhotoMaxBytes)
    }

    static func thumbnail(from imageData: Data) -> Data? {
        jpeg(from: imageData, maxEdge: thumbnailMaxEdge, maxBytes: thumbnailMaxBytes)
    }

    /// Scales down so the longest edge is at most `longestEdge` pixels (never scales up).
    private static func resized(_ image: UIImage, longestEdge: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > longestEdge else { return image }

        let ratio = longestEdge / longest
        let target = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
