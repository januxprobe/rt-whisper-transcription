# RT-Whisper: Real-Time Speech Transcription

A macOS application for real-time speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Available as both a command-line tool and a native desktop app with menu bar integration. Features automatic cleanup of filler words and repetitions for cleaner output.

## Features

- **Real-time transcription** - Captures audio from your microphone and transcribes as you speak
- **Text cleanup pipeline** - Automatically removes filler words ("um", "uh", "like", etc.) and stutters/repetitions
- **Configurable models** - Choose from tiny to large-v3 Whisper models based on your accuracy/speed needs
- **Multi-language support** - Transcribe in English, Spanish, French, and 90+ other languages
- **Direct text injection** - Types transcribed text directly into any active application
- **Timestamped output** - Each transcription shows elapsed time for easy reference (CLI)

### Desktop App Features

- **Menu bar integration** - Always-accessible microphone icon with status indication
- **Floating toolbar** - Optional draggable window that stays on top of all apps
- **Global hotkey** - Toggle dictation with Cmd+Shift+D from anywhere (customizable)
- **Settings UI** - Easy configuration of models, language, and preferences

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3) recommended for best performance
- Xcode Command Line Tools or Xcode
- Microphone access permission
- Accessibility permission (for text injection)

## Installation

### Build from source

```bash
git clone https://github.com/januxprobe/rt-whisper-transcription.git
cd rt-whisper-transcription
swift build -c release
```

The built binaries will be at:
- CLI: `.build/release/RTWhisperCLI`
- Desktop App: `.build/release/RTWhisperApp`

### Optional: Install CLI to PATH

```bash
cp .build/release/RTWhisperCLI /usr/local/bin/rt-whisper
```

## Desktop App Usage

### Running the App

```bash
swift run RTWhisperApp
```

The app runs as a menu bar application (no dock icon). Look for the microphone icon in your menu bar.

### Menu Bar

- **Microphone icon** shows current state:
  - Gray: Idle/Ready
  - Green: Listening
  - Downloading icon: Loading model
- **Click** to open the dropdown menu with controls

### Global Hotkey

Press **Cmd+Shift+D** from any application to toggle dictation on/off. The hotkey can be customized in Settings.

### Floating Toolbar

Enable the floating toolbar from the menu bar dropdown. It provides:
- Quick record button
- Status indicator
- Settings access
- Drag to reposition (position is saved)

### Settings

Access via menu bar → Settings, or press **Cmd+,**

- **General**: Toggle floating toolbar, enable raw mode (skip text cleanup)
- **Model**: Select Whisper model variant, view loading status
- **Hotkey**: Customize the global keyboard shortcut
- **Permissions**: Check and request microphone/accessibility access

## CLI Usage

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

### CLI Examples

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

## Available Models

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| `tiny`, `tiny.en` | 39M | Fastest | Lower | Quick dictation |
| `base`, `base.en` | 74M | Fast | Basic | Casual use |
| `small`, `small.en` | 244M | Balanced | Good | Daily use |
| `medium`, `medium.en` | 769M | Moderate | High | Quality transcription |
| `large-v2` | 1.5G | Slower | Highest | Maximum accuracy |
| `large-v3` | 1.5G | Slower | Highest | Maximum accuracy (default) |
| `large-v3-turbo` | 1.5G | Faster | High | Optimized large model |

Models with `.en` suffix are English-only and slightly faster for English transcription.

## First Run

On first run, the selected model will be downloaded from Hugging Face (~150MB for large-v3). Subsequent runs use the cached model.

You will be prompted to grant:
1. **Microphone access** - System Settings > Privacy & Security > Microphone
2. **Accessibility access** - System Settings > Privacy & Security > Accessibility (for text injection)

## Project Structure

```
rt-whisper-transcription/
├── Package.swift                    # SPM manifest
├── Sources/
│   ├── RTWhisperCLI/
│   │   └── main.swift              # CLI entry point
│   ├── RTWhisperApp/               # macOS desktop app
│   │   ├── RTWhisperAppApp.swift   # App entry, menu bar setup
│   │   ├── AppState.swift          # Observable state manager
│   │   ├── Views/
│   │   │   ├── MenuBarView.swift   # Menu bar dropdown
│   │   │   ├── FloatingToolbar.swift # Floating window
│   │   │   └── SettingsView.swift  # Settings window
│   │   └── Utilities/
│   │       └── HotkeyManager.swift # Global hotkey
│   └── RTWhisperLib/               # Shared library
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
2. **Voice Activity Detection** - Silence detection waits for speech pauses before transcribing
3. **Transcription** - WhisperKit processes audio using on-device CoreML models
4. **Text Cleanup** - A pipeline removes filler words and repetitions
5. **Text Injection** - Transcribed text is typed into the active application via accessibility APIs

## License

MIT
