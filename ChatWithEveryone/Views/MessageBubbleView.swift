import SwiftUI
import Textual

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 28)
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.role == .user ? "你" : "AI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !message.images.isEmpty {
                    ForEach(message.images) { img in
                        if let data = StorageService.shared.loadImageData(at: img.localFilePath),
                           let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 256, maxHeight: 256)
                                .cornerRadius(8)
                                .padding(.bottom, 4)
                        }
                    }
                }

                if message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 4) {
                        Circle().frame(width: 6, height: 6).opacity(0.4)
                        Circle().frame(width: 6, height: 6).opacity(0.7)
                        Circle().frame(width: 6, height: 6).opacity(1.0)
                    }
                    .foregroundColor(.accentColor)
                } else {
                    InlineText(markdown: message.content)
                        .textual.textSelection(.enabled)
                        .padding(10)
                        .background(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .cornerRadius(12)
                        .contextMenu {
                            Button("拷贝") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                            }
                        }
                }
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 28)
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
