// AIQuoteService.swift
import Foundation

// The model we pass around
struct QuoteResult: Codable, Equatable {
    let quote: String
    let author: String?
    let book: String?
}

@MainActor
final class AIQuoteService {
    static let shared = AIQuoteService()

    // Configure your Worker URL here (no trailing slash)
    private let baseURL = URL(string: "https://dqr-ai-proxy.istalin.workers.dev")!

    private init() {}

    /// Calls your Cloudflare Worker and returns a QuoteResult.
    /// - Parameters:
    ///   - prompt: the user's prompt
    ///   - recent: a few recent quotes to avoid duplicates
    func generateQuote(prompt: String, recent: [String]) async throws -> QuoteResult {
            var req = URLRequest(url: baseURL.appendingPathComponent("/quote"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "prompt": prompt,
                "recent": recent
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Server error"
                throw NSError(domain: "AIQuoteService", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }

            // Response can be {"quote": "...", "author": "..."/null, "book": "..."/null}
            let result = try JSONDecoder().decode(QuoteResult.self, from: data)
            return result
        }
    }
