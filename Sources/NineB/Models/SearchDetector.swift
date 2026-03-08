import Foundation

enum SearchDetector {
    /// Returns true if the prompt likely benefits from web search results.
    /// Strategy: search by default for most questions. Only skip for clearly
    /// conversational, creative, or instructional prompts that don't need fresh data.
    static func needsSearch(_ text: String) -> Bool {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Very short messages (greetings, single words) — skip search
        if lower.count < 10 { return false }

        // Skip search for creative/instructional tasks that don't need web data
        let skipPatterns = [
            "write me", "write a", "compose", "draft",
            "explain how", "explain what", "explain why", "explain the",
            "teach me", "help me understand",
            "translate", "convert",
            "summarize this", "rewrite this", "rephrase",
            "tell me a joke", "tell me a story",
            "code a", "code for", "write code", "build a",
            "calculate", "solve", "compute",
            "list the steps", "how do i cook", "recipe for",
            "what does the word", "define ",
            "hello", "hi ", "hey ", "thanks", "thank you", "goodbye",
        ]
        for pattern in skipPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) {
                // But if it also has location/entity markers, still search
                let forceSearch = ["in ", "near", "at ", "for ", "about ", "address",
                                   "price", "cost", "review", "best", "top", "open"]
                for force in forceSearch {
                    if lower.contains(force) { return true }
                }
                return false
            }
        }

        // Everything else: search. Most user questions benefit from fresh data.
        return true
    }
}
