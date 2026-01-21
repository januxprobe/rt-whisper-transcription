import Foundation
import SwiftUI
import RTWhisperLib

/// Observable state manager for the RTWhisper macOS app.
/// Manages transcription state, audio capture, and user preferences.
@Observable
final class AppState {
    // MARK: - Transcription State

    var isListening: Bool = false
    var currentTranscription: String = ""
    var isModelLoaded: Bool = false
    var downloadProgress: Double = 0.0
    var isLoadingModel: Bool = false
    var errorMessage: String?

    // MARK: - UI State

    var showFloatingToolbar: Bool {
        get { UserDefaults.standard.bool(forKey: "showFloatingToolbar") }
        set { UserDefaults.standard.set(newValue, forKey: "showFloatingToolbar") }
    }

    // MARK: - Settings

    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: "selectedModel") ?? "large-v3" }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
            // Model change requires reload
            if isModelLoaded {
                Task { await reloadModel() }
            }
        }
    }

    var selectedLanguage: String {
        get { UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en" }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedLanguage")
            // Update language on existing engine (no reload needed)
            transcriptionEngine?.language = newValue
        }
    }

    var useRawMode: Bool {
        get { UserDefaults.standard.bool(forKey: "useRawMode") }
        set { UserDefaults.standard.set(newValue, forKey: "useRawMode") }
    }

    var hotkeyModifiers: UInt {
        get { UInt(UserDefaults.standard.integer(forKey: "hotkeyModifiers")) }
        set { UserDefaults.standard.set(newValue, forKey: "hotkeyModifiers") }
    }

    var hotkeyKeyCode: UInt16 {
        get { UInt16(UserDefaults.standard.integer(forKey: "hotkeyKeyCode")) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    // MARK: - Components

    private var audioCapture: AudioCaptureManager?
    private var transcriptionEngine: TranscriptionEngine?
    private var textInjector: TextInjector?
    private var cleanupPipeline: TextCleanupPipeline?

    // MARK: - Initialization

    init() {
        // Set default hotkey if not set (Cmd+Shift+D)
        if UserDefaults.standard.object(forKey: "hotkeyKeyCode") == nil {
            hotkeyKeyCode = 0x02 // 'D' key
            hotkeyModifiers = UInt(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)
        }
    }

    // MARK: - Model Management

    /// Loads the transcription model
    @MainActor
    func loadModel() async {
        guard !isModelLoaded && !isLoadingModel else { return }

        isLoadingModel = true
        downloadProgress = 0.0
        errorMessage = nil

        do {
            let engine = TranscriptionEngine(modelVariant: selectedModel, language: selectedLanguage)
            engine.onDownloadProgress = { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }

            try await engine.initialize()
            transcriptionEngine = engine
            cleanupPipeline = TextCleanupPipeline.defaultPipeline()
            textInjector = TextInjector()
            isModelLoaded = true
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }

        isLoadingModel = false
    }

    /// Reloads the model with current settings
    @MainActor
    func reloadModel() async {
        if isListening {
            stopListening()
        }

        await transcriptionEngine?.unload()
        transcriptionEngine = nil
        isModelLoaded = false

        await loadModel()
    }

    // MARK: - Audio Capture Control

    /// Starts audio capture and transcription
    @MainActor
    func startListening() {
        guard isModelLoaded, !isListening else { return }

        // Request accessibility permission for text injection
        if !TextInjector.hasAccessibilityPermission() {
            TextInjector.requestAccessibilityPermission()
        }

        do {
            let capture = AudioCaptureManager()
            capture.useVoiceActivityDetection = true

            capture.onAudioChunkReady = { [weak self] samples in
                Task { @MainActor in
                    await self?.processAudioChunk(samples)
                }
            }

            try capture.startCapture()
            audioCapture = capture
            isListening = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start capture: \(error.localizedDescription)"
        }
    }

    /// Stops audio capture
    @MainActor
    func stopListening() {
        audioCapture?.stopCapture()
        audioCapture = nil
        isListening = false
    }

    /// Toggles listening state
    @MainActor
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    // MARK: - Transcription

    private func processAudioChunk(_ samples: [Float]) async {
        guard let engine = transcriptionEngine else { return }

        do {
            let result = try await engine.transcribe(samples: samples)

            guard !result.text.isEmpty else { return }

            var outputText = result.text

            // Apply cleanup unless raw mode is enabled
            if !useRawMode, let pipeline = cleanupPipeline {
                outputText = pipeline.process(outputText)
            }

            guard !outputText.isEmpty else { return }

            currentTranscription = outputText

            // Inject text into active app
            if let injector = textInjector {
                do {
                    try injector.inject(" " + outputText)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Text injection failed: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Permissions

    /// Requests microphone permission
    func requestMicrophonePermission() async -> Bool {
        let capture = AudioCaptureManager()
        return await capture.requestMicrophonePermission()
    }

    /// Checks if accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        TextInjector.hasAccessibilityPermission()
    }

    /// Requests accessibility permission
    func requestAccessibilityPermission() {
        TextInjector.requestAccessibilityPermission()
    }

    // MARK: - Available Options

    static let availableModels = TranscriptionEngine.availableModels

    static let availableLanguages = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese")
    ]
}
