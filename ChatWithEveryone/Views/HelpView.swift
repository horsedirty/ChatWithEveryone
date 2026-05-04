import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("使用说明")
                .font(.songtiTimes(size: 22, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                HelpRow(shortcut: "⌘N", description: "新建对话")
                HelpRow(shortcut: "Option + Space", description: "全局唤起浮动聊天窗口")
                HelpRow(shortcut: "Enter", description: "发送消息")
                HelpRow(shortcut: "Shift + Enter", description: "消息换行")
                HelpRow(shortcut: "", description: "点击 🌐 图标可开启联网搜索，AI 将基于实时搜索结果回答")
                HelpRow(shortcut: "", description: "支持拖拽/粘贴图片到对话框，或点击 📎 图标添加文件")
                HelpRow(shortcut: "", description: "点击 🖥️ 图标可截取屏幕窗口，直接在对话中分析")
                HelpRow(shortcut: "", description: "左侧边栏可管理多个对话，右键重命名或删除")
                HelpRow(shortcut: "", description: "顶部工具栏可切换 API 服务商、模型和上下文长度")
                HelpRow(shortcut: "", description: "在设置（齿轮图标）中配置 API 提供商和密钥")
            }

            Spacer()

            Button("确定") {
                if let window = NSApp.keyWindow, window.title == "Help - ChatWithEveryone" {
                    window.close()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 420, height: 380)
        .padding()
    }
}

private struct HelpRow: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            if !shortcut.isEmpty {
                Text(shortcut)
                    .font(.songtiTimes(size: 10, weight: .medium))
                    .monospaced()
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                    .frame(minWidth: 100, alignment: .trailing)
            } else {
                Spacer().frame(width: 100)
            }
            Text(description)
                .font(.songtiTimes(size: 13))
                .foregroundColor(.primary)
        }
    }
}
