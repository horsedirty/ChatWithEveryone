import SwiftUI
import Textual

struct MessageBubbleView: View {
    let message: Message
    @State private var showReasoning = false

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
                HStack(spacing: 6) {
                    Text(message.role == .user ? "你" : "AI")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !message.isStreaming, message.tokenCount > 0 {
                        Text("~\(message.tokenCount) tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }

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

                if message.hasReasoning {
                    reasoningSection
                }

                if message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 4) {
                        Circle().frame(width: 6, height: 6).opacity(0.4)
                        Circle().frame(width: 6, height: 6).opacity(0.7)
                        Circle().frame(width: 6, height: 6).opacity(1.0)
                    }
                    .foregroundColor(.accentColor)
                } else if !message.content.isEmpty {
                    markdownContent
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

    var reasoningSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showReasoning.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showReasoning ? "chevron.down" : "chevron.right")
                        .font(.caption)
                    Image(systemName: "brain")
                        .font(.caption)
                    Text("思考过程")
                        .font(.caption)
                    if let start = message.thinkingStartTime, !message.isStreaming {
                        let duration = Int(Date().timeIntervalSince(start))
                        if duration > 0 {
                            Text("(\(duration)s)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if message.isStreaming && message.content.isEmpty {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if showReasoning {
                InlineText(markdown: message.reasoningContent)
                    .textual.textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(.secondary)
            }
        }
    }

    var markdownContent: some View {
        StructuredText(markdown: message.content)
            .textual.textSelection(.enabled)
            .textual.structuredTextStyle(.default)
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
