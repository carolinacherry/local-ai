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

    /// Clean output: strips <think> tags for display
    var cleanOutput: String {
        stripThinkingTags(output)
    }

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

    func generate(messages: [[String: String]], enableThinking: Bool) {
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
                // Use container.perform to get access to tokenizer for enable_thinking
                let stream: AsyncStream<Generation> = try await container.perform { (context: ModelContext) in
                    // Apply chat template with enable_thinking parameter
                    let additionalContext: [String: Any] = [
                        "enable_thinking": enableThinking
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

                    let maxTokens = enableThinking ? 1200 : 512
                    let parameters = GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: enableThinking ? 0.6 : 0.7,
                        topP: enableThinking ? 0.95 : 0.8
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

                        // Check for repetition every 20 tokens
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

    /// Detect repetition loops. Returns trimmed output if repetition found, nil otherwise.
    private func detectRepetition(_ text: String) -> String? {
        let clean = stripThinkingTags(text)
        guard clean.count > 60 else { return nil }

        // Check if the last N characters repeat earlier in the text
        // Try different window sizes (15-40 chars)
        for windowSize in [40, 30, 20, 15] {
            guard clean.count > windowSize * 3 else { continue }

            let suffix = String(clean.suffix(windowSize))
            let searchArea = String(clean.dropLast(windowSize))

            // Count occurrences of this suffix in the text
            var count = 0
            var searchFrom = searchArea.startIndex
            while let range = searchArea.range(of: suffix, range: searchFrom..<searchArea.endIndex) {
                count += 1
                searchFrom = range.upperBound
                if count >= 2 { break }
            }

            // If the same chunk appears 3+ times total (2 in search + 1 suffix), it's repeating
            if count >= 2 {
                // Trim to first occurrence + one repetition
                if let firstRange = clean.range(of: suffix) {
                    let afterFirst = clean[firstRange.upperBound...]
                    if let secondRange = afterFirst.range(of: suffix) {
                        return String(clean[..<secondRange.upperBound])
                    }
                }
                return searchArea
            }
        }

        return nil
    }

    /// Strip <think>...</think> tags from output (Incept5 approach)
    private func stripThinkingTags(_ text: String) -> String {
        var result = text

        // 1. Strip complete <think>...</think> blocks
        let pattern = #"<think>[\s\S]*?</think>"#
        result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)

        // 2. Handle orphaned </think> — keep content after it
        if let closeRange = result.range(of: "</think>") {
            let after = String(result[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if after.count >= 2 {
                result = after
            } else {
                result = result.replacingOccurrences(of: "</think>", with: "")
            }
        }

        // 3. Handle orphaned <think> — keep content before it (still streaming)
        if let openRange = result.range(of: "<think>") {
            let before = String(result[..<openRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if before.count >= 2 {
                result = before
            } else {
                // Still in thinking phase, return empty
                return ""
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
