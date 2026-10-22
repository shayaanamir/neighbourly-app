//
//  ImageSuggestions.swift
//  neighbourly
//
//  Result types and pure mapping/cleaning logic for the Vision assist
//  feature. No Vision import here, so it is easy to unit test.
//

import Foundation

/// What on-device analysis suggests for a photo. Suggestions only; the user
/// must confirm or edit before anything is saved.
nonisolated struct ImageSuggestions: Equatable, Sendable {
    /// Best-guess category; `.other` when no label maps to a known category.
    var category: ListingCategory
    /// Human-readable top labels, most confident first.
    var labels: [String]
    /// Text found in the image, one entry per recognised line.
    var textLines: [String]
    /// True when image classification itself failed (as opposed to finding nothing),
    /// so the UI can say the category is unknown rather than showing a fake guess.
    var classificationUnavailable = false

    /// True when there is nothing worth showing the user.
    var isEmpty: Bool { labels.isEmpty && textLines.isEmpty }
}

nonisolated struct ClassifiedLabel: Equatable, Sendable {
    var identifier: String
    var confidence: Float
}

nonisolated enum VisionAssistError: LocalizedError, Sendable {
    case unreadableImage
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "That photo couldn't be analysed."
        case .unavailable: "Image analysis isn't available right now."
        }
    }
}

/// Anything that can analyse a photo. The real implementation uses Vision;
/// tests and previews can substitute a stub.
nonisolated protocol VisionAssisting: Sendable {
    func analyze(imageData: Data) async throws -> ImageSuggestions
}

// MARK: - Label → category mapping

nonisolated enum ListingCategoryMapper {
    /// A small curated vocabulary. Vision labels are lowercase identifiers such as
    /// "laptop" or "coffee_table"; each underscore-separated word is matched.
    private static let keywords: [ListingCategory: Set<String>] = [
        .electronics: [
            "electronics", "electronic", "laptop", "computer", "keyboard", "mouse", "monitor",
            "television", "tv", "phone", "telephone", "cellphone", "smartphone", "tablet",
            "camera", "headphones", "headset", "speaker", "microphone", "remote", "charger",
            "cable", "printer", "console", "radio", "screen", "display",
        ],
        .books: [
            "book", "books", "textbook", "notebook", "magazine", "novel", "paperback",
            "comic", "publication", "encyclopedia", "dictionary",
        ],
        .furniture: [
            "furniture", "chair", "armchair", "sofa", "couch", "table", "desk", "bed",
            "mattress", "shelf", "bookshelf", "bookcase", "cabinet", "drawer", "wardrobe",
            "stool", "bench", "dresser", "recliner",
        ],
        .clothing: [
            "clothing", "apparel", "shirt", "tshirt", "jacket", "coat", "dress", "jeans",
            "pants", "trousers", "shoe", "shoes", "sneaker", "boot", "sandal", "hat", "cap",
            "sweater", "hoodie", "scarf", "backpack", "handbag", "purse", "sock", "glove",
            "suit", "skirt",
        ],
        .home: [
            "kitchen", "cookware", "pot", "pan", "kettle", "cup", "mug", "plate", "bowl",
            "utensil", "cutlery", "microwave", "refrigerator", "oven", "blender", "toaster",
            "lamp", "curtain", "pillow", "blanket", "vase", "clock", "appliance", "fan",
            "vacuum", "cooker", "bottle",
        ],
        .sports: [
            "sport", "sports", "ball", "football", "soccer", "basketball", "cricket", "bat",
            "racket", "racquet", "tennis", "badminton", "bicycle", "bike", "helmet",
            "dumbbell", "yoga", "skateboard", "treadmill", "golf", "gym", "fitness",
        ],
        .toys: [
            "toy", "toys", "doll", "teddy", "puzzle", "lego", "game", "boardgame", "chess",
            "plush", "stuffed",
        ],
    ]

    /// Category of the most confident label that maps to one; `.other` if none do.
    static func category(for labels: [ClassifiedLabel]) -> ListingCategory {
        for label in labels.sorted(by: { $0.confidence > $1.confidence }) {
            let words = label.identifier.lowercased()
                .split(whereSeparator: { $0 == "_" || $0 == " " || $0 == "," })
                .map(String.init)
            // allCases order keeps the result deterministic if a label matches several.
            for category in ListingCategory.allCases {
                guard let vocabulary = keywords[category] else { continue }
                if words.contains(where: { vocabulary.contains($0) }) { return category }
            }
        }
        return .other
    }

    private static let textHints: [(ListingCategory, Set<String>)] = [
        (.books, ["isbn", "novel", "edition", "author", "paperback", "hardcover", "publisher", "publishers", "bestseller"]),
    ]

    /// Category implied by printed words, or nil if none match.
    static func category(forText lines: [String]) -> ListingCategory? {
        let words = Set(lines.flatMap { $0.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) })
        return textHints.first { !$0.1.isDisjoint(with: words) }?.0
    }

    /// "coffee_table" -> "Coffee table"
    static func displayName(for identifier: String) -> String {
        let spaced = identifier.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}

// MARK: - Building suggestions from raw Vision output

nonisolated enum SuggestionBuilder {
    static let minimumLabelConfidence: Float = 0.1
    static let maxLabels = 5
    static let maxTextLines = 8
    static let maxTextLineLength = 120

    static func make(
        labels: [ClassifiedLabel],
        recognizedText: [String],
        classificationAvailable: Bool = true
    ) -> ImageSuggestions {
        let confident = labels
            .filter { $0.confidence >= minimumLabelConfidence }
            .sorted { $0.confidence > $1.confidence }
        let textLines = cleanTextLines(recognizedText)

        // Printed words like "ISBN" or "a novel" are a decent hint when the image
        // labels alone don't point at a category.
        var category = ListingCategoryMapper.category(for: confident)
        if category == .other, let fromText = ListingCategoryMapper.category(forText: textLines) {
            category = fromText
        }

        return ImageSuggestions(
            category: category,
            labels: confident.prefix(maxLabels).map { ListingCategoryMapper.displayName(for: $0.identifier) },
            textLines: textLines,
            classificationUnavailable: !classificationAvailable
        )
    }

    /// Trims, drops noise and duplicates, and caps count/length. OCR output is
    /// untrusted, so it is only ever shown and inserted as plain text.
    static func cleanTextLines(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3, trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            let clipped = String(trimmed.prefix(maxTextLineLength))
            guard seen.insert(clipped.lowercased()).inserted else { continue }
            cleaned.append(clipped)
            if cleaned.count == maxTextLines { break }
        }
        return cleaned
    }
}
