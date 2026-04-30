import Foundation

struct ChatSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var messages: [Message] = []
    var providerId: UUID?
    var selectedModel: String?
    var contextLength: Int = 128000
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var lastMessage: Message? { messages.last }

    var totalTokens: Int {
        messages.reduce(0) { $0 + $1.tokenCount }
    }

    var contextWindowSize: Int {
        contextLength
    }

    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
        if title == "新对话", let firstUserMsg = messages.first(where: { $0.role == .user }) {
            title = String(firstUserMsg.content.prefix(30))
        }
    }

    mutating func updateLastAssistantMessage(_ content: String) {
        if let index = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[index].content = content
            messages[index].isStreaming = false
            updatedAt = Date()
        }
    }

    mutating func appendToLastAssistantMessage(_ chunk: String) {
        if let last = messages.last, last.role == .assistant, last.isStreaming {
            messages[messages.count - 1].content += chunk
            updatedAt = Date()
        } else {
            let msg = Message.assistant(chunk, isStreaming: true)
            messages.append(msg)
            updatedAt = Date()
        }
    }

    mutating func appendReasoningContent(_ chunk: String) {
        if !(messages.last?.role == .assistant && messages.last?.isStreaming == true) {
            let msg = Message.assistant("", isStreaming: true)
            messages.append(msg)
        }
        messages[messages.count - 1].reasoningContent += chunk
        updatedAt = Date()
    }

    mutating func finishLastAssistantStreaming() {
        guard let last = messages.last, last.role == .assistant, last.isStreaming else { return }
        messages[messages.count - 1].isStreaming = false
        messages[messages.count - 1].thinkingStartTime = nil
        updatedAt = Date()
    }

    var chatAPIMessages: [[String: Any]] {
        var result: [[String: Any]] = []
        for msg in messages {
            var dict: [String: Any] = ["role": msg.role.rawValue]
            if msg.images.isEmpty {
                dict["content"] = msg.content
            } else {
                var contentParts: [[String: Any]] = [
                    ["type": "text", "text": msg.content]
                ]
                for image in msg.images {
                    if let base64 = image.base64Data {
                        contentParts.append([
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                        ])
                    }
                }
                dict["content"] = contentParts
            }
            result.append(dict)
        }
        return result
    }
}

typealias SessionsStore = [ChatSession]
