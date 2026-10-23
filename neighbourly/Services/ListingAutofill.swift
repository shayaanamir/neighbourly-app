//
//  ListingAutofill.swift
//  neighbourly
//
//  Turns what on-device analysis found in a photo (item label, printed text) into a draft
//  title, description, and category. Pure wording logic: no framework code, so it is easy
//  to test. Everything it writes is built only from what was recognised plus choices the
//  person already made (condition, listing type); it never invents details like brand,
//  age, or size, and it never touches price or contact fields.
//

import Foundation

nonisolated struct AutofillDraft: Equatable, Sendable {
    var title: String?
    var description: String?
    var category: ListingCategory?

    var isEmpty: Bool { title == nil && description == nil && category == nil }
}

nonisolated enum ListingAutofill {
    static let maxTitleLength = 80
    static let maxDescriptionLength = 1_000
    /// Printed-text lines quoted in the description.
    static let maxQuotedLines = 3
    static let maxNameLineLength = 40

    static func draft(from suggestions: ImageSuggestions, mode: ListingMode, condition: ItemCondition) -> AutofillDraft {
        let label = suggestions.labels.first.map(friendlyName(for:))
        let lines = usableTextLines(suggestions.textLines)
        let nameLine = lines.first

        let (title, usedNameLine) = makeTitle(label: label, nameLine: nameLine)

        // Remaining printed text can be quoted, but not the line already used in the title.
        let quoted = lines.filter { $0 != (usedNameLine ?? "") }.prefix(maxQuotedLines)

        var sentences: [String] = []
        let subject = title ?? suggestions.category.displayName
        if title != nil || suggestions.category != .other {
            sentences.append("\(subject) in \(conditionPhrase(condition)).")
        }
        switch mode {
        case .donate: sentences.append("Free to a good home.")
        case .exchange: sentences.append("Happy to exchange it.")
        case .sell: break
        }
        if !quoted.isEmpty {
            let listed = quoted.map { "“\($0)”" }.joined(separator: ", ")
            sentences.append("Text on the item: \(listed).")
        }

        var description = sentences.joined(separator: " ")
        if description.count > maxDescriptionLength {
            description = String(description.prefix(maxDescriptionLength))
        }
        // A description with nothing but the condition tells a reader nothing, so only offer
        // one when the photo gave something to say.
        let hasSubstance = title != nil || !quoted.isEmpty || suggestions.category != .other

        return AutofillDraft(
            title: title,
            description: hasSubstance && !description.isEmpty ? description : nil,
            category: suggestions.category == .other ? nil : suggestions.category
        )
    }

    // MARK: - Title

    /// The title, and the printed-text line it used (if any).
    private static func makeTitle(label: String?, nameLine: String?) -> (String?, String?) {
        switch (label, nameLine) {
        case (nil, nil):
            return (nil, nil)
        case (let label?, nil):
            return (clip(label), nil)
        case (nil, let name?):
            return (clip(name), name)
        case (let label?, let name?):
            // Printed text that already names the item stands alone ("Samsung laptop");
            // otherwise it reads as a brand or title in front of the item type.
            if name.lowercased().contains(label.lowercased()) { return (clip(name), name) }
            let combined = "\(name) \(label.lowercased())"
            if combined.count <= maxTitleLength { return (combined, name) }
            return (clip(label), nil)
        }
    }

    private static func clip(_ text: String) -> String {
        String(text.prefix(maxTitleLength))
    }

    // MARK: - Friendly names

    /// ImageNet names are written for researchers ("book jacket", "cellular telephone");
    /// listings read better with the everyday word.
    private static let friendlyNames: [String: String] = [
        "book jacket": "Book",
        "comic book": "Comic book",
        "notebook": "Laptop",
        "cellular telephone": "Mobile phone",
        "studio couch": "Sofa",
        "loudspeaker": "Speaker",
        "jean": "Jeans",
        "jersey": "T-shirt",
        "running shoe": "Running shoes",
        "sunglass": "Sunglasses",
        "mouse": "Computer mouse",
        "computer keyboard": "Keyboard",
        "washer": "Washing machine",
        "teddy": "Teddy bear",
        "soccer ball": "Football",
        "table lamp": "Table lamp",
        "coffeepot": "Coffee pot",
        "dining table": "Dining table",
        "pool table": "Pool table",
    ]

    static func friendlyName(for label: String) -> String {
        friendlyNames[label.lowercased()] ?? label
    }

    // MARK: - Condition wording

    static func conditionPhrase(_ condition: ItemCondition) -> String {
        switch condition {
        case .new: "brand-new condition"
        case .likeNew: "like-new condition"
        case .good: "good condition"
        case .fair: "fair condition"
        }
    }

    // MARK: - Printed text

    /// Lines that could plausibly name an item: cleaned up, deduplicated, and free of things
    /// that shouldn't be copied into a public listing (phone numbers, emails, web addresses,
    /// prices) or that are clearly not names (mostly digits, far too long).
    static func usableTextLines(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in lines {
            let line = tidy(raw)
            let letters = line.filter { $0.isLetter }.count
            let digits = line.filter { $0.isNumber }.count
            guard letters >= 3, digits <= letters, line.count <= maxNameLineLength else { continue }
            guard !looksLikeContactOrPrice(line) else { continue }
            guard seen.insert(line.lowercased()).inserted else { continue }
            result.append(line)
        }
        return result
    }

    /// Trims stray punctuation and spaces, and turns SHOUTING into "Shouting".
    private static func tidy(_ text: String) -> String {
        let edges = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:-–—_|*"))
        var line = text.trimmingCharacters(in: edges)
        line = line.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let hasLowercase = line.contains { $0.isLowercase }
        if !hasLowercase { line = line.lowercased().capitalized }
        return line
    }

    private static func looksLikeContactOrPrice(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("@") || lower.contains("http") || lower.contains("www.") || lower.contains(".com") {
            return true
        }
        if line.contains("₹") || line.contains("$") || line.contains("€") || line.contains("%") { return true }
        // Whole words only, so "Mirrors" isn't mistaken for "rs".
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        if !words.isDisjoint(with: ["mrp", "price", "rs", "inr", "call", "whatsapp", "contact"]) { return true }
        // A run of 7 or more digits (allowing spaces and dashes) is a phone number.
        let digits = line.filter { $0.isNumber }.count
        return digits >= 7
    }
}
