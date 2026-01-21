import Foundation
import WhisperKit

/// Manages WhisperKit-based transcription of audio samples.
public final class TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private let modelVariant: String
    private let language: String

    /// Available model variants in order of size/accuracy
    public static let availableModels = [
        "tiny",
        "tiny.en",
        "base",
        "base.en",
        "small",
        "small.en",
        "medium",
        "medium.en",
        "large-v2",
        "large-v3",
        "large-v3-turbo"
    ]

    /// Progress callback for model download
    public var onDownloadProgress: ((Double) -> Void)?

    /// Whether the engine is ready for transcription
    public var isReady: Bool {
        whisperKit != nil
    }

    public init(modelVariant: String = "large-v3", language: String = "en") {
        self.modelVariant = modelVariant
        self.language = language
    }

    /// Initializes and loads the WhisperKit model
    public func initialize() async throws {
        // Download model with progress reporting
        let modelURL = try await WhisperKit.download(
            variant: modelVariant,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { [weak self] progress in
                self?.onDownloadProgress?(progress.fractionCompleted)
            }
        )

        // Initialize WhisperKit with downloaded model
        let config = WhisperKitConfig(
            modelFolder: modelURL.path,
            load: true,
            download: false
        )
        whisperKit = try await WhisperKit(config)
    }

    /// Transcribes audio samples and returns the text result
    /// - Parameter samples: Audio samples at 16kHz mono Float32
    /// - Returns: Transcribed text
    public func transcribe(samples: [Float]) async throws -> TranscriptionResult {
        guard let pipe = whisperKit else {
            throw TranscriptionError.notInitialized
        }

        let options = DecodingOptions(
            language: language,
            temperature: 0.0,
            wordTimestamps: false,
            suppressBlank: true
        )

        let results = try await pipe.transcribe(
            audioArray: samples,
            decodeOptions: options
        )

        guard let result = results.first else {
            return TranscriptionResult(text: "", segments: [])
        }

        let segments = result.segments.map { segment in
            TranscriptionSegment(
                text: segment.text,
                start: segment.start,
                end: segment.end
            )
        }

        return TranscriptionResult(
            text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments
        )
    }

    /// Unloads models to free memory
    public func unload() async {
        await whisperKit?.unloadModels()
        whisperKit = nil
    }
}

/// Result of a transcription operation
public struct TranscriptionResult {
    public let text: String
    public let segments: [TranscriptionSegment]

    public init(text: String, segments: [TranscriptionSegment]) {
        self.text = text
        self.segments = segments
    }
}

/// A segment of transcribed audio with timing information
public struct TranscriptionSegment {
    public let text: String
    public let start: Float
    public let end: Float

    public init(text: String, start: Float, end: Float) {
        self.text = text
        self.start = start
        self.end = end
    }
}

public enum TranscriptionError: Error, LocalizedError {
    case notInitialized
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Transcription engine not initialized. Call initialize() first."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
