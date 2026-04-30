import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FloatingChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onDismiss: (() -> Void)?

    @State private var showFileImporter = false
    @State private var showScreenCaptureSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ChatWithEveryone")
                    .font(.headline)
                Spacer()
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
                        .font(.caption)
                    Picker("模型", selection: Binding(
                        get: { viewModel.currentModel },
                        set: { viewModel.updateSessionModel($0) }
                    )) {
                        ForEach(viewModel.availableModelsForCurrentProvider, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.selectedSession?.messages.isEmpty ?? true {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.largeTitle)
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
                        if viewModel.isSending {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 28)
                                HStack(spacing: 4) {
                                    Circle().frame(width: 6, height: 6).opacity(0.4)
                                    Circle().frame(width: 6, height: 6).opacity(0.7)
                                    Circle().frame(width: 6, height: 6).opacity(1.0)
                                }
                                .foregroundColor(.accentColor)
                                .padding(10)
                                Spacer(minLength: 60)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.selectedSession?.messages.count) { _, _ in
                    if let last = viewModel.selectedSession?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isSending) { _, newValue in
                    if newValue {
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.selectedSession?.messages.last?.content) { _, _ in
                    if let last = viewModel.selectedSession?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("忽略") { viewModel.resetError() }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            }

            contextProgressView

            ImagePickerView(viewModel: viewModel)

            HStack(alignment: .bottom, spacing: 6) {
                HStack(spacing: 2) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("添加图片")

                    Button {
                        showScreenCaptureSheet = true
                    } label: {
                        Image(systemName: "macwindow.and.cursorarrow")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("截取窗口")
                }

                ZStack(alignment: .leading) {
                    if viewModel.inputText.isEmpty {
                        Text("输入消息...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 30, maxHeight: 100)
                        .fixedSize(horizontal: false, vertical: true)
                        .onKeyPress(.return) {
                            handleEnterKey()
                        }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: viewModel.isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty))
            }
            .padding(8)
        }
        .frame(minWidth: 440, minHeight: 500)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    viewModel.addImage(from: url)
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
            return .ignored
        }
        viewModel.sendMessage()
        return .handled
    }

    var contextProgressView: some View {
        let session = viewModel.selectedSession
        let tokens = session?.totalTokens ?? 0
        let windowSize = session?.contextWindowSize ?? 128000
        let fraction = min(Double(tokens) / Double(windowSize), 1.0)

        return HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 9))
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
            Text("\(tokens)/\(windowSize/1000)k")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
