import Foundation

/// Protocol for text processors in the cleanup pipeline.
public protocol TextProcessor {
    func process(_ text: String) -> String
}

/// Orchestrates multiple text processors to clean up transcribed text.
public final class TextCleanupPipeline {
    private var processors: [TextProcessor] = []

    public init() {}

    /// Creates a pipeline with the default set of processors.
    public static func defaultPipeline() -> TextCleanupPipeline {
        let pipeline = TextCleanupPipeline()
        pipeline.addProcessor(RepetitionRemover())
        pipeline.addProcessor(FillerWordRemover())
        return pipeline
    }

    /// Adds a processor to the pipeline.
    public func addProcessor(_ processor: TextProcessor) {
        processors.append(processor)
    }

    /// Processes text through all processors in order.
    public func process(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text
        for processor in processors {
            result = processor.process(result)
        }

        // Final cleanup pass
        result = finalCleanup(result)

        return result
    }

    private func finalCleanup(_ text: String) -> String {
        var result = text

        // Remove multiple spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure proper capitalization at sentence start
        result = capitalizeSentences(result)

        // Remove leading/trailing punctuation artifacts
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = ""
        var capitalizeNext = true

        for char in text {
            if capitalizeNext && char.isLetter {
                result.append(char.uppercased())
                capitalizeNext = false
            } else {
                result.append(char)
                if char == "." || char == "!" || char == "?" {
                    capitalizeNext = true
                }
            }
        }

        return result
    }
}
