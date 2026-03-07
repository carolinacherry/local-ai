import SwiftUI

struct ParsedContent {
    let thinking: String?
    let response: String

    init(raw: String) {
        // Strip <think>...</think> blocks
        let thinkPattern = #"<think>([\s\S]*?)</think>"#
        if let match = raw.range(of: thinkPattern, options: .regularExpression) {
            let thinkTag = raw[match]
            let inner = thinkTag
                .replacingOccurrences(of: "<think>", with: "")
                .replacingOccurrences(of: "</think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            thinking = inner.isEmpty ? nil : inner

            var remainder = raw
            remainder.removeSubrange(match)
            response = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if raw.contains("<think>") {
            let parts = raw.components(separatedBy: "<think>")
            let before = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let thinkContent = parts.dropFirst().joined(separator: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            thinking = thinkContent.isEmpty ? nil : thinkContent
            response = before
        } else {
            // Also detect plain-text reasoning and strip it
            var cleaned = raw
            let reasoningPatterns = [
                #"(?s)Thinking Process:.*?(?=\n\n[A-Z]|\n\n\*\*[^*]|\z)"#,
                #"(?s)^Thinking:.*?(?=\n\n[A-Z]|\n\n\*\*[^*]|\z)"#,
            ]
            for pattern in reasoningPatterns {
                cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

            // If we stripped reasoning and there's content left, use it
            if trimmed != raw.trimmingCharacters(in: .whitespacesAndNewlines) {
                thinking = nil
                response = trimmed
            } else {
                thinking = nil
                response = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    @State private var showThinking = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top) {
            if message.role == "user" { Spacer(minLength: 60) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                if message.role == "user" {
                    userBubble
                } else {
                    assistantBubble
                }
            }

            if message.role != "user" { Spacer(minLength: 16) }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var assistantBubble: some View {
        let parsed = ParsedContent(raw: message.content)

        return VStack(alignment: .leading, spacing: 4) {
            if let thinking = parsed.thinking {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showThinking.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "brain")
                            .font(.system(size: 10))
                        Text(showThinking ? "Hide thinking" : "Show thinking")
                            .font(.system(size: 11))
                        Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }

                if showThinking {
                    Text(thinking)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if !parsed.response.isEmpty {
                Text(LocalizedStringKey(parsed.response))
                    .font(.system(size: 15))
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = parsed.response
                        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            if copied {
                                Text("Copied")
                                    .font(.system(size: 11))
                            }
                        }
                        .foregroundStyle(copied ? .green : Color(.systemGray3))
                    }

                    if let stats = message.stats {
                        StatsBar(stats: stats)
                    }
                }
            } else if parsed.thinking != nil {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Thinking...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                        .opacity(i <= dotCount ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 3
            }

            Spacer(minLength: 60)
        }
    }
}

struct StatsBar: View {
    let stats: GenerationStats

    var body: some View {
        HStack(spacing: 6) {
            Text("\(String(format: "%.1f", stats.tokensPerSecond)) tok/s")
            Text("\(stats.totalTokens) tokens")
            Text(String(format: "%.1fs total", Double(stats.totalTokens) / max(stats.tokensPerSecond, 0.1)))
            Text(String(format: "%.2fs TTFT", stats.timeToFirstToken))
        }
        .font(.system(size: 10))
        .foregroundStyle(Color(.systemGray3))
    }
}
