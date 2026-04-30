import SwiftUI
import AppKit
import ScreenCaptureKit
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var providers: [APIProvider] = []
    @Published var sessions: [ChatSession] = []
    @Published var selectedSessionId: UUID?
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var attachedImages: [ImageAttachment] = []
    @Published var attachedFileNames: [String] = []
    @Published var showSettings = false
    @Published var showScreenCapturePicker = false

    var selectedSession: ChatSession? {
        sessions.first(where: { $0.id == selectedSessionId })
    }

    var activeProvider: APIProvider? {
        guard let session = selectedSession,
              let pid = session.providerId else { return providers.first }
        return providers.first(where: { $0.id == pid })
    }

    var currentModel: String {
        if let sessionModel = selectedSession?.selectedModel, !sessionModel.isEmpty {
            return sessionModel
        }
        return activeProvider?.model ?? ""
    }

    var availableModelsForCurrentProvider: [String] {
        let allModels: [String] = {
            var models = activeProvider?.providerType.availableModels ?? []
            if let custom = activeProvider?.customModels {
                for m in custom where !models.contains(m) {
                    models.append(m)
                }
            }
            if let m = activeProvider?.model, !m.isEmpty, !models.contains(m) {
                models.append(m)
            }
            if let m = selectedSession?.selectedModel, !m.isEmpty, !models.contains(m) {
                models.append(m)
            }
            return models
        }()
        let mode = selectedSession?.chatMode ?? .chat
        if mode == .imageGeneration {
            return allModels.filter { activeProvider?.providerType.isImageGenerationModel($0) ?? false }
        }
        return allModels.filter { !(activeProvider?.providerType.isImageGenerationModel($0) ?? false) }
    }

    var showModelPicker: Bool {
        !currentModel.isEmpty
    }

    var providerName: String {
        activeProvider?.name ?? activeProvider?.providerType.rawValue ?? ""
    }

    var availableModelsWithLabels: [(label: String, model: String)] {
        let prefix = providerName
        return availableModelsForCurrentProvider.map { model in
            (label: "\(prefix) - \(model)", model: model)
        }
    }

    init() {
        load()
    }

    func load() {
        providers = StorageService.shared.loadProviders()
        sessions = StorageService.shared.loadSessions()
        if selectedSessionId == nil {
            selectedSessionId = sessions.first?.id
        }
    }

    func save() {
        StorageService.shared.saveProviders(providers)
        StorageService.shared.saveSessions(sessions)
    }

    func createNewSession() {
        let session = ChatSession(title: "新对话", providerId: activeProvider?.id)
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        save()
    }

    func selectSession(_ id: UUID) {
        selectedSessionId = id
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        if selectedSessionId == id {
            selectedSessionId = sessions.first?.id
        }
        save()
    }

    func addImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        let id = UUID()
        let path = StorageService.shared.saveImage(data, id: id)
        let base64 = data.base64EncodedString()
        let attachment = ImageAttachment(id: id, localFilePath: path, base64Data: base64)
        attachedImages.append(attachment)
    }

    func addTextFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let filename = url.lastPathComponent
        attachedFileNames.append(filename)
        let textBlock = """

        --- \(filename) ---
        \(content)
        --- 文件结束 ---

        """
        inputText += textBlock
    }

    func addImage(from nsImage: NSImage) {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return }
        let id = UUID()
        let path = StorageService.shared.saveImage(jpegData, id: id)
        let base64 = jpegData.base64EncodedString()
        let attachment = ImageAttachment(id: id, localFilePath: path, base64Data: base64)
        attachedImages.append(attachment)
    }

    func removeImage(_ image: ImageAttachment) {
        StorageService.shared.deleteImage(at: image.localFilePath)
        attachedImages.removeAll(where: { $0.id == image.id })
    }

    func clearImages() {
        attachedImages.removeAll()
    }

    func clearFiles() {
        attachedFileNames.removeAll()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachedImages.isEmpty else { return }
        guard let provider = activeProvider else {
            errorMessage = "请先在设置中配置 API 提供商"
            return
        }

        if providers.isEmpty {
            providers = [provider]
        }

        inputText = ""
        let imagesToSend = attachedImages
        clearImages()
        clearFiles()

        let model = currentModel
        let mode = selectedSession?.chatMode ?? .chat

        if mode == .imageGeneration {
            performImageGeneration(provider: provider, model: model, prompt: text, userImages: imagesToSend)
            return
        }

        guard let index = sessions.firstIndex(where: { $0.id == selectedSessionId }) else {
            let newSession = ChatSession(title: "新对话", providerId: provider.id)
            sessions.insert(newSession, at: 0)
            selectedSessionId = newSession.id
            let userMsg = Message.user(text, images: imagesToSend)
            sessions[0].addMessage(userMsg)
            performSend(provider: provider, sessionIndex: 0, userImages: imagesToSend)
            return
        }

        let userMsg = Message.user(text, images: imagesToSend)
        sessions[index].addMessage(userMsg)
        save()
        performSend(provider: provider, sessionIndex: index, userImages: imagesToSend)
    }

    private func performSend(provider: APIProvider, sessionIndex: Int, userImages: [ImageAttachment]) {
        isSending = true
        errorMessage = nil

        let msgs = sessions[sessionIndex].chatAPIMessages
        let model = sessions[sessionIndex].selectedModel ?? provider.model

        var providerWithModel = provider
        providerWithModel.model = model

        APIService.shared.sendMessage(
            provider: providerWithModel,
            messages: msgs,
            streaming: true,
            onReasoningChunk: { [weak self] chunk in
                guard let self else { return }
                if self.sessions.indices.contains(sessionIndex) {
                    self.sessions[sessionIndex].appendReasoningContent(chunk)
                }
            },
            onChunk: { [weak self] chunk in
                guard let self else { return }
                if self.sessions.indices.contains(sessionIndex) {
                    self.sessions[sessionIndex].appendToLastAssistantMessage(chunk)
                }
            },
            onComplete: { [weak self] result in
                guard let self else { return }
                self.isSending = false
                switch result {
                case .success:
                    if self.sessions.indices.contains(sessionIndex) {
                        self.sessions[sessionIndex].finishLastAssistantStreaming()
                    }
                    self.save()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    let errorMsg = "错误: \(error.localizedDescription)"
                    if self.sessions.indices.contains(sessionIndex) {
                        self.sessions[sessionIndex].updateLastAssistantMessage(errorMsg)
                    }
                }
            }
        )
    }

    private func performImageGeneration(provider: APIProvider, model: String, prompt: String, userImages: [ImageAttachment]) {
        isSending = true
        errorMessage = nil

        let sessionIndex: Int
        if let idx = sessions.firstIndex(where: { $0.id == selectedSessionId }) {
            sessionIndex = idx
        } else {
            let newSession = ChatSession(title: "新对话", providerId: provider.id)
            sessions.insert(newSession, at: 0)
            selectedSessionId = newSession.id
            sessionIndex = 0
        }

        let userMsg = Message.user(prompt, images: userImages)
        sessions[sessionIndex].addMessage(userMsg)

        APIService.shared.generateImage(
            provider: provider,
            model: model,
            prompt: prompt
        ) { [weak self] result in
            guard let self else { return }
            self.isSending = false
            switch result {
            case .success(let urls):
                let imageMarkdown = urls.map { "![生成的图片](\($0.absoluteString))" }.joined(separator: "\n")
                let responseText = imageMarkdown.isEmpty ? "图片生成完成，但未能获取图片链接。" : imageMarkdown
                let assistantMsg = Message.assistant(responseText, isStreaming: false)
                if self.sessions.indices.contains(sessionIndex) {
                    self.sessions[sessionIndex].addMessage(assistantMsg)
                }
                self.save()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                let errorMsg = "图片生成失败\nURL: \(provider.imageGenerationURL)\n\(error.localizedDescription)"
                let assistantMsg = Message.assistant(errorMsg, isStreaming: false)
                if self.sessions.indices.contains(sessionIndex) {
                    self.sessions[sessionIndex].addMessage(assistantMsg)
                }
                self.save()
            }
        }
    }

    func captureScreenAndAttach() async {
        isSending = true
        if let image = await ScreenCaptureService.shared.captureFullScreen() {
            addImage(from: image)
        }
        isSending = false
    }

    func captureWindowAndAttach(scWindow: SCWindow) async {
        isSending = true
        if let image = await ScreenCaptureService.shared.captureWindow(scWindow) {
            addImage(from: image)
        }
        isSending = false
    }

    func resetError() {
        errorMessage = nil
    }

    func updateSessionModel(_ model: String) {
        guard let sessionId = selectedSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].selectedModel = model
        save()
    }

    func updateSessionProvider(_ providerId: UUID) {
        guard let sessionId = selectedSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }),
              providers.contains(where: { $0.id == providerId }) else { return }
        sessions[index].providerId = providerId
        sessions[index].selectedModel = nil
        save()
    }

    func updateChatMode(_ mode: ChatMode) {
        guard let sessionId = selectedSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].chatMode = mode
        sessions[index].selectedModel = nil
        save()
    }

    func regenerateMessage(after messageId: UUID) {
        guard let sessionId = selectedSessionId,
              let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let msgIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }),
              msgIndex > 0,
              sessions[sessionIndex].messages[msgIndex - 1].role == .user else { return }
        let userMsg = sessions[sessionIndex].messages[msgIndex - 1]
        sessions[sessionIndex].messages.removeSubrange(msgIndex...)
        save()
        guard let provider = activeProvider else { return }
        performSend(provider: provider, sessionIndex: sessionIndex, userImages: userMsg.images)
    }

    func editMessage(_ messageId: UUID) {
        guard let sessionId = selectedSessionId,
              let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let msgIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }),
              sessions[sessionIndex].messages[msgIndex].role == .user else { return }
        inputText = sessions[sessionIndex].messages[msgIndex].content
    }

    func undoExchange(after messageId: UUID) {
        guard let sessionId = selectedSessionId,
              let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let msgIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
        if msgIndex > 0, sessions[sessionIndex].messages[msgIndex - 1].role == .assistant {
            sessions[sessionIndex].messages.removeSubrange((msgIndex - 1)...)
        } else {
            sessions[sessionIndex].messages.remove(at: msgIndex)
        }
        save()
    }

    func updateContextLength(_ length: Int) {
        guard let sessionId = selectedSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].contextLength = length
        save()
    }

    func addCustomModel(to providerId: UUID, model: String) {
        guard let index = providers.firstIndex(where: { $0.id == providerId }),
              !model.trimmingCharacters(in: .whitespaces).isEmpty,
              !providers[index].customModels.contains(model) else { return }
        providers[index].customModels.append(model)
        save()
    }

    func removeCustomModel(from providerId: UUID, model: String) {
        guard let index = providers.firstIndex(where: { $0.id == providerId }) else { return }
        providers[index].customModels.removeAll(where: { $0 == model })
        save()
    }

    func updateSessionTitle(_ sessionId: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sessions[index].title = title
        save()
    }
}
