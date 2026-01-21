import SwiftUI

/// Menu bar dropdown content view
struct MenuBarView: View {
    @Bindable var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Status section
            statusSection

            Divider()
                .padding(.vertical, 4)

            // Dictation control
            dictationButton

            Divider()
                .padding(.vertical, 4)

            // Model info
            modelSection

            Divider()
                .padding(.vertical, 4)

            // Floating toolbar toggle
            floatingToolbarToggle

            Divider()
                .padding(.vertical, 4)

            // Settings and Quit
            settingsAndQuit
        }
        .padding(.vertical, 8)
    }

    private var statusSection: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var statusColor: Color {
        if appState.isLoadingModel {
            return .orange
        } else if appState.isListening {
            return .green
        } else if appState.isModelLoaded {
            return .gray
        } else {
            return .red
        }
    }

    private var statusText: String {
        if appState.isLoadingModel {
            let percentage = Int(appState.downloadProgress * 100)
            return percentage > 0 ? "Loading model... \(percentage)%" : "Loading model..."
        } else if appState.isListening {
            return "Listening..."
        } else if appState.isModelLoaded {
            return "Ready"
        } else {
            return "Model not loaded"
        }
    }

    private var dictationButton: some View {
        Button {
            if appState.isModelLoaded {
                appState.toggleListening()
            } else {
                Task {
                    await appState.loadModel()
                }
            }
        } label: {
            HStack {
                Image(systemName: appState.isListening ? "stop.fill" : "mic.fill")
                Text(appState.isListening ? "Stop Dictation" : "Start Dictation")
                Spacer()
                hotkeyLabel
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.001)) // For hover
        .disabled(appState.isLoadingModel)
    }

    private var hotkeyLabel: some View {
        let keyCode = appState.hotkeyKeyCode == 0 ? UInt32(HotkeyManager.defaultKeyCode) : UInt32(appState.hotkeyKeyCode)
        let modifiers = appState.hotkeyModifiers == 0 ? HotkeyManager.defaultModifiers : UInt32(appState.hotkeyModifiers)
        let hotkeyString = HotkeyManager.hotkeyString(keyCode: keyCode, modifiers: modifiers)

        return Text(hotkeyString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Model:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appState.selectedModel)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()
            }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if !appState.currentTranscription.isEmpty {
                Text("Last: \(appState.currentTranscription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
    }

    private var floatingToolbarToggle: some View {
        Button {
            appState.showFloatingToolbar.toggle()
            if appState.showFloatingToolbar {
                FloatingToolbarController.shared.show(appState: appState)
            } else {
                FloatingToolbarController.shared.hide()
            }
        } label: {
            HStack {
                Image(systemName: appState.showFloatingToolbar ? "checkmark" : "")
                    .frame(width: 16)
                Text("Show Floating Toolbar")
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var settingsAndQuit: some View {
        VStack(spacing: 0) {
            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("Cmd+,")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit RT-Whisper")
                    Spacer()
                    Text("Cmd+Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
