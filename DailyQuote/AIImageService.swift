import Foundation
import UIKit

// MARK: - Public error type for UI
enum AIImageError: LocalizedError {
    case badURL
    case noHTTPResponse
    case requestFailed(status: Int, details: String?)
    case decode
    case noImagePayload
    case base64DecodeFailed
    case uiImageInitFailed

    var errorDescription: String? {
        switch self {
        case .badURL:                    return "Invalid image service URL."
        case .noHTTPResponse:            return "No HTTP response from server."
        case .requestFailed(let s, let d):
            return "Image generation failed (\(s)). \(d ?? "")"
        case .decode:                    return "Couldn’t parse server response."
        case .noImagePayload:            return "Server didn’t return image data."
        case .base64DecodeFailed:        return "Couldn’t decode image data."
        case .uiImageInitFailed:         return "Couldn’t construct image."
        }
    }
}

// MARK: - Response models (cover both Worker and OpenAI-like shapes)
private struct WorkerImageResponse: Decodable { let image_b64: String? }
private struct OpenAIImageResponse: Decodable {
    struct Datum: Decodable { let b64_json: String?; let url: String? }
    struct APIError: Decodable { let message: String? }
    let data: [Datum]?
    let error: APIError?
}

struct AIImageService {
    static let shared = AIImageService()

    // CHANGE if your Worker lives elsewhere (no trailing slash)
    private let baseURL = URL(string: "https://dqr-ai-proxy.istalin.workers.dev")!

    // Preferred portrait wallpaper size for phones.
    // gpt-image-1 supports: 1024x1024, 1024x1792, 1792x1024.
    // We use the tallest portrait option for the best phone wallpaper quality.
    private let defaultSize = "1024x1792"
    // OpenAI current image model
    private let model = "gpt-image-1"
    // Request high quality from the API
    private let quality = "high"

    // MARK: - Public API

    /// Generate an image for `prompt`.
    /// Tries a standards-style body first (model/prompt/size/n),
    /// then falls back to legacy `{ "prompt": ... }` if the Worker expects that.
    func generateImage(prompt: String, size: String? = nil) async throws -> UIImage {
        let resolvedSize = size ?? defaultSize
        // 1) Try "modern" JSON body that most proxies accept
        do {
            return try await requestImage(
                path: "image",
                json: [
                    "model": model,
                    "prompt": prompt,
                    "n": 1,
                    "size": resolvedSize,
                    "quality": quality
                ]
            )
        } catch let err as AIImageError {
            // If the first attempt fails due to strict schema on your Worker,
            // retry with the legacy body including size so we still get portrait
            switch err {
            case .requestFailed(let status, _)
                 where status == 400 || status == 404 || status == 422:
                return try await requestImage(
                    path: "image",
                    json: [
                        "prompt": prompt,
                        "size": resolvedSize,
                        "quality": quality
                    ]
                )
            default:
                throw err
            }
        } catch {
            // Non-AIImageError (e.g., transport) → try legacy once, still with size
            return try await requestImage(
                path: "image",
                json: [
                    "prompt": prompt,
                    "size": resolvedSize,
                    "quality": quality
                ]
            )
        }
    }

    // MARK: - Core request/parse

    private func requestImage(path: String, json: [String: Any]) async throws -> UIImage {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Optional: helps CORS rules on Worker side
        req.setValue(Bundle.main.bundleIdentifier ?? "app", forHTTPHeaderField: "Origin")
        req.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIImageError.noHTTPResponse }

        guard (200...299).contains(http.statusCode) else {
            let details = String(data: data, encoding: .utf8)
            // If the Worker passed through OpenAI’s error JSON, try to extract message
            if
                let detailsData = details?.data(using: .utf8),
                let openAI = try? JSONDecoder().decode(OpenAIImageResponse.self, from: detailsData),
                let msg = openAI.error?.message, !msg.isEmpty
            {
                throw AIImageError.requestFailed(status: http.statusCode, details: msg)
            }
            throw AIImageError.requestFailed(status: http.statusCode, details: details)
        }

        // Try decoding known shapes in order of likelihood
        // 1) Your Worker’s `{ "image_b64": ... }`
        if let worker = try? JSONDecoder().decode(WorkerImageResponse.self, from: data),
           let b64 = worker.image_b64, let ui = try? b64ToImage(b64) {
            return ui
        }

        // 2) OpenAI standard `{ data: [ { b64_json: ... } ] }`
        if let openAI = try? JSONDecoder().decode(OpenAIImageResponse.self, from: data),
           let b64 = openAI.data?.first?.b64_json, let ui = try? b64ToImage(b64) {
            return ui
        }

        // 3) Minimal forms like `{ "b64_json": "..." }` or `{ "image": "..." }`
        if
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let b64 = (obj["b64_json"] as? String) ?? (obj["image"] as? String),
            let ui = try? b64ToImage(b64)
        {
            return ui
        }

        throw AIImageError.noImagePayload
    }

    // MARK: - Helpers

    private func b64ToImage(_ b64: String) throws -> UIImage {
        guard let decoded = Data(base64Encoded: b64) else { throw AIImageError.base64DecodeFailed }
        guard let image = UIImage(data: decoded) else { throw AIImageError.uiImageInitFailed }
        return image
    }
}

// Small utility you can reuse anywhere to make a thumbnail that matches your grid tiles.
func makeThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = UIScreen.main.scale
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
        let aspect = image.size.width / image.size.height
        let targetAspect = targetSize.width / targetSize.height
        var rect = CGRect(origin: .zero, size: targetSize)
        if aspect > targetAspect {
            let newW = targetSize.height * aspect
            rect.origin.x = (targetSize.width - newW) / 2
            rect.size.width = newW
        } else {
            let newH = targetSize.width / aspect
            rect.origin.y = (targetSize.height - newH) / 2
            rect.size.height = newH
        }
        image.draw(in: rect)
    }
}
