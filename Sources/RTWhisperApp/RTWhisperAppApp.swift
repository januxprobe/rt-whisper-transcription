import SwiftUI
import AppKit

@main
struct RTWhisperApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar status item
        MenuBarExtra {
            MenuBarView(appState: appState)
                .onAppear {
                    setupAppState()
                }
        } label: {
            menuBarIcon
        }

        // Settings window
        Settings {
            SettingsView(appState: appState)
        }
    }

    private var menuBarIcon: some View {
        Group {
            if appState.isLoadingModel {
                Image(systemName: "arrow.down.circle")
                    .symbolRenderingMode(.hierarchical)
            } else if appState.isListening {
                Image(systemName: "mic.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "mic")
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private func setupAppState() {
        // Only setup once
        guard !appDelegate.didSetup else { return }
        appDelegate.didSetup = true

        // Setup global hotkey
        let keyCode = UInt32(appState.hotkeyKeyCode)
        let modifiers = UInt32(appState.hotkeyModifiers)

        let finalKeyCode = keyCode == 0 ? HotkeyManager.defaultKeyCode : keyCode
        let finalModifiers = modifiers == 0 ? HotkeyManager.defaultModifiers : modifiers

        HotkeyManager.shared.registerHotkey(keyCode: finalKeyCode, modifiers: finalModifiers) { [appState] in
            Task { @MainActor in
                appState.toggleListening()
            }
        }

        // Load model on launch
        Task {
            await appState.loadModel()
        }
    }
}

/// App delegate for additional lifecycle handling
final class AppDelegate: NSObject, NSApplicationDelegate {
    var didSetup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar app
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        HotkeyManager.shared.unregisterHotkey()
    }
}
