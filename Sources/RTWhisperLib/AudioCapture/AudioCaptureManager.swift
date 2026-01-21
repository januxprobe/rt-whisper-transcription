import AVFoundation
import Foundation

/// Manages real-time audio capture from the microphone using AVAudioEngine.
/// Configured for 16kHz mono Float32 format as required by Whisper models.
public final class AudioCaptureManager {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    /// Target sample rate for Whisper models
    public static let targetSampleRate: Double = 16000

    /// Callback invoked when audio chunk is ready for processing
    public var onAudioChunkReady: (([Float]) -> Void)?

    /// Duration of audio chunks in seconds
    public var chunkDuration: Double = 2.0

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
