import UIKit
import ImageIO

/// Small, pre-decoded thumbnails for the theme grid.
///
/// The built-in themes are full 1024x1536 PNGs (2-3 MB each). Drawing them
/// directly in 120-220pt tiles made SwiftUI decode every full image on the
/// main thread while scrolling. Thumbnails are decoded once, off the main
/// thread, at tile size and kept in memory.
final class ThemeThumbnailCache {
    static let shared = ThemeThumbnailCache()

    /// Longest side in pixels. Tiles are at most ~330pt tall; 720px stays
    /// sharp on typical 2-column phone layouts at a fraction of the memory.
    static let maxPixel = 720

    private let cache = ImageCache(costLimit: 80 * 1024 * 1024) // bytes of decoded bitmaps
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "theme.thumbnails"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 2
        return q
    }()

    private init() {}

    private func key(for source: ThemeCatalog.Source) -> String {
        ThemeCatalog.encode(source)
    }

    /// Returns the thumbnail immediately if it has already been made.
    func cached(_ source: ThemeCatalog.Source) -> UIImage? {
        cache.image(forKey: key(for: source))
    }

    /// Returns the thumbnail, decoding it on a background queue if needed.
    func thumbnail(for source: ThemeCatalog.Source) async -> UIImage? {
        let k = key(for: source)
        if let hit = cache.image(forKey: k) { return hit }

        return await withCheckedContinuation { continuation in
            queue.addOperation { [cache] in
                if let hit = cache.image(forKey: k) {
                    continuation.resume(returning: hit)
                    return
                }
                let img = Self.makeThumbnail(for: source)
                if let img {
                    let px = img.size.width * img.scale * img.size.height * img.scale
                    cache.set(img, forKey: k, cost: Int(px) * 4)
                }
                continuation.resume(returning: img)
            }
        }
    }

    /// Drop a thumbnail (e.g. when a custom theme file is overwritten).
    func remove(_ source: ThemeCatalog.Source) {
        cache.remove(forKey: key(for: source))
    }

    // MARK: - Decoding

    private static func makeThumbnail(for source: ThemeCatalog.Source) -> UIImage? {
        switch source {
        case .file(let path):
            // ImageIO decodes straight to the small size without ever
            // decoding the full-resolution bitmap.
            let url = URL(fileURLWithPath: path) as CFURL
            guard let src = CGImageSourceCreateWithURL(url, [kCGImageSourceShouldCache: false] as CFDictionary) else {
                return nil
            }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)

        case .asset(let name):
            // Asset-catalog images have no file URL, so load and downscale.
            guard let full = UIImage(named: name) else { return nil }
            let pxW = full.size.width * full.scale
            let pxH = full.size.height * full.scale
            let ratio = min(1, CGFloat(maxPixel) / max(pxW, pxH))
            let target = CGSize(width: (pxW * ratio).rounded(), height: (pxH * ratio).rounded())
            // preparingThumbnail returns a decoded bitmap, ready to draw.
            return full.preparingThumbnail(of: target)
        }
    }
}

/// NSCache is documented as thread-safe, so sharing it with the background
/// decode operations is safe; this wrapper tells the compiler so (and uses
/// Sendable String keys instead of NSString).
private final class ImageCache: @unchecked Sendable {
    private let storage = NSCache<NSString, UIImage>()

    init(costLimit: Int) {
        storage.totalCostLimit = costLimit
    }

    func image(forKey key: String) -> UIImage? {
        storage.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String, cost: Int) {
        storage.setObject(image, forKey: key as NSString, cost: cost)
    }

    func remove(forKey key: String) {
        storage.removeObject(forKey: key as NSString)
    }
}
