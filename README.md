# RT-Whisper: Real-Time Speech Transcription CLI

A macOS command-line tool for real-time speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Features automatic cleanup of filler words and repetitions for cleaner output.

## Features

- **Real-time transcription** - Captures audio from your microphone and transcribes as you speak
- **Text cleanup pipeline** - Automatically removes filler words ("um", "uh", "like", etc.) and stutters/repetitions
- **Configurable models** - Choose from tiny to large-v3 Whisper models based on your accuracy/speed needs
- **Multi-language support** - Transcribe in English, Spanish, French, and 90+ other languages
- **Clipboard integration** - Optionally copy each transcription directly to your clipboard
- **Timestamped output** - Each transcription shows elapsed time for easy reference

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3) recommended for best performance
- Xcode Command Line Tools or Xcode
- Microphone access permission

## Installation

### Build from source

```bash
git clone https://github.com/januxprobe/rt-whisper-transcription.git
cd rt-whisper-transcription
swift build -c release
```

The built binary will be at `.build/release/RTWhisperCLI`.

### Optional: Install to PATH

```bash
cp .build/release/RTWhisperCLI /usr/local/bin/rt-whisper
```

## Usage

```bash
# Basic usage with default settings (large-v3 model, English)
swift run RTWhisperCLI

# Or if installed to PATH
rt-whisper
```

### Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--raw` | `false` | Show raw transcription without cleanup |
| `--model <name>` | `large-v3` | WhisperKit model variant |
| `--language <code>` | `en` | Language code for transcription |
| `--clipboard` | `false` | Copy each transcription to clipboard |
| `--type` | `false` | Type transcription into the currently active app (uses silence detection) |
| `--chunk-duration <secs>` | `2.0` | Audio chunk duration in seconds |

### Available Models

- `tiny`, `tiny.en` - Fastest, lower accuracy
- `base`, `base.en` - Fast, basic accuracy
- `small`, `small.en` - Balanced speed/accuracy
- `medium`, `medium.en` - Good accuracy
- `large-v3` - Best accuracy (default)
- `large-v3-turbo` - Optimized large model

Models with `.en` suffix are English-only and slightly faster for English transcription.

### Examples

```bash
# Use a smaller, faster model
rt-whisper --model small.en

# Transcribe Spanish
rt-whisper --language es

# Show raw output without filler word removal
rt-whisper --raw

# Copy transcriptions to clipboard for pasting
rt-whisper --clipboard

# Type directly into the focused application (Cursor, TextEdit, VS Code, etc.)
# Waits for pauses in speech to form complete sentences before typing
rt-whisper --type

# Combine type with other options
rt-whisper --type --model small.en --language en

# Shorter chunks for faster feedback (may reduce accuracy)
rt-whisper --chunk-duration 1.5
```

### First Run

On first run, the selected model will be downloaded from Hugging Face (~150MB for large-v3). Subsequent runs use the cached model.

You will also be prompted to grant microphone access in System Settings > Privacy & Security > Microphone.

### Accessibility Permission (for --type flag)

When using the `--type` flag to type transcriptions into the active app, you must grant accessibility permission:

1. Run `rt-whisper --type` for the first time
2. System Settings will open automatically to Privacy & Security > Accessibility
3. Enable access for your terminal app (Terminal, iTerm, etc.)
4. You may need to restart the terminal or re-run the command after granting permission

## Project Structure

```
rt-whisper-transcription/
├── Package.swift                    # SPM manifest
├── Sources/
│   ├── RTWhisperCLI/
│   │   └── main.swift              # CLI entry point
│   └── RTWhisperLib/
│       ├── RTWhisperLib.swift
│       ├── AudioCapture/
│       │   └── AudioCaptureManager.swift
│       ├── Transcription/
│       │   └── TranscriptionEngine.swift
│       ├── TextProcessing/
│       │   ├── TextCleanupPipeline.swift
│       │   ├── FillerWordRemover.swift
│       │   └── RepetitionRemover.swift
│       └── TextInjection/
│           └── TextInjector.swift
└── Tests/
    └── RTWhisperTests/
        ├── TextCleanupTests.swift
        └── TextInjectorTests.swift
```

## How It Works

1. **Audio Capture** - `AVAudioEngine` captures microphone input at 16kHz mono (optimal for Whisper)
2. **Chunking** - Audio is buffered into configurable chunks (default 2 seconds)
3. **Transcription** - WhisperKit processes each chunk using on-device CoreML models
4. **Text Cleanup** - A pipeline removes filler words and repetitions
5. **Output** - Cleaned text is displayed with timestamps (and optionally copied to clipboard)

## License

MIT
