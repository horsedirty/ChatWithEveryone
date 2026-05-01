import Foundation

enum ChatMode: String, Codable, CaseIterable {
    case chat = "对话"
    case imageGeneration = "图片生成"
}

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
    var reasoningContent: String = ""
    var images: [ImageAttachment] = []
    var timestamp: Date = Date()
    var isStreaming: Bool = false
    var thinkingStartTime: Date? = nil

    var hasImages: Bool { !images.isEmpty }

    var hasReasoning: Bool { !reasoningContent.isEmpty }

    var extractedImageURLs: [URL] {
        let pattern = /!\[.*?\]\((https?:\/\/[^\s)]+\.(?:png|jpg|jpeg|gif|webp|bmp)(?:\?[^\s)]*)?)\)/
        return content.matches(of: pattern).compactMap { match in
            URL(string: String(match.output.1))
        }
    }

    var tokenCount: Int {
        var count = 0
        for ch in content {
            count += ch.isASCII ? 1 : 2
        }
        for ch in reasoningContent {
            count += ch.isASCII ? 1 : 2
        }
        return max(count / 4, 1)
    }

    static func user(_ content: String, images: [ImageAttachment] = []) -> Message {
        Message(role: .user, content: content, images: images)
    }

    static func assistant(_ content: String, isStreaming: Bool = false) -> Message {
        Message(role: .assistant, content: content, isStreaming: isStreaming, thinkingStartTime: isStreaming ? Date() : nil)
    }

    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }

    static func searchResult(_ results: [SearchResult]) -> Message {
        Message(role: .system, content: WebSearchService.formatSearchResults(results), searchResults: results)
    }

    var searchResults: [SearchResult]?
}
