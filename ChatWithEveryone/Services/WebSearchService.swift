import Foundation

struct SearchResult: Identifiable, Codable, Equatable {
    var id: String { url.absoluteString }
    let title: String
    let snippet: String
    let url: URL
}

final class WebSearchService: @unchecked Sendable {
    static let shared = WebSearchService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    func search(query: String) async -> [SearchResult] {
        let apiResults = await searchInstantAnswer(query: query)
        if !apiResults.isEmpty {
            return apiResults
        }
        return await searchHTML(query: query)
    }

    private func searchInstantAnswer(query: String) async -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&no_redirect=1&t=ChatWithEveryone") else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

            var results: [SearchResult] = []

            if let abstract = json["Abstract"] as? String, !abstract.isEmpty,
               let abstractURL = json["AbstractURL"] as? String, !abstractURL.isEmpty,
               let url = URL(string: abstractURL) {
                results.append(SearchResult(
                    title: (json["Heading"] as? String) ?? query,
                    snippet: abstract,
                    url: url
                ))
            }

            if let relatedTopics = json["RelatedTopics"] as? [[String: Any]] {
                for topic in relatedTopics {
                    guard let text = topic["Text"] as? String, !text.isEmpty,
                          let firstURL = topic["FirstURL"] as? String, !firstURL.isEmpty,
                          let url = URL(string: firstURL) else { continue }
                    let title = text.components(separatedBy: " - ").first ?? text
                    results.append(SearchResult(title: title, snippet: text, url: url))
                }
            }

            let maxResults = min(results.count, 8)
            return Array(results.prefix(maxResults))
        } catch {
            return []
        }
    }

    private func searchHTML(query: String) async -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return [] }

            var results: [SearchResult] = []

            let pattern = try NSRegularExpression(
                pattern: "<a[^>]*class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>\\s*(.*?)\\s*<\\/a>",
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            )

            let snippetPattern = try NSRegularExpression(
                pattern: "<a[^>]*class=\"result__snippet\"[^>]*>\\s*(.*?)\\s*<\\/a>",
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            )

            let linkMatches = pattern.matches(in: html, range: NSRange(html.startIndex..., in: html))
            let snippetMatches = snippetPattern.matches(in: html, range: NSRange(html.startIndex..., in: html))

            for i in 0..<min(linkMatches.count, snippetMatches.count) {
                let linkMatch = linkMatches[i]
                let snippetMatch = snippetMatches[i]

                guard let hrefRange = Range(linkMatch.range(at: 1), in: html),
                      let titleRange = Range(linkMatch.range(at: 2), in: html),
                      let snippetRange = Range(snippetMatch.range(at: 1), in: html) else { continue }

                let href = String(html[hrefRange])
                let title = String(html[titleRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = String(html[snippetRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let resultURL = URL(string: href) else { continue }

                results.append(SearchResult(title: title, snippet: snippet, url: resultURL))
            }

            return Array(results.prefix(8))
        } catch {
            return []
        }
    }

    static func formatSearchResults(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        var text = "以下是来自网络的搜索结果，请基于这些信息以中文回答用户的问题：\n\n"
        for (i, result) in results.prefix(5).enumerated() {
            text += "**\(i + 1). \(result.title)**\n"
            text += "\(result.snippet)\n"
            text += "来源: \(result.url.absoluteString)\n\n"
        }
        return text
    }
}
