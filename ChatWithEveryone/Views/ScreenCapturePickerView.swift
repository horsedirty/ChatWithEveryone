import SwiftUI
import ScreenCaptureKit

struct ScreenCapturePickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择要截取的窗口")
                    .font(.songtiTimes(size: 13, weight: .semibold))
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()

            Divider()

            List(ScreenCaptureService.shared.availableWindows) { window in
                Button {
                    Task {
                        await viewModel.captureWindowAndAttach(scWindow: window.scWindow)
                        dismiss()
                    }
                } label: {
                    HStack {
                        if let appIcon = window.icon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        VStack(alignment: .leading) {
                            Text(window.title.isEmpty ? "\(window.appName) - 未命名窗口" : window.title)
                                .lineLimit(1)
                            Text(window.appName)
                                .font(.songtiTimes(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button("截取整个屏幕") {
                Task {
                    await viewModel.captureScreenAndAttach()
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .task {
            await ScreenCaptureService.shared.fetchWindows()
        }
    }
}
