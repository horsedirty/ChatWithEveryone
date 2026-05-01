import SwiftUI
import AppKit

@main
struct ChatWithEveryoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建对话") {
                    NotificationCenter.default.post(name: .createNewChatSession, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        MenuBarExtra {
            Button("显示主窗口") {
                showMainWindow()
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text("💬")
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if !(window is NSPanel), window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        for window in NSApp.windows {
            if !(window is NSPanel) {
                window.orderFrontRegardless()
                return
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

extension Notification.Name {
    static let createNewChatSession = Notification.Name("createNewChatSession")
}
