import Foundation

/// Removes filler words and verbal tics from transcribed text.
public struct FillerWordRemover: TextProcessor {
    /// Filler words to remove (case-insensitive)
    public static let fillerWords: Set<String> = [
        // Hesitation sounds
        "um", "uh", "uhh", "umm", "er", "err", "ah", "ahh", "hmm", "hm",
        // Common fillers
        "like", "basically", "actually", "literally", "honestly", "obviously",
        // Phrases
        "you know", "i mean", "sort of", "kind of", "you see",
        "let me think", "how do i say this", "how should i put this",
        // Connector fillers
        "right", "so", "well", "anyway", "anyways"
    ]

    /// Single-word fillers for word-boundary matching
    private static let singleWordFillers: Set<String> = [
        "um", "uh", "uhh", "umm", "er", "err", "ah", "ahh", "hmm", "hm",
        "like", "basically", "actually", "literally", "honestly", "obviously",
        "right", "so", "well", "anyway", "anyways"
    ]

    /// Multi-word phrases to remove
    private static let phraseFillers: [String] = [
        "you know",
        "i mean",
        "sort of",
        "kind of",
        "you see",
        "let me think",
        "how do i say this",
        "how should i put this"
    ]

    public init() {}

    public func process(_ text: String) -> String {
        var result = text

        // First, remove multi-word phrases (case-insensitive)
        for phrase in Self.phraseFillers {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Then, remove single-word fillers at word boundaries
        for filler in Self.singleWordFillers {
            // Match filler at word boundaries, optionally followed by comma
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,?\\s*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Clean up multiple spaces and trim
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fix punctuation spacing
        result = result.replacingOccurrences(of: "\\s+([.,!?])", with: "$1", options: .regularExpression)

        // Capitalize first letter if needed
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + String(result.dropFirst())
        }

        return result
    }
}
