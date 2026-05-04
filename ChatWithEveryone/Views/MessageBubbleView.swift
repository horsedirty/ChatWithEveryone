import SwiftUI
import Textual
import UniformTypeIdentifiers
import AppKit

struct MessageBubbleView: View {
    let message: Message
    var onRegenerate: (() -> Void)?
    var onEdit: (() -> Void)?
    var onUndo: (() -> Void)?
    @State private var showReasoning = false
    @State private var copiedCodeId: UUID?

    var body: some View {
        if message.role == .system, let results = message.searchResults, !results.isEmpty {
            searchResultsView(results: results)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .assistant {
                    Image(systemName: "brain.head.profile")
                        .font(.songtiTimes(size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                } else {
                    Spacer(minLength: 60)
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(message.role == .user ? "你" : "AI")
                            .font(.songtiTimes(size: 10))
                            .foregroundColor(.secondary)

                        if !message.isStreaming, message.tokenCount > 0 {
                            Text("~\(message.tokenCount) tokens")
                                .font(.songtiTimes(size: 9))
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
                        TypingIndicatorView()
                            .padding(10)
                    } else if !message.content.isEmpty {
                        markdownContent
                    }

                    if message.role == .assistant, !message.extractedImageURLs.isEmpty {
                        generatedImagesView
                    }

                    if !message.isStreaming, !message.content.isEmpty {
                        actionButtons
                    }
                }

                if message.role == .user {
                    Image(systemName: "person.circle.fill")
                        .font(.songtiTimes(size: 20))
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

    func searchResultsView(results: [SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.songtiTimes(size: 10))
                    .foregroundColor(.accentColor)
                Text("联网搜索结果")
                    .font(.songtiTimes(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(8)

            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                Button {
                    NSWorkspace.shared.open(result.url)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(index + 1).")
                                .font(.songtiTimes(size: 9))
                                .foregroundColor(.secondary)
                            Text(result.title)
                                .font(.songtiTimes(size: 13, weight: .medium))
                                .lineLimit(2)
                        }
                        if !result.snippet.isEmpty {
                            Text(result.snippet)
                                .font(.songtiTimes(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        Text(result.url.absoluteString)
                            .font(.songtiTimes(size: 9))
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
                        .font(.songtiTimes(size: 10))
                    Image(systemName: "brain")
                        .font(.songtiTimes(size: 10))
                    Text("思考过程")
                        .font(.songtiTimes(size: 10))
                    if let start = message.thinkingStartTime, !message.isStreaming {
                        let duration = Int(Date().timeIntervalSince(start))
                        if duration > 0 {
                            Text("(\(duration)s)")
                                .font(.songtiTimes(size: 9))
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
                InlineText(markdown: normalizeMathDelimiters(message.reasoningContent), syntaxExtensions: [.math])
                    .textual.textSelection(.enabled)
                    .font(.songtiTimes(size: 13))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var markdownContent: some View {
        Group {
            if message.codeBlocks.isEmpty {
                plainMarkdownContent
            } else {
                segmentedMarkdownContent
            }
        }
    }

    private func normalizeMathDelimiters(_ markdown: String) -> String {
        var result = markdown

        // Step 1: convert alternative LaTeX block delimiters to standard $$...$$
        result = result.replacingOccurrences(of: "\\[", with: "$$")
        result = result.replacingOccurrences(of: "\\]", with: "$$")
        result = result.replacingOccurrences(of: "\\begin{equation}", with: "$$")
        result = result.replacingOccurrences(of: "\\end{equation}", with: "$$")
        result = result.replacingOccurrences(of: "\\begin{align}", with: "$$")
        result = result.replacingOccurrences(of: "\\end{align}", with: "$$")
        result = result.replacingOccurrences(of: "\\begin{aligned}", with: "$$")
        result = result.replacingOccurrences(of: "\\end{aligned}", with: "$$")

        // Step 2: convert $$...$$ block math to ```math code blocks.  Textual
        // handles ```math blocks at the block level (MathCodeBlock), which does
        // not get split by paragraph boundaries.  The PatternProcessor, in
        // contrast, tokenizes each AttributedString run independently and cannot
        // detect $$ blocks that span run (paragraph) boundaries — or block math
        // at all in some Swift Regex / Markdown parser configurations.
        if let blockRegex = try? NSRegularExpression(pattern: "(?s)\\$\\$(.+?)\\$\\$") {
            let nsRange = NSRange(result.startIndex..., in: result)
            for match in blockRegex.matches(in: result, range: nsRange).reversed() {
                guard match.numberOfRanges >= 2,
                      let fullRange = Range(match.range, in: result),
                      let contentRange = Range(match.range(at: 1), in: result) else { continue }
                var content = String(result[contentRange])
                // Collapse blank lines so the entire formula stays in one code block
                while content.contains("\n\n") {
                    content = content.replacingOccurrences(of: "\n\n", with: "\n")
                }
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
                result.replaceSubrange(fullRange, with: "\n```math\n\(content)\n```\n")
            }
        }

        // Step 3: convert alternative LaTeX inline delimiters to $...$
        result = result.replacingOccurrences(of: "\\(", with: "$")
        result = result.replacingOccurrences(of: "\\)", with: "$")
        return result
    }

    var plainMarkdownContent: some View {
        StructuredText(markdown: normalizeMathDelimiters(message.content), syntaxExtensions: [.math])
            .textual.textSelection(.enabled)
            .textual.structuredTextStyle(.default)
            .font(.songtiTimes(size: 13))
            .padding(10)
            .background(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(message.role == .user ? .white : .primary)
            .cornerRadius(12)
            .fixedSize(horizontal: false, vertical: true)
            .contextMenu {
                Button("拷贝") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                }
                if !message.extractedImageURLs.isEmpty {
                    Divider()
                    ForEach(Array(message.extractedImageURLs.enumerated()), id: \.offset) { _, url in
                        Button("保存图片: \(url.lastPathComponent)") {
                            saveImage(from: url)
                        }
                    }
                    Button("保存全部图片") {
                        for url in message.extractedImageURLs {
                            saveImage(from: url)
                        }
                    }
                }
            }
    }

    var segmentedMarkdownContent: some View {
        let codeBlocks = message.codeBlocks
        let textSegments = message.contentSegmentsWithoutCodeBlocks()
        let maxCount = max(textSegments.count, codeBlocks.count)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<maxCount, id: \.self) { index in
                if index < textSegments.count {
                    let seg = textSegments[index]
                    if !seg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        StructuredText(markdown: normalizeMathDelimiters(seg), syntaxExtensions: [.math])
                            .textual.textSelection(.enabled)
                            .textual.structuredTextStyle(.default)
                            .font(.songtiTimes(size: 13))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    }
                }
                if index < codeBlocks.count {
                    let block = codeBlocks[index]
                    codeBlockView(block: block)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(10)
        .background(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        .foregroundColor(message.role == .user ? .white : .primary)
        .cornerRadius(12)
        .fixedSize(horizontal: false, vertical: true)
        .contextMenu {
            Button("拷贝全部") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            }
            if !codeBlocks.isEmpty {
                Divider()
                ForEach(Array(codeBlocks.enumerated()), id: \.offset) { idx, block in
                    let label = block.language.map { "\($0) 代码 #\(idx + 1)" } ?? "代码 #\(idx + 1)"
                    Button("拷贝 \(label)") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(block.code, forType: .string)
                    }
                }
            }
            if !message.extractedImageURLs.isEmpty {
                Divider()
                ForEach(Array(message.extractedImageURLs.enumerated()), id: \.offset) { _, url in
                    Button("保存图片: \(url.lastPathComponent)") {
                        saveImage(from: url)
                    }
                }
                Button("保存全部图片") {
                    for url in message.extractedImageURLs {
                        saveImage(from: url)
                    }
                }
            }
        }
    }

    func codeBlockView(block: Message.CodeBlock) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 6) {
                if let lang = block.language {
                    Text(lang)
                        .font(.songtiTimes(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                        .padding(.vertical, 3)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(block.code, forType: .string)
                    copiedCodeId = UUID()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedCodeId = nil
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copiedCodeId != nil ? "checkmark" : "doc.on.doc")
                            .font(.songtiTimes(size: 10))
                        Text(copiedCodeId != nil ? "已复制" : "复制")
                            .font(.songtiTimes(size: 10))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .background(Color.secondary.opacity(0.08))

            StructuredText(markdown: "```\(block.language ?? "")\n\(block.code)\n```", syntaxExtensions: [.math])
                .textual.textSelection(.enabled)
                .textual.structuredTextStyle(.default)
                .padding(10)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    var generatedImagesView: some View {
        VStack(spacing: 8) {
            ForEach(Array(message.extractedImageURLs.enumerated()), id: \.offset) { _, url in
                HStack {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(8)
                        case .failure:
                            VStack(spacing: 4) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.songtiTimes(size: 22))
                                    .foregroundColor(.secondary)
                                Text("加载失败")
                                    .font(.songtiTimes(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 200, height: 120)
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 120)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    Button {
                        saveImage(from: url)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.songtiTimes(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("保存图片")
                }
            }
        }
        .padding(.leading, 6)
    }

    var actionButtons: some View {
        HStack(spacing: 8) {
            if message.role == .assistant {
                Button {
                    onRegenerate?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.songtiTimes(size: 9))
                        Text("重新生成")
                            .font(.songtiTimes(size: 9))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
            } else if message.role == .user {
                Button {
                    onEdit?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "pencil")
                            .font(.songtiTimes(size: 9))
                        Text("编辑")
                            .font(.songtiTimes(size: 9))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)

                Button {
                    onUndo?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.songtiTimes(size: 9))
                        Text("撤销")
                            .font(.songtiTimes(size: 9))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
            }
        }
    }

    private func saveImage(from url: URL) {
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.nameFieldStringValue = url.lastPathComponent
                savePanel.allowedContentTypes = [.png, .jpeg, .gif]
                if savePanel.runModal() == .OK, let saveURL = savePanel.url {
                    try? data.write(to: saveURL)
                }
            }
        }
    }
}
