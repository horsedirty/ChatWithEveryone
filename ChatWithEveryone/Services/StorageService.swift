import Foundation

final class StorageService: @unchecked Sendable {
    static let shared = StorageService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var providersURL: URL {
        appSupportURL.appendingPathComponent("providers.json")
    }

    private var sessionsURL: URL {
        appSupportURL.appendingPathComponent("sessions.json")
    }

    private var imagesDirectoryURL: URL {
        let dir = appSupportURL.appendingPathComponent("images")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var appSupportURL: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChatWithEveryone")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadProviders() -> [APIProvider] {
        guard let data = try? Data(contentsOf: providersURL),
              let providers = try? decoder.decode([APIProvider].self, from: data) else {
            return []
        }
        return providers
    }

    func saveProviders(_ providers: [APIProvider]) {
        guard let data = try? encoder.encode(providers) else { return }
        try? data.write(to: providersURL)
    }

    func loadSessions() -> [ChatSession] {
        guard let data = try? Data(contentsOf: sessionsURL),
              let sessions = try? decoder.decode([ChatSession].self, from: data) else {
            return [ChatSession(title: "新对话")]
        }
        return sessions.isEmpty ? [ChatSession(title: "新对话")] : sessions
    }

    func saveSessions(_ sessions: [ChatSession]) {
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: sessionsURL)
    }

    func saveImage(_ imageData: Data, id: UUID) -> String {
        let filename = "\(id.uuidString).jpg"
        let url = imagesDirectoryURL.appendingPathComponent(filename)
        try? imageData.write(to: url)
        return url.path
    }

    func loadImageData(at path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    func deleteImage(at path: String) {
        try? fileManager.removeItem(atPath: path)
    }
}
