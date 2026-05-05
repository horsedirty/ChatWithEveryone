import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FloatingChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onDismiss: (() -> Void)?
    var onOpenMainWindow: (() -> Void)?

    @State private var showFileImporter = false
    @State private var showScreenCaptureSheet = false
    @State private var enterPressedOnce = false
    @State private var shouldAutoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ChatWithEveryone")
                    .font(.songtiTimes(size: 13, weight: .semibold))
                Spacer()
                Button {
                    onOpenMainWindow?()
                } label: {
                    Image(systemName: "rectangle.expand.vertical")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("切换到主窗口")
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if viewModel.showModelPicker {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                        .font(.songtiTimes(size: 10))
                    Picker("模型", selection: Binding(
                        get: { viewModel.currentModel },
                        set: { viewModel.updateSessionModel($0) }
                    )) {
                        ForEach(viewModel.availableModelsWithLabels, id: \.model) { item in
                            Text(item.label).tag(item.model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .font(.songtiTimes(size: 10))

                    Divider()
                        .frame(height: 14)

                    HStack(spacing: 2) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundColor(.secondary)
                            .font(.songtiTimes(size: 9))
                        Picker("上下文", selection: Binding(
                            get: { viewModel.selectedSession?.contextLength ?? 1000000 },
                            set: { viewModel.updateContextLength($0) }
                        )) {
                            Text("8K").tag(8000)
                            Text("16K").tag(16000)
                            Text("32K").tag(32000)
                            Text("64K").tag(64000)
                            Text("128K").tag(128000)
                            Text("256K").tag(256000)
                            Text("1M").tag(1000000)
                            Text("2M").tag(2000000)
                            Text("4M").tag(4000000)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.songtiTimes(size: 9))
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.selectedSession?.messages.isEmpty ?? true {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.songtiTimes(size: 26))
                                    .foregroundColor(.secondary)
                                Text("开始对话")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        }

                        ForEach(viewModel.selectedSession?.messages ?? []) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }

                        if viewModel.isWebSearching {
                            HStack(spacing: 8) {
                                Spacer(minLength: 60)
                                HStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .font(.songtiTimes(size: 10))
                                        .foregroundColor(.accentColor)
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("正在搜索...")
                                        .font(.songtiTimes(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color.accentColor.opacity(0.08))
                                .cornerRadius(12)
                                Spacer(minLength: 60)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .id("webSearching")
                        }

                        if viewModel.isSending, !viewModel.isWebSearching,
                           viewModel.selectedSession?.messages.last?.role != .assistant || viewModel.selectedSession?.messages.last?.isStreaming == false {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.songtiTimes(size: 20))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 28)
                                TypingIndicatorView()
                                .foregroundColor(.accentColor)
                                .padding(10)
                                Spacer(minLength: 60)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .id("aiLoading")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    let maxOffsetY = max(geometry.contentSize.height - geometry.bounds.height, 0)
                    return geometry.contentOffset.y >= maxOffsetY - 50
                } action: { _, isNearBottom in
                    shouldAutoScroll = isNearBottom
                }
                .onChange(of: viewModel.selectedSession?.messages.count) { _, _ in
                    if shouldAutoScroll, let last = viewModel.selectedSession?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isWebSearching) { _, newValue in
                    if newValue, shouldAutoScroll {
                        withAnimation { proxy.scrollTo("webSearching", anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isSending) { _, newValue in
                    if newValue, !viewModel.isWebSearching {
                        shouldAutoScroll = true
                        withAnimation { proxy.scrollTo("aiLoading", anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.selectedSession?.messages.last?.content) { _, _ in
                    if shouldAutoScroll, let last = viewModel.selectedSession?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.songtiTimes(size: 10))
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("忽略") { viewModel.resetError() }
                        .font(.songtiTimes(size: 10))
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            }

            contextProgressView

            ImagePickerView(viewModel: viewModel)

            if !viewModel.attachedFileNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.attachedFileNames, id: \.self) { name in
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.songtiTimes(size: 10))
                                Text(name)
                                    .font(.songtiTimes(size: 10))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                HStack(spacing: 2) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.songtiTimes(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("添加图片/文件")

                    Button {
                        showScreenCaptureSheet = true
                    } label: {
                        Image(systemName: "macwindow.and.cursorarrow")
                            .font(.songtiTimes(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("截取窗口")

                    Button {
                        viewModel.isWebSearchEnabled.toggle()
                    } label: {
                        Image(systemName: "globe")
                            .font(.songtiTimes(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.isWebSearchEnabled ? .accentColor : .secondary)
                    .help(viewModel.isWebSearchEnabled ? "已开启联网搜索" : "开启联网搜索")
                }

                TextField("输入消息... (双击Enter 发送)", text: $viewModel.inputText, axis: .vertical)
                    .font(.songtiTimes(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onKeyPress(.return) {
                        handleEnterKey()
                    }
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Button {
                    if viewModel.isSending {
                        viewModel.cancelStreaming()
                    } else {
                        viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: viewModel.isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.songtiTimes(size: 20))
                        .foregroundColor(viewModel.isSending ? .red : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isSending && viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty)
            }
            .padding(8)
        }
        .frame(minWidth: 440, minHeight: 500)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    let ext = url.pathExtension.lowercased()
                    if ["txt", "md", "markdown"].contains(ext) {
                        viewModel.addTextFile(from: url)
                    } else {
                        viewModel.addImage(from: url)
                    }
                }
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showScreenCaptureSheet) {
            ScreenCapturePickerView(viewModel: viewModel)
        }
    }

    private func handleEnterKey() -> KeyPress.Result {
        let flags = NSApp.currentEvent?.modifierFlags
        if flags?.contains(.shift) == true {
            enterPressedOnce = false
            return .ignored
        }
        if enterPressedOnce {
            enterPressedOnce = false
            viewModel.sendMessage()
            return .handled
        }
        enterPressedOnce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak viewModel] in
            enterPressedOnce = false
        }
        return .ignored
    }

    var contextProgressView: some View {
        let session = viewModel.selectedSession
        let tokens = session?.totalTokens ?? 0
        let windowSize = session?.contextWindowSize ?? 1000000
        let fraction = min(Double(tokens) / Double(windowSize), 1.0)

        return HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.songtiTimes(size: 9))
                .foregroundColor(fraction > 0.8 ? .orange : .secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fraction > 0.8 ? Color.orange : fraction > 0.5 ? Color.yellow : Color.accentColor)
                        .frame(width: max(geo.size.width * fraction, 4), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: fraction)
                }
            }
            .frame(height: 4)
            Text(windowSize >= 1000000 ? "\(tokens)/\(windowSize/1000000)M" : "\(tokens)/\(windowSize/1000)k")
                .font(.songtiTimes(size: 9))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
