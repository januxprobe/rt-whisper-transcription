import SwiftUI
import AppKit

/// Controller for the floating toolbar window
final class FloatingToolbarController {
    static let shared = FloatingToolbarController()

    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<FloatingToolbarView>?

    private init() {}

    func show(appState: AppState) {
        if panel == nil {
            createPanel(appState: appState)
        }
        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle(appState: AppState) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(appState: appState)
        }
    }

    private func createPanel(appState: AppState) {
        let panel = FloatingPanel()

        let contentView = FloatingToolbarView(appState: appState) { [weak self] in
            self?.hide()
            appState.showFloatingToolbar = false
        }

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 140, height: 44)

        panel.contentView = hostingView
        panel.setContentSize(NSSize(width: 140, height: 44))

        // Restore saved position or use default
        if let savedX = UserDefaults.standard.object(forKey: "floatingToolbarX") as? CGFloat,
           let savedY = UserDefaults.standard.object(forKey: "floatingToolbarY") as? CGFloat {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else {
            // Default position: top-right corner
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.maxX - 160
                let y = screenFrame.maxY - 60
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        self.panel = panel
        self.hostingView = hostingView
    }

    func savePosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(frame.origin.x, forKey: "floatingToolbarX")
        UserDefaults.standard.set(frame.origin.y, forKey: "floatingToolbarY")
    }
}

/// Custom NSPanel that floats above all windows
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // Floating behavior
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Appearance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        // Movable
        self.isMovableByWindowBackground = true

        // Don't show in window menu
        self.hidesOnDeactivate = false
        self.isExcludedFromWindowsMenu = true
    }

    // Save position when moved
    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        FloatingToolbarController.shared.savePosition()
    }

    // Prevent becoming key window (keeps focus on other apps)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SwiftUI view for the floating toolbar content
struct FloatingToolbarView: View {
    @Bindable var appState: AppState
    var onClose: () -> Void
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            // Record button
            Button {
                if appState.isModelLoaded {
                    appState.toggleListening()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 28, height: 28)

                    Image(systemName: appState.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!appState.isModelLoaded || appState.isLoadingModel)

            // Status indicator
            if appState.isLoadingModel {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 20, height: 20)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // Settings button
            Button {
                openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var buttonColor: Color {
        if appState.isListening {
            return .red
        } else if appState.isModelLoaded {
            return .green
        } else {
            return .gray
        }
    }

    private var statusColor: Color {
        if appState.isListening {
            return .green
        } else if appState.isModelLoaded {
            return .gray
        } else {
            return .red
        }
    }
}
