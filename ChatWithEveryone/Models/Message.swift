import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ImageAttachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var localFilePath: String
    var base64Data: String?
}

struct Message: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: MessageRole
    var content: String
    var images: [ImageAttachment] = []
    var timestamp: Date = Date()
    var isStreaming: Bool = false

    var hasImages: Bool { !images.isEmpty }

    static func user(_ content: String, images: [ImageAttachment] = []) -> Message {
        Message(role: .user, content: content, images: images)
    }

    static func assistant(_ content: String, isStreaming: Bool = false) -> Message {
        Message(role: .assistant, content: content, isStreaming: isStreaming)
    }

    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}
