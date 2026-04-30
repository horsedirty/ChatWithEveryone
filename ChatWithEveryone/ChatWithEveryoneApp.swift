import SwiftUI

@main
struct ChatWithEveryoneApp: App {
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
    }
}

extension Notification.Name {
    static let createNewChatSession = Notification.Name("createNewChatSession")
}
