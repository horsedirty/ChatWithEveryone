import SwiftUI
import AppKit
import Combine

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingChatView>?

    @Published var isVisible = false

    private init() {}

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !isVisible else { return }
        isVisible = true

        let viewModel = ChatViewModel()
        let floatingView = FloatingChatView(viewModel: viewModel) { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: floatingView)
        self.hostingView = hostingView

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.title = "ChatWithEveryone"
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelWillClose),
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }

    func hide() {
        isVisible = false
        panel?.close()
        panel = nil
        hostingView = nil
    }

    @objc private func panelWillClose() {
        isVisible = false
        panel = nil
        hostingView = nil
    }
}
