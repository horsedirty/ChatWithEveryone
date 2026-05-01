import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        MainChatView(viewModel: viewModel)
            .frame(minWidth: 800, minHeight: 600)
            .onReceive(NotificationCenter.default.publisher(for: .createNewChatSession)) { _ in
                viewModel.createNewSession()
            }
    }
}
