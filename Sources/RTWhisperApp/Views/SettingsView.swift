import SwiftUI

/// Settings window view
struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsView(appState: appState)
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            HotkeySettingsView(appState: appState)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }

            PermissionsView(appState: appState)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @State private var selectedLanguage: String

    init(appState: AppState) {
        self.appState = appState
        self._selectedLanguage = State(initialValue: appState.selectedLanguage)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show floating toolbar", isOn: Binding(
                    get: { appState.showFloatingToolbar },
                    set: { newValue in
                        appState.showFloatingToolbar = newValue
                        if newValue {
                            FloatingToolbarController.shared.show(appState: appState)
                        } else {
                            FloatingToolbarController.shared.hide()
                        }
                    }
                ))

                Toggle("Raw mode (skip text cleanup)", isOn: Binding(
                    get: { appState.useRawMode },
                    set: { appState.useRawMode = $0 }
                ))
            } header: {
                Text("Interface")
            }

            Section {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(AppState.availableLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    appState.selectedLanguage = newValue
                }
            } header: {
                Text("Transcription")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: Binding(
                    get: { appState.selectedModel },
                    set: { appState.selectedModel = $0 }
                )) {
                    ForEach(AppState.availableModels, id: \.self) { model in
                        Text(modelDisplayName(model)).tag(model)
                    }
                }
                .pickerStyle(.menu)

                Text(modelDescription(appState.selectedModel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Whisper Model")
            }

            Section {
                HStack {
                    Text("Status:")
                    Spacer()
                    if appState.isLoadingModel {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("\(Int(appState.downloadProgress * 100))%")
                        }
                    } else if appState.isModelLoaded {
                        Label("Loaded", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not loaded", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if !appState.isLoadingModel {
                    Button(appState.isModelLoaded ? "Reload Model" : "Load Model") {
                        Task {
                            await appState.reloadModel()
                        }
                    }
                }
            } header: {
                Text("Model Status")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "tiny": return "Tiny (39M)"
        case "tiny.en": return "Tiny English (39M)"
        case "base": return "Base (74M)"
        case "base.en": return "Base English (74M)"
        case "small": return "Small (244M)"
        case "small.en": return "Small English (244M)"
        case "medium": return "Medium (769M)"
        case "medium.en": return "Medium English (769M)"
        case "large-v2": return "Large v2 (1.5G)"
        case "large-v3": return "Large v3 (1.5G)"
        case "large-v3-turbo": return "Large v3 Turbo (1.5G)"
        default: return model
        }
    }

    private func modelDescription(_ model: String) -> String {
        if model.contains("tiny") {
            return "Fastest, lowest accuracy. Good for quick dictation."
        } else if model.contains("base") {
            return "Fast with reasonable accuracy."
        } else if model.contains("small") {
            return "Good balance of speed and accuracy."
        } else if model.contains("medium") {
            return "High accuracy, moderate speed."
        } else if model.contains("large") {
            return "Highest accuracy, slower processing."
        }
        return ""
    }
}

// MARK: - Hotkey Settings

struct HotkeySettingsView: View {
    @Bindable var appState: AppState
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt32 = 0
    @State private var recordedModifiers: UInt32 = 0

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle Dictation:")

                    Spacer()

                    Button {
                        isRecording = true
                    } label: {
                        if isRecording {
                            Text("Press keys...")
                                .foregroundStyle(.orange)
                        } else {
                            Text(currentHotkeyString)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if isRecording {
                    HotkeyRecorderView(
                        isRecording: $isRecording,
                        onRecorded: { keyCode, modifiers in
                            appState.hotkeyKeyCode = UInt16(keyCode)
                            appState.hotkeyModifiers = UInt(modifiers)

                            // Re-register the hotkey
                            HotkeyManager.shared.registerHotkey(
                                keyCode: keyCode,
                                modifiers: modifiers
                            ) {
                                Task { @MainActor in
                                    appState.toggleListening()
                                }
                            }
                        }
                    )
                    .frame(height: 0)
                }

                Button("Reset to Default (Cmd+Shift+D)") {
                    appState.hotkeyKeyCode = UInt16(HotkeyManager.defaultKeyCode)
                    appState.hotkeyModifiers = UInt(HotkeyManager.defaultModifiers)

                    HotkeyManager.shared.registerHotkey { [appState] in
                        Task { @MainActor in
                            appState.toggleListening()
                        }
                    }
                }
            } header: {
                Text("Global Hotkey")
            } footer: {
                Text("Press the hotkey from any application to toggle dictation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var currentHotkeyString: String {
        let keyCode = appState.hotkeyKeyCode == 0 ? UInt32(HotkeyManager.defaultKeyCode) : UInt32(appState.hotkeyKeyCode)
        let modifiers = appState.hotkeyModifiers == 0 ? HotkeyManager.defaultModifiers : UInt32(appState.hotkeyModifiers)
        return HotkeyManager.hotkeyString(keyCode: keyCode, modifiers: modifiers)
    }
}

/// View that captures keyboard input for hotkey recording
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecorded: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKeyPress = { keyCode, modifiers in
            onRecorded(keyCode, modifiers)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var onKeyPress: ((UInt32, UInt32) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .shift, .option, .control]) != [] else {
            // Require at least one modifier
            NSSound.beep()
            return
        }

        let carbonModifiers = HotkeyManager.carbonModifiers(from: event.modifierFlags)
        onKeyPress?(UInt32(event.keyCode), carbonModifiers)
    }
}

// MARK: - Permissions

struct PermissionsView: View {
    @Bindable var appState: AppState
    @State private var hasMicPermission = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Microphone", systemImage: "mic.fill")
                    Spacer()
                    if hasMicPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Request") {
                            Task {
                                hasMicPermission = await appState.requestMicrophonePermission()
                            }
                        }
                    }
                }

                HStack {
                    Label("Accessibility", systemImage: "accessibility")
                    Spacer()
                    if appState.hasAccessibilityPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Request") {
                            appState.requestAccessibilityPermission()
                        }
                    }
                }
            } header: {
                Text("Required Permissions")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Microphone: Required for audio capture")
                    Text("Accessibility: Required for typing text into apps")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            Task {
                hasMicPermission = await appState.requestMicrophonePermission()
            }
        }
    }
}
