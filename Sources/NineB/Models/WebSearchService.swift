import Foundation

struct SearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
}

actor WebSearchService {
    private static let keychainKey = "brave_search_api_key"

    static var hasAPIKey: Bool {
        KeychainHelper.load(key: keychainKey) != nil
    }

    static func saveAPIKey(_ key: String) {
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeychainHelper.delete(key: keychainKey)
        } else {
            KeychainHelper.save(key: keychainKey, value: key.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    static func loadAPIKey() -> String? {
        KeychainHelper.load(key: keychainKey)
    }

    func search(query: String) async throws -> [SearchResult] {
        guard let apiKey = Self.loadAPIKey() else { return [] }

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.search.brave.com/res/v1/web/search?q=\(encoded)&count=5") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let web = json["web"] as? [String: Any],
              let results = web["results"] as? [[String: Any]] else {
            return []
        }

        return results.prefix(5).compactMap { item in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }
            let snippet = item["description"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }

    /// Format search results as context for the system prompt.
    static func formatResults(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        var lines = ["[Web Search Results]"]
        for (i, r) in results.enumerated() {
            lines.append("\(i + 1). \(r.title)")
            if !r.snippet.isEmpty {
                lines.append("   \(r.snippet)")
            }
            lines.append("   Source: \(r.url)")
        }
        lines.append("[End of Search Results]")
        return lines.joined(separator: "\n")
    }
}
