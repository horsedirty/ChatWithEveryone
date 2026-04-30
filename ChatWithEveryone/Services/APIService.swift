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
        onReasoningChunk: (@MainActor @Sendable (String) -> Void)? = nil,
        onChunk: (@MainActor @Sendable (String) -> Void)?,
        onComplete: (@MainActor @Sendable (Result<String, APIError>) -> Void)?
    ) {
        guard !provider.apiKey.isEmpty else {
            Task { @MainActor in onComplete?(.failure(.noAPIKey)) }
            return
        }

        let urlString = provider.chatCompletionURL
        guard let url = URL(string: urlString) else {
            Task { @MainActor in onComplete?(.failure(.invalidURL)) }
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
        onReasoningChunk: (@MainActor @Sendable (String) -> Void)?,
        onChunk: (@MainActor @Sendable (String) -> Void)?,
        onComplete: (@MainActor @Sendable (Result<String, APIError>) -> Void)?
    ) {
        Task {
            do {
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await onComplete?(.failure(.invalidResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    var errorBody = ""
                    for try await line in bytes.lines.prefix(20) {
                        errorBody += line
                    }
                    let errorMessage = APIService.extractErrorMessage(from: errorBody) ?? errorBody
                    await onComplete?(.failure(.httpError(httpResponse.statusCode, errorMessage)))
                    return
                }

                var fullContent = ""
                var streamedContent = false

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }
                    guard let jsonData = jsonString.data(using: .utf8) else { continue }

                    do {
                        let chunk = try self.decoder.decode(ChatCompletionChunk.self, from: jsonData)
                        if let reasoning = chunk.choices?.first?.delta?.reasoning_content {
                            await onReasoningChunk?(reasoning)
                        }
                        if let content = chunk.choices?.first?.delta?.content {
                            fullContent += content
                            streamedContent = true
                            await onChunk?(content)
                        }
                    } catch {
                        continue
                    }
                }

                if !streamedContent && fullContent.isEmpty {
                    await onComplete?(.failure(.streamError("空响应")))
                } else {
                    await onComplete?(.success(fullContent))
                }
            } catch {
                await onComplete?(.failure(.networkError(error)))
            }
        }
    }

    private func performNonStreamRequest(
        _ request: URLRequest,
        onComplete: (@MainActor @Sendable (Result<String, APIError>) -> Void)?
    ) {
        Task {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await onComplete?(.failure(.invalidResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    let errorMessage = APIService.extractErrorMessage(from: body) ?? body
                    await onComplete?(.failure(.httpError(httpResponse.statusCode, errorMessage)))
                    return
                }

                do {
                    let result = try self.decoder.decode(ChatCompletionResponse.self, from: data)
                    let content = result.choices?.first?.message?.content ?? ""
                    await onComplete?(.success(content))
                } catch {
                    await onComplete?(.failure(.decodingError(error)))
                }
            } catch {
                await onComplete?(.failure(.networkError(error)))
            }
        }
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

    func generateImage(
        provider: APIProvider,
        model: String,
        prompt: String,
        imageSize: String = "1024x1024",
        onComplete: (@MainActor @Sendable (Result<[URL], APIError>) -> Void)?
    ) {
        guard !provider.apiKey.isEmpty else {
            Task { @MainActor in onComplete?(.failure(.noAPIKey)) }
            return
        }

        let urlString = provider.imageGenerationURL
        guard let url = URL(string: urlString) else {
            Task { @MainActor in onComplete?(.failure(.invalidURL)) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "image_size": imageSize,
            "batch_size": 1,
            "num_inference_steps": 20,
            "guidance_scale": 7.5
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Task {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await onComplete?(.failure(.invalidResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let bodyText = String(data: data, encoding: .utf8) ?? ""
                    let errorMessage = APIService.extractErrorMessage(from: bodyText) ?? bodyText
                    await onComplete?(.failure(.httpError(httpResponse.statusCode, errorMessage)))
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let images = json["images"] as? [[String: Any]] else {
                    await onComplete?(.failure(.decodingError(NSError(domain: "", code: -1))))
                    return
                }

                let urls: [URL] = images.compactMap { img in
                    guard let urlStr = img["url"] as? String else { return nil }
                    return URL(string: urlStr)
                }

                await onComplete?(.success(urls))
            } catch {
                await onComplete?(.failure(.networkError(error)))
            }
        }
    }
}
