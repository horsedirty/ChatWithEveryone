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
        case .deepseek: return "deepseek-v4-flash"
        case .siliconflow: return "deepseek-ai/DeepSeek-V3"
        case .aiapi: return "gpt-4o"
        case .custom: return ""
        }
    }

    var availableModels: [String] {
        switch self {
        case .deepseek:
            return ["deepseek-v4-flash", "deepseek-v4-pro"]
        case .siliconflow:
            return [
                "deepseek-ai/DeepSeek-V3",
                "deepseek-ai/DeepSeek-R1",
                "Qwen/Qwen2.5-72B-Instruct",
                "Qwen/QwQ-32B",
                "meta-llama/Llama-3.1-405B-Instruct",
                "Kwai-Kolors/Kolors",
                "stabilityai/stable-diffusion-3-5-large",
                "black-forest-labs/FLUX.1-schnell"
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

    var imageGenerationPath: String {
        return "/images/generations"
    }

    func isImageGenerationModel(_ model: String) -> Bool {
        let imageModelPatterns = [
            "Kolors", "kolors",
            "stable-diffusion", "Stable-Diffusion", "stable-diffusion",
            "FLUX", "flux",
            "SDXL", "sdxl",
            "dall-e", "DALL-E",
            "Image", "image",
            "midjourney", "Midjourney"
        ]
        for pattern in imageModelPatterns {
            if model.contains(pattern) { return true }
        }
        return false
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
    var customModels: [String] = []
    var isEnabled: Bool = true
    var customHeaders: [String: String]? = nil
    var imageGenerationBaseURL: String? = nil

    var chatCompletionURL: String {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return base + providerType.chatCompletionPath
    }

    var imageGenerationURL: String {
        if let override = imageGenerationBaseURL, !override.isEmpty {
            return override.hasSuffix("/") ? String(override.dropLast()) : override
        }
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return base + providerType.imageGenerationPath
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
