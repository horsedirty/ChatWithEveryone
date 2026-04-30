import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case noProvider
    case noAPIKey
    case streamError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code, let msg): return "HTTP 错误 \(code): \(msg)"
        case .decodingError(let e): return "解析错误: \(e.localizedDescription)"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .noProvider: return "未配置 API 提供商"
        case .noAPIKey: return "未设置 API Key"
        case .streamError(let msg): return "流式传输错误: \(msg)"
        }
    }
}

struct ChatCompletionChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
            let role: String?
            let reasoning_content: String?
        }
        let delta: Delta?
        let index: Int?
        let finish_reason: String?
    }
    let id: String?
    let choices: [Choice]?
}

struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String?
        }
        let message: Message?
        let index: Int?
        let finish_reason: String?
    }
    let id: String?
    let choices: [Choice]?
}

final class APIService: @unchecked Sendable {
    static let shared = APIService()
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func sendMessage(
        provider: APIProvider,
        messages: [[String: Any]],
        streaming: Bool = true,
        onReasoningChunk: (@Sendable (String) -> Void)? = nil,
        onChunk: (@Sendable (String) -> Void)?,
        onComplete: (@Sendable (Result<String, APIError>) -> Void)?
    ) {
        guard !provider.apiKey.isEmpty else {
            onComplete?(.failure(.noAPIKey))
            return
        }

        let urlString = provider.chatCompletionURL
        guard let url = URL(string: urlString) else {
            onComplete?(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("\(Bundle.main.bundleIdentifier ?? "chatwitheveryone")-swift/1.0", forHTTPHeaderField: "User-Agent")

        for (key, value) in provider.customHeaders ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body: [String: Any] = [
            "model": provider.model,
            "messages": messages,
            "stream": streaming
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if streaming {
            performStreamRequest(request, onReasoningChunk: onReasoningChunk, onChunk: onChunk, onComplete: onComplete)
        } else {
            performNonStreamRequest(request, onComplete: onComplete)
        }
    }

    private func performStreamRequest(
        _ request: URLRequest,
        onReasoningChunk: (@Sendable (String) -> Void)?,
        onChunk: (@Sendable (String) -> Void)?,
        onComplete: (@Sendable (Result<String, APIError>) -> Void)?
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                onComplete?(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                onComplete?(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let errorMessage = APIService.extractErrorMessage(from: body) ?? body
                onComplete?(.failure(.httpError(httpResponse.statusCode, errorMessage)))
                return
            }

            guard let data = data else {
                onComplete?(.failure(.invalidResponse))
                return
            }

            let text = String(data: data, encoding: .utf8) ?? ""
            let lines = text.components(separatedBy: "\n").filter { $0.hasPrefix("data: ") }

            var fullContent = ""
            var streamedContent = false

            for line in lines {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" { continue }
                guard let jsonData = jsonString.data(using: .utf8) else { continue }

                do {
                    let chunk = try self.decoder.decode(ChatCompletionChunk.self, from: jsonData)
                    if let reasoning = chunk.choices?.first?.delta?.reasoning_content {
                        DispatchQueue.main.async { onReasoningChunk?(reasoning) }
                    }
                    if let content = chunk.choices?.first?.delta?.content {
                        fullContent += content
                        streamedContent = true
                        DispatchQueue.main.async { onChunk?(content) }
                    }
                } catch {
                    continue
                }
            }

            DispatchQueue.main.async {
                if !streamedContent && fullContent.isEmpty {
                    let errorMsg = APIService.extractErrorMessage(from: text) ?? "空响应"
                    onComplete?(.failure(.streamError(errorMsg)))
                } else {
                    onComplete?(.success(fullContent))
                }
            }
        }
        task.resume()
    }

    private func performNonStreamRequest(
        _ request: URLRequest,
        onComplete: (@Sendable (Result<String, APIError>) -> Void)?
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { onComplete?(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { onComplete?(.failure(.invalidResponse)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { onComplete?(.failure(.invalidResponse)) }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                let errorMessage = APIService.extractErrorMessage(from: body) ?? body
                DispatchQueue.main.async { onComplete?(.failure(.httpError(httpResponse.statusCode, errorMessage))) }
                return
            }

            do {
                let result = try self.decoder.decode(ChatCompletionResponse.self, from: data)
                let content = result.choices?.first?.message?.content ?? ""
                DispatchQueue.main.async { onComplete?(.success(content)) }
            } catch {
                DispatchQueue.main.async { onComplete?(.failure(.decodingError(error))) }
            }
        }
        task.resume()
    }

    private static func extractErrorMessage(from text: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
            return msg
        }
        if let msg = json["error"] as? String {
            return msg
        }
        return nil
    }
}
