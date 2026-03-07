import Foundation

enum SearchDetector {
    /// Returns true if the prompt likely needs web search results for a good answer.
    static func needsSearch(_ text: String) -> Bool {
        let lower = text.lowercased()

        // URL detection — user pasted a link
        if lower.range(of: #"https?://"#, options: .regularExpression) != nil { return true }
        if lower.contains("www.") { return true }

        // Temporal keywords — asking about current/recent info
        let temporal = ["today", "latest", "current", "currently", "right now",
                        "this week", "this month", "this year", "yesterday",
                        "recent", "recently", "2025", "2026"]
        for keyword in temporal {
            if lower.contains(keyword) { return true }
        }

        // Info-seeking patterns
        let patterns = [
            "who is", "who are", "who was", "who won",
            "what happened", "what is the price", "how much does", "how much is",
            "price of", "stock price", "market cap",
            "weather in", "weather for", "forecast",
            "news about", "latest news", "breaking",
            "score of", "game score", "match result",
            "release date", "when does", "when did", "when will",
            "search for", "look up", "google",
        ]
        for pattern in patterns {
            if lower.contains(pattern) { return true }
        }

        return false
    }
}
