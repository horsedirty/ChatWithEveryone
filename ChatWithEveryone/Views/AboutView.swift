import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("ChatWithEveryone")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("一个简洁的 AI 聊天客户端，\n支持多模型切换、联网搜索、图片生成和屏幕截图对话。")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button("确定") {
                if let window = NSApp.keyWindow, window.title == "About ChatWithEveryone" {
                    window.close()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)

            Spacer().frame(height: 8)
        }
        .frame(minWidth: 300, minHeight: 240)
        .padding()
    }
}
