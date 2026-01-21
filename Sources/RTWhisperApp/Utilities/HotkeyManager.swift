import Foundation
import Carbon
import AppKit

/// Manages global hotkey registration using Carbon APIs.
/// Default hotkey is Cmd+Shift+D for toggling dictation.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    // Key code for 'D' key
    static let defaultKeyCode: UInt32 = 0x02

    // Default modifiers: Cmd + Shift
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private init() {}

    deinit {
        unregisterHotkey()
    }

    /// Registers a global hotkey with the specified key code and modifiers.
    /// - Parameters:
    ///   - keyCode: The virtual key code (e.g., 0x02 for 'D')
    ///   - modifiers: Carbon modifier flags (cmdKey, shiftKey, etc.)
    ///   - action: The closure to execute when the hotkey is pressed
    func registerHotkey(keyCode: UInt32 = defaultKeyCode, modifiers: UInt32 = defaultModifiers, action: @escaping () -> Void) {
        unregisterHotkey()

        self.action = action

        // Create hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x52545748) // "RTWH" in hex
        hotKeyID.id = 1

        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            print("Failed to register hotkey: \(status)")
            return
        }

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if handlerStatus != noErr {
            print("Failed to install event handler: \(handlerStatus)")
        }
    }

    /// Unregisters the current hotkey
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.action?()
        }
    }

    /// Converts SwiftUI/AppKit modifier flags to Carbon modifiers
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0

        if flags.contains(.command) {
            carbonMods |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            carbonMods |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            carbonMods |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonMods |= UInt32(controlKey)
        }

        return carbonMods
    }

    /// Converts Carbon modifiers to NSEvent.ModifierFlags for display
    static func modifierFlags(from carbonMods: UInt32) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()

        if carbonMods & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonMods & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        if carbonMods & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonMods & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }

        return flags
    }

    /// Returns a human-readable string for a key code
    static func keyString(for keyCode: UInt32) -> String {
        let keyCodeToString: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x31: " ", 0x32: "`",
            0x24: "Return", 0x30: "Tab", 0x33: "Delete",
            0x35: "Escape", 0x7A: "F1", 0x78: "F2", 0x63: "F3",
            0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
            0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12"
        ]

        return keyCodeToString[keyCode] ?? "Key \(keyCode)"
    }

    /// Returns a formatted hotkey string (e.g., "Cmd+Shift+D")
    static func hotkeyString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Ctrl")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Opt")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Cmd")
        }

        parts.append(keyString(for: keyCode))

        return parts.joined(separator: "+")
    }
}
