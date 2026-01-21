import AVFoundation
import Foundation

/// Manages real-time audio capture from the microphone using AVAudioEngine.
/// Configured for 16kHz mono Float32 format as required by Whisper models.
public final class AudioCaptureManager {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    // Voice activity detection state
    private var isSpeaking = false
    private var silenceStartTime: Date?
    private var speechStartTime: Date?

    /// Target sample rate for Whisper models
    public static let targetSampleRate: Double = 16000

    /// Callback invoked when audio chunk is ready for processing
    public var onAudioChunkReady: (([Float]) -> Void)?

    /// Duration of audio chunks in seconds (used when VAD is disabled)
    public var chunkDuration: Double = 2.0

    /// Enable voice activity detection (silence-based chunking)
    public var useVoiceActivityDetection: Bool = false

    /// RMS threshold below which audio is considered silence (0.0 to 1.0)
    public var silenceThreshold: Float = 0.015

    /// Duration of silence required to trigger transcription (seconds)
    public var silenceDurationThreshold: Double = 0.8

    /// Maximum buffer duration before forcing transcription (seconds)
    public var maxBufferDuration: Double = 30.0

    /// Minimum speech duration required before transcription (seconds)
    public var minSpeechDuration: Double = 0.3

    /// Whether the audio engine is currently running
    public var isRecording: Bool {
        audioEngine.isRunning
    }

    public init() {}

    /// Requests microphone permission and returns the result
    public func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Starts capturing audio from the default input device
    public func startCapture() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create format for 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }

        // Install tap on input node with conversion
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Stops audio capture
    public func stopCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Flush remaining buffer
        bufferLock.lock()
        if !audioBuffer.isEmpty {
            let remainingAudio = audioBuffer
            audioBuffer.removeAll()
            bufferLock.unlock()
            onAudioChunkReady?(remainingAudio)
        } else {
            bufferLock.unlock()
        }
    }

    /// Gets and clears the current audio buffer
    public func getAndClearBuffer() -> [Float] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let buffer = audioBuffer
        audioBuffer.removeAll()
        return buffer
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        var samples: [Float]

        if let converter = converter, buffer.format.sampleRate != Self.targetSampleRate {
            // Need to convert sample rate
            let ratio = Self.targetSampleRate / buffer.format.sampleRate
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

            if error != nil {
                return
            }

            samples = Array(UnsafeBufferPointer(start: outputBuffer.floatChannelData?[0], count: Int(outputBuffer.frameLength)))
        } else {
            // Already at target sample rate
            guard let channelData = buffer.floatChannelData else { return }
            samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)

        if useVoiceActivityDetection {
            processWithVAD(samples: samples)
        } else {
            processWithFixedChunks()
        }
    }

    private func processWithFixedChunks() {
        // Check if we have enough samples for a chunk
        let samplesPerChunk = Int(Self.targetSampleRate * chunkDuration)
        if audioBuffer.count >= samplesPerChunk {
            let chunk = Array(audioBuffer.prefix(samplesPerChunk))
            audioBuffer.removeFirst(samplesPerChunk)
            bufferLock.unlock()

            onAudioChunkReady?(chunk)
        } else {
            bufferLock.unlock()
        }
    }

    private func processWithVAD(samples: [Float]) {
        let rms = calculateRMS(samples)
        let now = Date()
        let isCurrentlySpeaking = rms > silenceThreshold

        if isCurrentlySpeaking {
            // Speech detected
            if !isSpeaking {
                // Speech just started
                isSpeaking = true
                speechStartTime = now
            }
            silenceStartTime = nil
        } else {
            // Silence detected
            if isSpeaking {
                if silenceStartTime == nil {
                    // Silence just started
                    silenceStartTime = now
                } else if let silenceStart = silenceStartTime {
                    // Check if silence has persisted long enough
                    let silenceDuration = now.timeIntervalSince(silenceStart)
                    if silenceDuration >= silenceDurationThreshold {
                        // Check minimum speech duration
                        let speechDuration = speechStartTime.map { now.timeIntervalSince($0) } ?? 0
                        if speechDuration >= minSpeechDuration && !audioBuffer.isEmpty {
                            let chunk = audioBuffer
                            audioBuffer.removeAll()
                            bufferLock.unlock()

                            onAudioChunkReady?(chunk)

                            bufferLock.lock()
                        }

                        // Reset state
                        isSpeaking = false
                        silenceStartTime = nil
                        speechStartTime = nil
                    }
                }
            }
        }

        // Force transcription if buffer exceeds max duration
        let maxSamples = Int(Self.targetSampleRate * maxBufferDuration)
        if audioBuffer.count >= maxSamples {
            let chunk = audioBuffer
            audioBuffer.removeAll()
            bufferLock.unlock()

            onAudioChunkReady?(chunk)

            // Reset state
            bufferLock.lock()
            isSpeaking = false
            silenceStartTime = nil
            speechStartTime = nil
        }

        bufferLock.unlock()
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

public enum AudioCaptureError: Error, LocalizedError {
    case formatCreationFailed
    case microphonePermissionDenied

    public var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please grant access in System Settings > Privacy & Security > Microphone"
        }
    }
}
