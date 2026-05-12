import SwiftUI
import UIKit

final class ThemeState: ObservableObject {
    static let shared = ThemeState()

    private let selectedKey = "selectedThemeIndex"

    // Persisted selection
    @Published var currentIndex: Int {
        didSet {
            // Clamp & persist on the main queue to avoid re-entrancy warnings
            let clamped = ThemeCatalog.clampedIndex(from: currentIndex)
            if clamped != currentIndex {
                DispatchQueue.main.async { [weak self] in
                    self?.currentIndex = clamped
                }
            }
            UserDefaults.standard.set(clamped, forKey: selectedKey)
        }
    }

    // MARK: - Current item (always valid)
    var currentItem: ThemeCatalog.Item {
        let idx = ThemeCatalog.clampedIndex(from: currentIndex)
        return ThemeCatalog.allItems[safe: idx] ?? ThemeCatalog.items[0]
    }

    /// Is the current theme a user-created (file) image?
    var isUsingCustomImage: Bool {
        if case .file = currentItem.source { return true }
        return false
    }

    // MARK: - Init
    private init() {
        let stored = UserDefaults.standard.integer(forKey: selectedKey)
        self.currentIndex = ThemeCatalog.clampedIndex(from: stored)
    }

    // MARK: - Helpers for backgrounds used across the app

    /// UIKit image for the current theme (nil if it can't be loaded)
    func currentUIImage() -> UIImage? {
        ThemeCatalog.uiImage(for: currentItem)
    }

    /// Always returns an image; if the current theme can't be loaded,
    /// a simple gradient fallback is rendered at the requested size.
    func currentUIImageOrFallback(size: CGSize) -> UIImage {
        if let img = ThemeCatalog.uiImage(for: currentItem) {
            return img // return original file, not a resized thumbnail
        }

        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(white: 0.92, alpha: 1).cgColor,
                UIColor(white: 0.78, alpha: 1).cgColor
            ] as CFArray
            let sp = CGColorSpaceCreateDeviceRGB()
            let g  = CGGradient(colorsSpace: sp, colors: colors, locations: [0, 1])!
            cg.drawLinearGradient(g,
                                  start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: 0, y: size.height),
                                  options: [])
        }
    }

    /// Apply a specific catalog item as the current theme.
    func apply(_ item: ThemeCatalog.Item) {
        if let idx = ThemeCatalog.allItems.firstIndex(of: item) {
            currentIndex = ThemeCatalog.clampedIndex(from: idx)
        }
    }
}

// Safe subscript (unchanged)
extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - First-run default theme seed
extension ThemeState {
    /// Change this if you ever want a different first-run default.
    private static let defaultThemeName = "Dawn Glow"
    /// Guard so we never override returning users.
    private static let seedKey = "dq.hasSeededDefaultTheme_1"

    /// Call this once at app start. If no selection has been made before,
    /// we set "Dawn Glow" as the current theme and remember that we seeded.
    func seedDefaultThemeIfNeeded() {
        let ud = UserDefaults.standard
        guard ud.bool(forKey: Self.seedKey) == false else { return }

        // Find "Dawn Glow" from your catalog.
        // Replace `allItems` with your actual collection if it has a different name
        // (e.g. `builtins`, `all`, `prebuilts`, etc.)
        if let dawn = ThemeCatalog.allItems.first(where: { $0.displayName == Self.defaultThemeName }) {
            // Your existing method already persists the selection.
            self.apply(dawn)
        } else if let fallback = ThemeCatalog.allItems.first {
            self.apply(fallback)
        }

        ud.set(true, forKey: Self.seedKey)
    }
}

