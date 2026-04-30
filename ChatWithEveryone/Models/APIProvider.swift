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
