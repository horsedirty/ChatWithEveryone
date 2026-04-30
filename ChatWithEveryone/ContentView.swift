import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        MainChatView(viewModel: viewModel)
            .frame(minWidth: 800, minHeight: 600)
            .onReceive(NotificationCenter.default.publisher(for: .createNewChatSession)) { _ in
                viewModel.createNewSession()
            }
    }
}

#Preview {
    ContentView()
}
