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
        activeProvider?.providerType.availableModels ?? []
    }

    var showModelPicker: Bool {
        !availableModelsForCurrentProvider.isEmpty
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
        guard let data = try? Data(contentsOf: url) else { return }
        let id = UUID()
        let path = StorageService.shared.saveImage(data, id: id)
        let base64 = data.base64EncodedString()
        let attachment = ImageAttachment(id: id, localFilePath: path, base64Data: base64)
        attachedImages.append(attachment)
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
        for img in attachedImages {
            StorageService.shared.deleteImage(at: img.localFilePath)
        }
        attachedImages.removeAll()
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

        guard let index = sessions.firstIndex(where: { $0.id == selectedSessionId }) else {
            let newSession = ChatSession(title: "新对话", providerId: provider.id)
            sessions.insert(newSession, at: 0)
            selectedSessionId = newSession.id
            let userMsg = Message.user(text, images: attachedImages)
            sessions[0].addMessage(userMsg)
            inputText = ""
            let imagesToSend = attachedImages
            clearImages()
            performSend(provider: provider, sessionIndex: 0, userImages: imagesToSend)
            return
        }

        let userMsg = Message.user(text, images: attachedImages)
        sessions[index].addMessage(userMsg)
        save()
        inputText = ""
        let imagesToSend = attachedImages
        clearImages()

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

    func updateContextLength(_ length: Int) {
        guard let sessionId = selectedSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].contextLength = length
        save()
    }

    func updateSessionTitle(_ sessionId: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sessions[index].title = title
        save()
    }
}
