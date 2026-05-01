import SwiftUI
import AppKit

@main
struct ChatWithEveryoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("显示主窗口") {
                DispatchQueue.main.async { [appDelegate] in
                    appDelegate.showMainWindow()
                }
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text("💬")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private var mainViewModel: ChatViewModel?
    private var aboutWindow: NSWindow?
    private var helpWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
        setupHotKey()
        setupMenuCommands()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    static func showMainWindow() {
        (NSApp.delegate as? AppDelegate)?.showMainWindow()
    }

    func showMainWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        if mainWindow == nil {
            createMainWindow()
        } else {
            mainWindow?.orderFrontRegardless()
            mainWindow?.makeKey()
        }
    }

    private func createMainWindow() {
        let viewModel = ChatViewModel()
        self.mainViewModel = viewModel

        let contentView = ContentView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ChatWithEveryone"
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 800, height: 600)
        window.setFrameAutosaveName("MainWindow")
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.mainWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - HotKey

    private func setupHotKey() {
        HotKeyManager.shared.onHotKeyPressed = {
            DispatchQueue.main.async {
                FloatingPanelController.shared.toggle()
            }
        }
        HotKeyManager.shared.register()
    }

    // MARK: - Menu Commands

    private func setupMenuCommands() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // App menu: About + Show Main Window + Help + separator
        if let appMenu = mainMenu.item(at: 0)?.submenu {
            let aboutItem = NSMenuItem(
                title: "About ChatWithEveryone",
                action: #selector(showAboutWindow),
                keyEquivalent: ""
            )
            appMenu.insertItem(aboutItem, at: 0)

            let showItem = NSMenuItem(
                title: "显示主窗口",
                action: #selector(showMainWindowFromMenu),
                keyEquivalent: "0"
            )
            showItem.keyEquivalentModifierMask = .command
            appMenu.insertItem(showItem, at: 1)

            let helpItem = NSMenuItem(
                title: "使用说明",
                action: #selector(showHelpWindow),
                keyEquivalent: ""
            )
            appMenu.insertItem(helpItem, at: 2)

            appMenu.insertItem(.separator(), at: 3)
        }

        // File menu: 新建对话
        if let fileMenu = mainMenu.item(withTitle: "File")?.submenu {
            let newItem = NSMenuItem(
                title: "新建对话",
                action: #selector(newChatSession),
                keyEquivalent: "n"
            )
            newItem.keyEquivalentModifierMask = .command
            fileMenu.insertItem(newItem, at: 0)
        }
    }

    @objc private func showMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func showAboutWindow() {
        if aboutWindow == nil {
            let hostingView = NSHostingView(rootView: AboutView())

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About ChatWithEveryone"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            aboutWindow = window
        }
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showHelpWindow() {
        if helpWindow == nil {
            let hostingView = NSHostingView(rootView: HelpView())

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Help - ChatWithEveryone"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            helpWindow = window
        }
        helpWindow?.center()
        helpWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func newChatSession() {
        mainViewModel?.createNewSession()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let createNewChatSession = Notification.Name("createNewChatSession")
}
