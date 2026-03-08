import SwiftUI
import UIKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    var content: String
    var stats: GenerationStats?
}

struct ChatView: View {
    @EnvironmentObject var engine: LLMEngine
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var conversationStore: ConversationStore

    @Binding var activeConversationId: UUID?

    @StateObject private var speechRecognizer = SpeechRecognizer()

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var isSearching = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageArea
            Divider()
            inputBar
        }
        .background(Color(.systemBackground))
        .onTapGesture {
            inputFocused = false
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            ConversationListView(activeConversationId: $activeConversationId, showList: $showHistory)
        }
        .onChange(of: activeConversationId) {
            loadConversation()
        }
        .onAppear {
            loadConversation()
            preloadModelIfNeeded()
        }
    }

    private var header: some View {
        HStack {
            Button {
                showHistory = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Menu {
                let downloaded = AvailableModels.all.filter { modelManager.isDownloaded($0) }
                ForEach(downloaded) { model in
                    Button {
                        Task { try? await modelManager.activateModel(model) }
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if modelManager.isActive(model) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text(activeModelName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    saveCurrentConversation()
                    activeConversationId = nil
                    messages.removeAll()
                    engine.output = ""
                    engine.cancelGeneration()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 32)
                }

                Divider()
                    .frame(height: 16)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 32)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !engine.isGenerating && !engine.isLoading {
                    VStack(spacing: 12) {
                        Spacer(minLength: 120)
                        Text("4B")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.25))
                        Text("On-Device AI")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(activeModelName)
                                .font(.system(size: 12))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isSearching {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching the web...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .id("searching")
                        }

                        if engine.isGenerating {
                            if engine.output.isEmpty {
                                ThinkingIndicator()
                                    .id("streaming")
                            } else {
                                MessageBubble(
                                    message: ChatMessage(
                                        role: "assistant",
                                        content: engine.output,
                                        stats: nil
                                    )
                                )
                                .id("streaming")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: engine.output) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                speechRecognizer.toggleRecording()
            } label: {
                Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundStyle(speechRecognizer.isRecording ? .red : .secondary)
                    .frame(width: 30, height: 30)
            }

            TextField("Message...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .submitLabel(.send)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button {
                if engine.isGenerating {
                    engine.cancelGeneration()
                    finalizeAssistantMessage()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: engine.isGenerating ? "stop.fill" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(sendButtonColor)
                    .clipShape(Circle())
            }
            .disabled(engine.isLoading || (!engine.isGenerating && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: speechRecognizer.transcript) {
            if !speechRecognizer.transcript.isEmpty {
                inputText = speechRecognizer.transcript
            }
        }
        .onAppear {
            speechRecognizer.requestPermissions()
        }
    }

    private var sendButtonColor: Color {
        if engine.isGenerating { return .red }
        return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : .blue
    }

    private var activeModelName: String {
        if let id = modelManager.activeModelId,
           let model = AvailableModels.all.first(where: { $0.id == id }) {
            return model.displayName
        }
        if let first = AvailableModels.all.first(where: { modelManager.isDownloaded($0) }) {
            return first.displayName
        }
        return "No Model"
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        messages.append(ChatMessage(role: "user", content: text))
        inputText = ""

        Task {
            // Prefetch search results if needed (runs concurrently with model load)
            var searchContext: String?
            let shouldSearch = WebSearchService.hasAPIKey && SearchDetector.needsSearch(text)
            if shouldSearch { isSearching = true }

            async let searchTask: [SearchResult] = shouldSearch ? {
                let service = WebSearchService()
                return (try? await service.search(query: text)) ?? []
            }() : []

            if modelManager.activeModelId == nil {
                if let firstDownloaded = AvailableModels.all.first(where: { modelManager.isDownloaded($0) }) {
                    try? await modelManager.activateModel(firstDownloaded)
                }
            }

            let results = await searchTask
            if !results.isEmpty {
                searchContext = WebSearchService.formatResults(results)
            }
            isSearching = false

            let chatHistory = buildChatHistory(searchContext: searchContext)
            engine.generate(messages: chatHistory)

            while engine.isGenerating {
                try? await Task.sleep(for: .milliseconds(100))
            }
            finalizeAssistantMessage()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func finalizeAssistantMessage() {
        guard !engine.output.isEmpty else { return }
        messages.append(ChatMessage(
            role: "assistant",
            content: engine.output,
            stats: engine.stats
        ))
        engine.output = ""
        saveCurrentConversation()
    }

    private func saveCurrentConversation() {
        guard !messages.isEmpty else { return }

        if let existingId = activeConversationId,
           var existing = conversationStore.conversations.first(where: { $0.id == existingId }) {
            existing.messages = messages.map { SavedMessage(from: $0) }
            conversationStore.save(existing)
        } else {
            let conv = Conversation(messages: messages, modelId: modelManager.activeModelId)
            activeConversationId = conv.id
            conversationStore.save(conv)
        }
    }

    private func preloadModelIfNeeded() {
        guard modelManager.activeModelId == nil else { return }
        Task {
            if let first = AvailableModels.all.first(where: { modelManager.isDownloaded($0) }) {
                try? await modelManager.activateModel(first)
            }
        }
    }

    private func loadConversation() {
        if let id = activeConversationId,
           let conv = conversationStore.conversations.first(where: { $0.id == id }) {
            messages = conv.messages.map { $0.toChatMessage() }
        } else {
            messages = []
        }
        engine.output = ""
    }

    private func buildChatHistory(searchContext: String? = nil) -> [[String: String]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let today = dateFormatter.string(from: Date())

        var systemPrompt = "You are a helpful assistant running locally on an iPhone. Today is \(today). Answer directly and concisely. Never say you cannot access real-time data or the internet."

        if let context = searchContext {
            systemPrompt += "\n\nYou have real-time web search results below. Use them to answer the user's question. Do not ignore these results. Cite sources.\n\n\(context)"
        }

        var history: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in messages {
            history.append(["role": msg.role, "content": msg.content])
        }
        return history
    }
}
