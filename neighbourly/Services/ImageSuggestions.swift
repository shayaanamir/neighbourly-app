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
    /// Human-readable labels that point at a known category, most confident first.
    /// Unrelated scene labels (sky, outdoor, ...) are left out on purpose.
    var labels: [String]
    /// Text found in the image, one entry per recognised line.
    var textLines: [String]
    /// True when image classification itself failed (as opposed to finding nothing),
    /// so the UI can say the category is unknown rather than showing a fake guess.
    var classificationUnavailable = false
    /// Everything the classifier reported with its confidence (e.g. "Chair 12%"), including
    /// labels that don't map to a category. Shown tucked away so users can see why a
    /// suggestion was or wasn't made.
    var allLabels: [String] = []

    /// True when there is nothing worth showing the user.
    var isEmpty: Bool { labels.isEmpty && textLines.isEmpty && allLabels.isEmpty }
}

nonisolated struct ClassifiedLabel: Equatable, Sendable {
    var identifier: String
    var confidence: Float
}

nonisolated enum VisionAssistError: LocalizedError, Sendable {
    case unreadableImage
    case unavailable
    /// The bundled Core ML model is missing from the app or failed to load.
    case modelUnavailable
    /// The model loaded but running it on the photo failed; `reason` is the underlying error,
    /// kept so a failing test or log says why.
    case classifierFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "That photo couldn't be analysed."
        case .unavailable: "Image analysis isn't available right now."
        case .modelUnavailable: "The image recognition model couldn't be loaded."
        case .classifierFailed: "The photo couldn't be recognised."
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
    /// A small curated vocabulary. Labels come from the bundled Core ML model (ImageNet names
    /// such as "rocking chair, rocker") or from Vision's classifier (identifiers such as
    /// "coffee_table"). Each label is split into lowercase words and the words are matched.
    private static let keywords: [ListingCategory: Set<String>] = [
        .electronics: [
            "electronics", "electronic", "laptop", "computer", "keyboard", "mouse", "monitor",
            "television", "tv", "phone", "telephone", "cellphone", "smartphone", "tablet",
            "camera", "headphones", "headset", "speaker", "loudspeaker", "microphone", "remote",
            "charger", "cable", "printer", "console", "radio", "screen", "display", "ipod",
            "projector", "modem", "joystick",
        ],
        .books: [
            "book", "books", "textbook", "notebook", "magazine", "novel", "paperback",
            "comic", "publication", "encyclopedia", "dictionary", "binder",
        ],
        .furniture: [
            "furniture", "chair", "armchair", "sofa", "couch", "table", "desk", "bed",
            "mattress", "shelf", "bookshelf", "bookcase", "cabinet", "drawer", "wardrobe",
            "stool", "bench", "dresser", "recliner", "seat", "seating", "chairs", "tables",
            "ottoman", "rocker", "crib", "cradle", "bassinet", "throne", "chiffonier",
        ],
        .clothing: [
            "clothing", "apparel", "shirt", "tshirt", "jacket", "coat", "dress", "jeans", "jean",
            "pants", "trousers", "shoe", "shoes", "sneaker", "boot", "sandal", "hat", "cap",
            "sweater", "hoodie", "scarf", "backpack", "handbag", "purse", "sock", "glove",
            "suit", "skirt", "jersey", "sweatshirt", "cardigan", "gown", "kimono", "poncho",
            "cloak", "sombrero", "bonnet", "wallet", "tie", "stole", "trunks", "bikini",
            "maillot", "pajama", "sarong", "abaya", "loafer", "clog", "sunglass", "sunglasses",
            "mitten",
        ],
        .home: [
            "kitchen", "cookware", "pot", "pan", "kettle", "cup", "mug", "plate", "bowl",
            "utensil", "cutlery", "microwave", "refrigerator", "oven", "blender", "toaster",
            "lamp", "curtain", "pillow", "blanket", "vase", "clock", "appliance", "fan",
            "vacuum", "cooker", "bottle", "teapot", "coffeepot", "pitcher", "jug", "wok",
            "caldron", "ladle", "spatula", "spoon", "dishwasher", "washer", "stove", "waffle",
            "lampshade", "quilt", "towel", "washbasin", "bathtub", "candle", "rotisserie",
            "opener", "corkscrew", "plunger", "broom", "bucket", "thermos", "saucepan",
        ],
        .sports: [
            "sport", "sports", "ball", "football", "soccer", "basketball", "cricket", "bat",
            "racket", "racquet", "tennis", "badminton", "bicycle", "bike", "helmet",
            "dumbbell", "yoga", "skateboard", "treadmill", "golf", "gym", "fitness",
            "volleyball", "baseball", "barbell", "ski", "unicycle", "paddle", "canoe",
            "scuba", "snorkel",
        ],
        .toys: [
            "toy", "toys", "doll", "teddy", "puzzle", "lego", "game", "boardgame", "chess",
            "plush", "stuffed", "pinwheel", "tricycle",
        ],
    ]

    /// Whole phrases that beat the single-word vocabulary, for labels whose words would
    /// otherwise point at the wrong category ("book jacket" is a book, not clothing).
    private static let phraseOverrides: [(phrase: String, category: ListingCategory)] = [
        ("book jacket", .books),
        ("comic book", .books),
        ("table lamp", .home),
        ("pool table", .sports),
        ("billiard table", .sports),
        ("punching bag", .sports),
        ("balance beam", .sports),
        ("horizontal bar", .sports),
        ("parallel bars", .sports),
        ("four poster", .furniture),
        ("dining table", .furniture),
    ]

    /// Category of one label, or nil if it doesn't map to any.
    static func category(forLabel identifier: String) -> ListingCategory? {
        // Lowercase letters and single spaces only: "Four-poster" -> "four poster".
        let words = identifier.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        let normalized = words.joined(separator: " ")

        for override in phraseOverrides where normalized.contains(override.phrase) {
            return override.category
        }
        // allCases order keeps the result deterministic if a label matches several.
        for category in ListingCategory.allCases {
            guard let vocabulary = keywords[category] else { continue }
            if words.contains(where: { word in
                vocabulary.contains(word) || (word.hasSuffix("s") && vocabulary.contains(String(word.dropLast())))
            }) {
                return category
            }
        }
        return nil
    }

    /// Category with the most total confidence across the labels that map to one; `.other`
    /// if none do. Adding confidences means three weak "table"-ish labels can outvote one
    /// stronger unrelated label.
    static func category(for labels: [ClassifiedLabel]) -> ListingCategory {
        var mass: [ListingCategory: Float] = [:]
        for label in labels {
            if let category = category(forLabel: label.identifier) {
                mass[category, default: 0] += label.confidence
            }
        }
        // Iterate allCases (not the dictionary) so ties resolve deterministically.
        var best: ListingCategory = .other
        var bestMass: Float = 0
        for category in ListingCategory.allCases {
            if let total = mass[category], total > bestMass {
                best = category
                bestMass = total
            }
        }
        return best
    }

    private static let textHints: [(ListingCategory, Set<String>)] = [
        (.books, ["isbn", "novel", "edition", "author", "paperback", "hardcover", "publisher", "publishers", "bestseller"]),
    ]

    /// Category implied by printed words, or nil if none match.
    static func category(forText lines: [String]) -> ListingCategory? {
        let words = Set(lines.flatMap { $0.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) })
        return textHints.first { !$0.1.isDisjoint(with: words) }?.0
    }

    /// "coffee_table" -> "Coffee table"; "rocking chair, rocker" -> "Rocking chair"
    /// (ImageNet labels list synonyms after commas; the first is the main name).
    static func displayName(for identifier: String) -> String {
        let firstName = identifier.split(separator: ",", maxSplits: 1).first.map(String.init) ?? identifier
        let spaced = firstName
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}

// MARK: - Building suggestions from raw Vision output

nonisolated enum SuggestionBuilder {
    /// Classifier confidences are spread over ~1,300 labels, so even a correct one is often low.
    static let minimumLabelConfidence: Float = 0.05
    static let minimumRawConfidence: Float = 0.02
    static let maxRawLabels = 8
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
            labels: confident
                .filter { ListingCategoryMapper.category(for: [$0]) != .other }
                .prefix(maxLabels)
                .map { ListingCategoryMapper.displayName(for: $0.identifier) },
            textLines: textLines,
            classificationUnavailable: !classificationAvailable,
            allLabels: labels
                .filter { $0.confidence >= minimumRawConfidence }
                .sorted { $0.confidence > $1.confidence }
                .prefix(maxRawLabels)
                .map { "\(ListingCategoryMapper.displayName(for: $0.identifier)) \(Int(($0.confidence * 100).rounded()))%" }
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
