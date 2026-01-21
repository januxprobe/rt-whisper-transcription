import ArgumentParser
import Foundation
import RTWhisperLib

@main
struct RTWhisperCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rt-whisper",
        abstract: "Real-time speech transcription with automatic cleanup of filler words and repetitions.",
        version: "1.0.0"
    )

    @Flag(name: .long, help: "Show raw transcription without cleanup")
    var raw: Bool = false

    @Option(name: .long, help: "WhisperKit model variant to use (e.g., tiny, base, small, medium, large-v3)")
    var model: String = "large-v3"

    @Option(name: .long, help: "Language code for transcription (e.g., en, es, fr)")
    var language: String = "en"

    @Flag(name: .long, help: "Copy each transcription to clipboard")
    var clipboard: Bool = false

    @Flag(name: .long, help: "Type transcription into the currently active app")
    var type: Bool = false

    @Option(name: .long, help: "Audio chunk duration in seconds")
    var chunkDuration: Double = 2.0

    func run() async throws {
        // Setup signal handling for graceful shutdown
        let signalSource = setupSignalHandler()
        defer { signalSource.cancel() }

        // Validate model
        guard TranscriptionEngine.availableModels.contains(model) else {
            print("Error: Invalid model '\(model)'")
            print("Available models: \(TranscriptionEngine.availableModels.joined(separator: ", "))")
            throw ExitCode.failure
        }

        // Initialize components
        let audioCapture = AudioCaptureManager()
        audioCapture.chunkDuration = chunkDuration

        let transcriptionEngine = TranscriptionEngine(modelVariant: model, language: language)
        let cleanupPipeline = TextCleanupPipeline.defaultPipeline()

        // Request microphone permission
        print("Requesting microphone permission...")
        let hasPermission = await audioCapture.requestMicrophonePermission()
        guard hasPermission else {
            print("\u{001B}[31mError: Microphone permission denied\u{001B}[0m")
            print("Please grant access in System Settings > Privacy & Security > Microphone")
            throw ExitCode.failure
        }

        // Check accessibility permission if --type is used
        var injector: TextInjector?
        if type {
            if !TextInjector.hasAccessibilityPermission() {
                print("Requesting accessibility permission...")
                TextInjector.requestAccessibilityPermission()
                // Give user time to grant permission
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if !TextInjector.hasAccessibilityPermission() {
                    print("\u{001B}[31mError: Accessibility permission denied\u{001B}[0m")
                    print("Please grant access in System Settings > Privacy & Security > Accessibility")
                    throw ExitCode.failure
                }
            }
            injector = TextInjector()
            print("\u{001B}[32m✓\u{001B}[0m Accessibility permission granted")
        }

        // Initialize transcription engine (downloads model if needed)
        print("Loading model '\(model)'...")
        transcriptionEngine.onDownloadProgress = { progress in
            let percentage = Int(progress * 100)
            print("\rDownloading model: \(percentage)%", terminator: "")
            fflush(stdout)
            if progress >= 1.0 {
                print() // New line after download complete
            }
        }

        do {
            try await transcriptionEngine.initialize()
        } catch {
            print("\u{001B}[31mError loading model: \(error.localizedDescription)\u{001B}[0m")
            throw ExitCode.failure
        }

        print("\u{001B}[32m✓\u{001B}[0m Model loaded successfully")

        // Track session start time for timestamps
        let sessionStart = Date()

        // Setup audio chunk processing
        audioCapture.onAudioChunkReady = { [transcriptionEngine, cleanupPipeline, raw, clipboard, injector, sessionStart] samples in
            Task {
                do {
                    let result = try await transcriptionEngine.transcribe(samples: samples)

                    guard !result.text.isEmpty else { return }

                    let outputText: String
                    if raw {
                        outputText = result.text
                    } else {
                        outputText = cleanupPipeline.process(result.text)
                    }

                    // Skip if cleanup removed everything
                    guard !outputText.isEmpty else { return }

                    // Calculate timestamp
                    let elapsed = Date().timeIntervalSince(sessionStart)
                    let minutes = Int(elapsed) / 60
                    let seconds = Int(elapsed) % 60
                    let timestamp = String(format: "[%02d:%02d]", minutes, seconds)

                    // Output with timestamp
                    print("\u{001B}[90m\(timestamp)\u{001B}[0m \(outputText)")

                    // Copy to clipboard if requested
                    if clipboard {
                        copyToClipboard(outputText)
                    }

                    // Type into active app if requested
                    if let injector = injector {
                        do {
                            try injector.inject(outputText)
                        } catch {
                            print("\u{001B}[31mType injection error: \(error.localizedDescription)\u{001B}[0m")
                        }
                    }
                } catch {
                    print("\u{001B}[31mTranscription error: \(error.localizedDescription)\u{001B}[0m")
                }
            }
        }

        // Start audio capture
        do {
            try audioCapture.startCapture()
        } catch {
            print("\u{001B}[31mError starting audio capture: \(error.localizedDescription)\u{001B}[0m")
            throw ExitCode.failure
        }

        print("\u{001B}[32m🎤 Listening...\u{001B}[0m (Ctrl+C to stop)")
        if !raw {
            print("\u{001B}[90m   Filler words and repetitions will be removed\u{001B}[0m")
        }
        if type {
            print("\u{001B}[90m   Text will be typed into the active app\u{001B}[0m")
        }
        print()

        // Keep running until interrupted
        await withCheckedContinuation { continuation in
            isRunning = true
            shutdownContinuation = continuation
        }

        // Cleanup
        audioCapture.stopCapture()
        await transcriptionEngine.unload()
        print("\n\u{001B}[32m✓\u{001B}[0m Session ended")
    }
}

// MARK: - Signal Handling

private var isRunning = false
private var shutdownContinuation: CheckedContinuation<Void, Never>?

private func setupSignalHandler() -> DispatchSourceSignal {
    signal(SIGINT, SIG_IGN)
    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signalSource.setEventHandler {
        if isRunning {
            isRunning = false
            shutdownContinuation?.resume()
        }
    }
    signalSource.resume()
    return signalSource
}

// MARK: - Clipboard

private func copyToClipboard(_ text: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")

    let pipe = Pipe()
    process.standardInput = pipe

    do {
        try process.run()
        pipe.fileHandleForWriting.write(text.data(using: .utf8) ?? Data())
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
    } catch {
        // Silently fail clipboard copy
    }
}
