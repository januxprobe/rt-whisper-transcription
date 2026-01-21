import Foundation

/// Removes stutters and repeated words/phrases from transcribed text.
public struct RepetitionRemover: TextProcessor {
    public init() {}

    public func process(_ text: String) -> String {
        var result = text

        // Remove word stutters: "I I I went" -> "I went", "the the" -> "the"
        // Match word repeated 2+ times (case-insensitive)
        let stutterPattern = "\\b(\\w+)(\\s+\\1)+\\b"
        if let regex = try? NSRegularExpression(pattern: stutterPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove repeated short phrases (2-3 words repeated)
        // "I went to I went to the store" -> "I went to the store"
        let phrasePattern = "\\b((?:\\w+\\s+){1,3})(\\1)+"
        if let regex = try? NSRegularExpression(pattern: phrasePattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove false starts with dashes: "I went- I went to the store"
        let falseStartPattern = "\\b(\\w+)-\\s*\\1\\b"
        if let regex = try? NSRegularExpression(pattern: falseStartPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Clean up multiple spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}
