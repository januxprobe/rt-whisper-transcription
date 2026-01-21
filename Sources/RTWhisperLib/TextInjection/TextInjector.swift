import Foundation
import ApplicationServices
import AppKit

public enum TextInjectorError: Error, LocalizedError {
    case accessibilityNotGranted
    case clipboardWriteFailed
    case keySimulationFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission not granted"
        case .clipboardWriteFailed:
            return "Failed to write to clipboard"
        case .keySimulationFailed:
            return "Failed to simulate keyboard input"
        }
    }
}

public final class TextInjector {
    public init() {}

    /// Check if accessibility permission has been granted
    public static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permission, triggering system prompt if needed
    /// Returns true if permission is already granted or was just granted
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Inject text into the currently active application by copying to clipboard and simulating Cmd+V
    public func inject(_ text: String) throws {
        // 1. Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInjectorError.clipboardWriteFailed
        }

        // Small delay to ensure clipboard is ready
        usleep(10000) // 10ms

        // 2. Simulate Cmd+V keystroke
        try simulatePaste()
    }

    private func simulatePaste() throws {
        // Create key down event for 'V' with Command modifier
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            throw TextInjectorError.keySimulationFailed
        }
        keyDownEvent.flags = .maskCommand

        // Create key up event for 'V' with Command modifier
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            throw TextInjectorError.keySimulationFailed
        }
        keyUpEvent.flags = .maskCommand

        // Post the events to the HID event system
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
}
