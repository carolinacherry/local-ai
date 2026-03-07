import Foundation

struct SavedMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    var content: String
    var tokensPerSecond: Double?
    var timeToFirstToken: Double?
    var totalTokens: Int?

    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id
        self.role = chatMessage.role
        self.content = chatMessage.content
        self.tokensPerSecond = chatMessage.stats?.tokensPerSecond
        self.timeToFirstToken = chatMessage.stats?.timeToFirstToken
        self.totalTokens = chatMessage.stats?.totalTokens
    }

    var stats: GenerationStats? {
        guard let tps = tokensPerSecond, let ttft = timeToFirstToken, let total = totalTokens else {
            return nil
        }
        return GenerationStats(tokensPerSecond: tps, timeToFirstToken: ttft, totalTokens: total)
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(role: role, content: content, stats: stats)
    }
}

struct Conversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var messages: [SavedMessage]
    var modelId: String?
    var createdAt: Date
    var updatedAt: Date

    init(messages: [ChatMessage], modelId: String?) {
        self.id = UUID()
        self.title = messages.first(where: { $0.role == "user" })?.content
            .prefix(50)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "New Chat"
        self.messages = messages.map { SavedMessage(from: $0) }
        self.modelId = modelId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@MainActor
final class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []

    private let directory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadAll()
    }

    func save(_ conversation: Conversation) {
        var conv = conversation
        conv.updatedAt = Date()

        if let index = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[index] = conv
        } else {
            conversations.insert(conv, at: 0)
        }

        let file = directory.appendingPathComponent("\(conv.id.uuidString).json")
        if let data = try? JSONEncoder().encode(conv) {
            try? data.write(to: file)
        }
    }

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        let file = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
    }

    private func loadAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        conversations = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Conversation.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}
