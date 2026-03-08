import Foundation
import MLX
import MLXLLM
import MLXLMCommon

struct GenerationStats {
    let tokensPerSecond: Double
    let timeToFirstToken: Double
    let totalTokens: Int
}

@MainActor
final class LLMEngine: ObservableObject {
    @Published var output = ""
    @Published var isGenerating = false
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    @Published var stats: GenerationStats?
    @Published var stoppedByRepetition = false

    private var modelContainer: ModelContainer?
    private var generateTask: Task<Void, Never>?
    private(set) var activeModel: ModelConfig?

    func loadModel(_ config: ModelConfig) async throws {
        isLoading = true
        loadingProgress = 0
        defer { isLoading = false }

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let modelConfig = ModelConfiguration(id: config.huggingFaceRepo)

        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfig
        ) { [weak self] progress in
            Task { @MainActor in
                self?.loadingProgress = progress.fractionCompleted
            }
        }

        activeModel = config
    }

    func generate(messages: [[String: String]]) {
        guard let container = modelContainer else { return }
        guard !isGenerating else { return }

        isGenerating = true
        output = ""
        stats = nil
        stoppedByRepetition = false

        generateTask = Task {
            let ttftStart = Date()
            var firstTokenReceived = false
            var ttft: Double = 0
            var tokenCount = 0

            do {
                let stream: AsyncStream<Generation> = try await container.perform { (context: ModelContext) in
                    let additionalContext: [String: Any] = [
                        "enable_thinking": false
                    ]

                    let promptTokens = try context.tokenizer.applyChatTemplate(
                        messages: messages,
                        chatTemplate: nil,
                        addGenerationPrompt: true,
                        truncation: false,
                        maxLength: nil,
                        tools: nil,
                        additionalContext: additionalContext
                    )

                    let input = LMInput(tokens: MLXArray(promptTokens))

                    let parameters = GenerateParameters(
                        maxTokens: 512,
                        temperature: 0.7,
                        topP: 0.8
                    )

                    return try MLXLMCommon.generate(
                        input: input,
                        parameters: parameters,
                        context: context
                    )
                }

                for await generation in stream {
                    if Task.isCancelled { break }

                    switch generation {
                    case .chunk(let text):
                        if !firstTokenReceived {
                            ttft = Date().timeIntervalSince(ttftStart)
                            firstTokenReceived = true
                        }
                        tokenCount += 1
                        output += text

                        if tokenCount % 20 == 0, let trimmed = detectRepetition(output) {
                            output = trimmed
                            stoppedByRepetition = true
                            break
                        }

                    case .info(let info):
                        stats = GenerationStats(
                            tokensPerSecond: info.tokensPerSecond,
                            timeToFirstToken: ttft,
                            totalTokens: info.generationTokenCount
                        )

                    default:
                        break
                    }

                    if stoppedByRepetition { break }
                }

                if stats == nil {
                    let elapsed = Date().timeIntervalSince(ttftStart)
                    stats = GenerationStats(
                        tokensPerSecond: elapsed > 0 ? Double(tokenCount) / elapsed : 0,
                        timeToFirstToken: ttft,
                        totalTokens: tokenCount
                    )
                }
            } catch {
                if !Task.isCancelled {
                    output += "\n[Error: \(error.localizedDescription)]"
                }
            }

            isGenerating = false
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    private func detectRepetition(_ text: String) -> String? {
        guard text.count > 60 else { return nil }

        for windowSize in [40, 30, 20, 15] {
            guard text.count > windowSize * 3 else { continue }

            let suffix = String(text.suffix(windowSize))
            let searchArea = String(text.dropLast(windowSize))

            var count = 0
            var searchFrom = searchArea.startIndex
            while let range = searchArea.range(of: suffix, range: searchFrom..<searchArea.endIndex) {
                count += 1
                searchFrom = range.upperBound
                if count >= 2 { break }
            }

            if count >= 2 {
                if let firstRange = text.range(of: suffix) {
                    let afterFirst = text[firstRange.upperBound...]
                    if let secondRange = afterFirst.range(of: suffix) {
                        return String(text[..<secondRange.upperBound])
                    }
                }
                return searchArea
            }
        }

        return nil
    }
}
