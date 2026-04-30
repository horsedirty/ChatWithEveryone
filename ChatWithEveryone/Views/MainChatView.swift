import SwiftUI
import UniformTypeIdentifiers

struct MainChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showFileImporter = false
    @State private var showScreenCaptureSheet = false

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            chatDetailView
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    var sidebarView: some View {
        List(selection: Binding(
            get: { viewModel.selectedSessionId },
            set: { id in
                if let id = id { viewModel.selectSession(id) }
            }
        )) {
            ForEach(viewModel.sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .lineLimit(1)
                        .font(.body)
                    Text(session.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button("删除对话", role: .destructive) {
                        viewModel.deleteSession(session.id)
                    }
                }
                .tag(session.id)
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    viewModel.deleteSession(viewModel.sessions[idx].id)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createNewSession()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("新建对话")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("设置")
            }
        }
    }

    var chatDetailView: some View {
        VStack(spacing: 0) {
            if viewModel.selectedSession == nil {
                emptyStateView
            } else {
                chatContentView
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("选择或创建一个对话开始聊天")
                .font(.title2)
                .foregroundColor(.secondary)
            Button("新建对话") {
                viewModel.createNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var modelPickerView: some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    var chatContentView: some View {
        VStack(spacing: 0) {
            if viewModel.showModelPicker {
                modelPickerView
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.selectedSession?.messages ?? []) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.selectedSession?.messages.count) { _, _ in
                    if let last = viewModel.selectedSession?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
                    Spacer()
                    Button("忽略") { viewModel.resetError() }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
            }

            ImagePickerView(viewModel: viewModel)

            inputBarView
        }
    }

    var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 4) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "photo.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .help("添加图片")

                    Button {
                        showScreenCaptureSheet = true
                    } label: {
                        Image(systemName: "macwindow.and.cursorarrow")
                    }
                    .buttonStyle(.plain)
                    .help("截取窗口")
                }

                ZStack(alignment: .leading) {
                    if viewModel.inputText.isEmpty {
                        Text("输入消息... (Enter 发送, Shift+Enter 换行)")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 36, maxHeight: 120)
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
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty))
            }
            .padding(10)
        }
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
}
