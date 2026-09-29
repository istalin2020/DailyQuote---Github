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
        let ud = UserDefaults.standard
        var stored = ud.integer(forKey: selectedKey)

        // Custom themes come after the built-ins, so adding built-ins shifts
        // their indices. Keep a saved custom selection pointing at the same theme.
        let builtinCountKey = "theme.builtinCount"
        let oldBuiltinCount = (ud.object(forKey: builtinCountKey) as? Int) ?? 50  // 50 before this key existed
        if stored >= oldBuiltinCount && oldBuiltinCount != ThemeCatalog.items.count {
            stored += ThemeCatalog.items.count - oldBuiltinCount
            ud.set(stored, forKey: selectedKey)   // didSet doesn't run during init
        }
        ud.set(ThemeCatalog.items.count, forKey: builtinCountKey)

        self.currentIndex = ThemeCatalog.clampedIndex(from: stored)

        // A custom theme file can be overwritten under the same path
        NotificationCenter.default.addObserver(forName: .customThemeCatalogChanged,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.cachedImage = nil
            self?.cachedLuminance = nil
        }
    }

    // MARK: - Caches
    // Views call these many times per redraw (the Home screen ~8x for its
    // text colour). Loading the image (a disk read + decode for custom
    // themes) and measuring its brightness each time made the Home screen
    // and every sheet over it slow, so both are cached per theme.
    private var cachedImage: (source: ThemeCatalog.Source, image: UIImage)?
    private var cachedLuminance: (source: ThemeCatalog.Source, value: CGFloat)?

    // MARK: - Helpers for backgrounds used across the app

    /// UIKit image for the current theme (nil if it can't be loaded)
    func currentUIImage() -> UIImage? {
        let source = currentItem.source
        if let c = cachedImage, c.source == source { return c.image }
        guard let img = ThemeCatalog.uiImage(for: currentItem) else { return nil }
        cachedImage = (source, img)
        return img
    }

    /// Average perceived brightness (0...1) of the current theme, cached.
    var currentLuminance: CGFloat {
        let source = currentItem.source
        if let c = cachedLuminance, c.source == source { return c.value }
        let value = currentUIImageOrFallback(size: CGSize(width: 800, height: 800)).averageLuminance ?? 0.5
        cachedLuminance = (source, value)
        return value
    }

    /// Always returns an image; if the current theme can't be loaded,
    /// a simple gradient fallback is rendered at the requested size.
    func currentUIImageOrFallback(size: CGSize) -> UIImage {
        if let img = currentUIImage() {
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

// MARK: - Daily random theme
extension ThemeState {
    private static let dailyDateKey = "theme.daily.date"   // "yyyy-MM-dd" of the last daily pick
    private static let dailyUsedKey = "theme.daily.used"   // themes already shown in this cycle

    private static let dailyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Once per day, switches the Home screen to a random theme
    /// (built-in themes and the user's own creations).
    /// - No theme repeats until every theme has been shown once.
    /// - Never the same theme two days in a row.
    /// - A theme picked by hand in the Theme window stays until the next day.
    /// Call on launch, when the app becomes active, and when the day changes.
    func applyDailyThemeIfNeeded(now: Date = Date()) {
        let ud = UserDefaults.standard
        let today = Self.dailyFormatter.string(from: now)
        guard ud.string(forKey: Self.dailyDateKey) != today else { return }

        let pool = ThemeCatalog.allItems
        guard !pool.isEmpty else { return }
        let currentKey = ThemeCatalog.encode(currentItem.source)

        var used = Set(ud.stringArray(forKey: Self.dailyUsedKey) ?? [])
        var candidates = pool.filter {
            let key = ThemeCatalog.encode($0.source)
            return key != currentKey && !used.contains(key)
        }
        if candidates.isEmpty {
            // Every theme has been shown: start a new cycle
            used = []
            candidates = pool.filter { ThemeCatalog.encode($0.source) != currentKey }
        }

        if let pick = candidates.randomElement() {
            used.insert(ThemeCatalog.encode(pick.source))
            apply(pick)
        }
        ud.set(today, forKey: Self.dailyDateKey)
        ud.set(Array(used), forKey: Self.dailyUsedKey)
    }
}
