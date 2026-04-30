import Foundation

enum APIProviderType: String, Codable, CaseIterable {
    case deepseek = "DeepSeek"
    case siliconflow = "硅基流动"
    case aiapi = "AIAPI.world"
    case custom = "自定义"

    var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .aiapi: return "https://aiapi.world/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .siliconflow: return "deepseek-ai/DeepSeek-V3"
        case .aiapi: return "gpt-4o"
        case .custom: return ""
        }
    }

    var availableModels: [String] {
        switch self {
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .siliconflow:
            return [
                "deepseek-ai/DeepSeek-V3",
                "deepseek-ai/DeepSeek-R1",
                "Qwen/Qwen2.5-72B-Instruct",
                "Qwen/QwQ-32B",
                "meta-llama/Llama-3.1-405B-Instruct"
            ]
        case .aiapi:
            return ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo", "claude-3-5-sonnet", "gemini-2.0-flash"]
        case .custom:
            return []
        }
    }

    var chatCompletionPath: String {
        return "/chat/completions"
    }

    var isVisionCapable: Bool {
        switch self {
        case .deepseek: return true
        case .siliconflow: return true
        case .aiapi: return true
        case .custom: return true
        }
    }
}

struct APIProvider: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var providerType: APIProviderType
    var baseURL: String
    var apiKey: String
    var model: String
    var isEnabled: Bool = true
    var customHeaders: [String: String]? = nil

    var chatCompletionURL: String {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return base + providerType.chatCompletionPath
    }

    static func `default`(for type: APIProviderType) -> APIProvider {
        APIProvider(
            name: type.rawValue,
            providerType: type,
            baseURL: type.defaultBaseURL,
            apiKey: "",
            model: type.defaultModel
        )
    }
}

typealias ProvidersStore = [APIProvider]
