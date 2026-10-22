//
//  PhotoStore.swift
//  neighbourly
//
//  Copies picked photos into app-owned storage as downscaled JPEGs and
//  hands back file names for `Listing.imageFileNames`.
//

import Foundation
import UIKit

nonisolated final class PhotoStore: Sendable {
    nonisolated enum PhotoStoreError: LocalizedError {
        case unreadableImage
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That photo couldn't be read."
            case .encodingFailed: "That photo couldn't be saved."
            }
        }
    }

    /// Longest edge, in pixels, of a stored photo.
    static let maxPixelDimension: CGFloat = 1600

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// Saves image data (any format UIImage can decode) and returns the new file name.
    func save(imageData: Data) throws -> String {
        guard let image = UIImage(data: imageData) else { throw PhotoStoreError.unreadableImage }
        guard let jpeg = Self.downscaled(image).jpegData(compressionQuality: 0.8) else {
            throw PhotoStoreError.encodingFailed
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        try jpeg.write(to: url(for: fileName), options: .atomic)
        return fileName
    }

    /// Saves several photos all-or-nothing: if one fails, the ones already written are removed.
    func save(imagesData: [Data]) throws -> [String] {
        var fileNames: [String] = []
        do {
            for data in imagesData {
                fileNames.append(try save(imageData: data))
            }
        } catch {
            for fileName in fileNames { delete(named: fileName) }
            throw error
        }
        return fileNames
    }

    func url(for fileName: String) -> URL {
        // Only the last path component is used so stored names can't escape the directory.
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        return directory.appending(path: safeName, directoryHint: .notDirectory)
    }

    /// The stored image, or nil if the file is missing or unreadable.
    func image(named fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName).path(percentEncoded: false))
    }

    func fileExists(named fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path(percentEncoded: false))
    }

    func delete(named fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Deletes every stored photo whose name isn't in `names`.
    func removeOrphans(keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height) * image.scale
        guard longestEdge > maxPixelDimension else { return image }

        let ratio = maxPixelDimension / longestEdge
        let target = CGSize(
            width: (size.width * image.scale * ratio).rounded(),
            height: (size.height * image.scale * ratio).rounded()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
