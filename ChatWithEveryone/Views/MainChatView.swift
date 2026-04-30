import SwiftUI
import UniformTypeIdentifiers

struct MainChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showFileImporter = false
    @State private var showScreenCaptureSheet = false
    @State private var editingSessionId: UUID?
    @State private var editingTitle = ""

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
                if editingSessionId == session.id {
                    HStack(spacing: 4) {
                        TextField("标题", text: $editingTitle)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .onSubmit {
                                viewModel.updateSessionTitle(session.id, title: editingTitle)
                                editingSessionId = nil
                            }
                        Button {
                            viewModel.updateSessionTitle(session.id, title: editingTitle)
                            editingSessionId = nil
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        Button {
                            editingSessionId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .tag(session.id)
                } else {
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
                        Button("重命名") {
                            editingSessionId = session.id
                            editingTitle = session.title
                        }
                        Divider()
                        Button("删除对话", role: .destructive) {
                            viewModel.deleteSession(session.id)
                        }
                    }
                    .onTapGesture(count: 2) {
                        editingSessionId = session.id
                        editingTitle = session.title
                    }
                    .tag(session.id)
                }
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

            Divider()
                .frame(height: 14)

            HStack(spacing: 2) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 9))
                Picker("上下文", selection: Binding(
                    get: { viewModel.selectedSession?.contextLength ?? 128000 },
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
                .font(.system(size: 9))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
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
            Text(windowSize >= 1000000 ? "\(tokens)/\(windowSize/1000000)M" : "\(tokens)/\(windowSize/1000)k")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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

            contextProgressView

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
