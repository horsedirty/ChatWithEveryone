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

    struct CodeBlock {
        public let language: String?
        public let code: String
    }

    var codeBlocks: [CodeBlock] {
        let pattern = "```(\\w+)?\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        return regex.matches(in: content, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let codeRange = Range(match.range(at: 2), in: content) else { return nil }
            let lang: String? = {
                guard match.numberOfRanges > 1,
                      let langRange = Range(match.range(at: 1), in: content) else { return nil }
                let s = String(content[langRange])
                return s.isEmpty ? nil : s
            }()
            return CodeBlock(language: lang, code: String(content[codeRange]))
        }
    }

    func contentSegmentsWithoutCodeBlocks() -> [String] {
        let pattern = "```(?:\\w+)?\\s*\\n[\\s\\S]*?\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [content] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        var results: [String] = []
        var lastEnd = content.startIndex
        for match in matches {
            if let r = Range(match.range, in: content) {
                if lastEnd < r.lowerBound {
                    results.append(String(content[lastEnd..<r.lowerBound]))
                }
                lastEnd = r.upperBound
            }
        }
        if lastEnd < content.endIndex {
            results.append(String(content[lastEnd..<content.endIndex]))
        }
        return results.isEmpty && !content.isEmpty ? [content] : results
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
