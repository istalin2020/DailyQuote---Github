import SwiftUI
import UIKit

enum ThemeCatalog {

    // MARK: - Cache for custom items
    // We no longer recompute customs on every access to `allItems`.
    private static var cachedCustoms: [Item] = loadCustomsOnce()
    
    // Public read-only accessor to the cached customs
    static var customs: [Item] { cachedCustoms }

    static var allItems: [Item] { items + cachedCustoms }
    static var names: [String] { allItems.map { $0.displayName } }
    static func name(for index: Int) -> String {
        let i = max(0, min(index, allItems.count - 1))
        return allItems[i].displayName
    }
    static var count: Int { allItems.count }
    static func clampedIndex(from stored: Int) -> Int {
        max(0, min(stored, allItems.count - 1))
    }

    // MARK: - Types
    enum Category: String, CaseIterable, Identifiable, Hashable {
        case all = "All"
        case nature = "Nature"
        case artistic = "Artistic"
        case beautiful = "Beautiful"
        case monuments = "Monuments"
        var id: String { rawValue }
    }

    enum Source: Hashable {
        case asset(String)   // asset catalog name
        case file(String)    // absolute path in Documents
    }

    struct Item: Identifiable, Equatable, Hashable {
        let id = UUID()
        let displayName: String
        let category: Category
        let source: Source
    }

    // MARK: - Built-in items (unchanged)
    static let items: [Item] = [
        Item(displayName: "Dawn Glow",     category: .beautiful, source: .asset("theme1")),
        Item(displayName: "Night Sky",     category: .nature,    source: .asset("theme2")),
        Item(displayName: "Mountain Mist", category: .nature,    source: .asset("theme3")),
        Item(displayName: "Coastal Blue",  category: .nature,    source: .asset("theme4")),
        Item(displayName: "Neon Spires",   category: .beautiful, source: .asset("theme5")),
        Item(displayName: "Amber Bokeh",   category: .beautiful, source: .asset("theme6")),
        Item(displayName: "Golden Horizon",category: .nature,    source: .asset("theme7")),
        Item(displayName: "Aurora Veil",   category: .nature,    source: .asset("theme8")),
        Item(displayName: "City Neon",     category: .beautiful, source: .asset("theme9")),
        Item(displayName: "Dune Sunset",   category: .nature,    source: .asset("theme10")),
        Item(displayName: "Calm Water",    category: .nature,    source: .asset("theme11")),
        Item(displayName: "Warm Dunes",    category: .beautiful, source: .asset("theme12")),
        Item(displayName: "Sun Disk",      category: .nature,    source: .asset("theme13")),
        Item(displayName: "Canvas Lines",  category: .beautiful, source: .asset("theme14")),
        Item(displayName: "Dark",          category: .beautiful, source: .asset("theme15")),
        Item(displayName: "Peach Skies",   category: .beautiful, source: .asset("theme16")),
        Item(displayName: "Green Meadow",  category: .beautiful, source: .asset("theme17")),
        Item(displayName: "Turquoise Sea", category: .nature,    source: .asset("theme18")),
        Item(displayName: "Midnight Peaks",category: .nature,    source: .asset("theme19")),
        Item(displayName: "Lavender Field",category: .nature,    source: .asset("theme20")),
        Item(displayName: "Blossom",       category: .beautiful, source: .asset("theme21")),
        Item(displayName: "Lotus",         category: .beautiful, source: .asset("theme22")),
        Item(displayName: "Sunflowers",    category: .beautiful, source: .asset("theme23")),
        Item(displayName: "Coral Beads",   category: .beautiful, source: .asset("theme24")),
        Item(displayName: "Rose Blush",    category: .beautiful, source: .asset("theme25")),
        Item(displayName: "Super Heroes",  category: .artistic,  source: .asset("theme26")),
        Item(displayName: "Knowledge",     category: .artistic,  source: .asset("theme27")),
        Item(displayName: "Monk",          category: .artistic,  source: .asset("theme28")),
        Item(displayName: "Shepherd",      category: .artistic,  source: .asset("theme29")),
        Item(displayName: "Library",       category: .artistic,  source: .asset("theme30")),
        Item(displayName: "Victory",       category: .artistic,  source: .asset("theme31")),
        Item(displayName: "Golden Wreath", category: .artistic,  source: .asset("theme32")),
        Item(displayName: "Triumph",       category: .artistic,  source: .asset("theme33")),
        Item(displayName: "Breaking Through", category: .artistic, source: .asset("theme34")),
        Item(displayName: "Rays of Light", category: .artistic,  source: .asset("theme35")),
        Item(displayName: "Artist",        category: .artistic,  source: .asset("theme36")),
        Item(displayName: "Snowy Mountain",category: .artistic,  source: .asset("theme37")),
        Item(displayName: "Cherry Blossom",category: .beautiful,  source: .asset("theme38")),
        Item(displayName: "Sunset Ocean",  category: .nature,    source: .asset("theme39")),
        Item(displayName: "Waterfall",     category: .beautiful, source: .asset("theme40")),
        Item(displayName: "Night Sky II",  category: .nature,    source: .asset("theme41")),
        Item(displayName: "Autumn",        category: .beautiful, source: .asset("theme42")),
        Item(displayName: "Desert",        category: .nature,    source: .asset("theme43")),
        Item(displayName: "Lavender II",   category: .beautiful, source: .asset("theme44")),
        Item(displayName: "Hot Air Balloons", category: .beautiful, source: .asset("theme45")),
        Item(displayName: "Taj Mahal",     category: .monuments, source: .asset("theme46")),
        Item(displayName: "Eiffel Tower",  category: .monuments, source: .asset("theme47")),
        Item(displayName: "Great Wall",    category: .monuments, source: .asset("theme48")),
        Item(displayName: "Pyramid",       category: .monuments, source: .asset("theme49")),
        Item(displayName: "Colosseum",     category: .monuments, source: .asset("theme50")),
        Item(displayName: "Rose Watercolor", category: .beautiful, source: .asset("theme51")),
        Item(displayName: "Misty Sunrise", category: .nature,    source: .asset("theme52")),
        Item(displayName: "Olive Light",   category: .beautiful, source: .asset("theme53")),
        Item(displayName: "Starry Horizon",category: .nature,    source: .asset("theme54")),
        Item(displayName: "Turquoise Shore", category: .nature,  source: .asset("theme55")),
        // Always append new built-ins at the end; ThemeState shifts saved
        // custom-theme indices by the number of built-ins added.
    ]

    // MARK: - Persistence for customs
    private static let CUSTOMS_KEY = "customThemePaths"

    /// Append if not already present, update cache, then notify UI.
    static func appendCustomPath(_ path: String) {
        var arr = UserDefaults.standard.stringArray(forKey: CUSTOMS_KEY) ?? []
        if !arr.contains(path) { arr.append(path) }
        UserDefaults.standard.set(arr, forKey: CUSTOMS_KEY)

        // The file may have been overwritten under the same name
        ThemeThumbnailCache.shared.remove(.file(path))

        // Refresh cache once, not on every access
        cachedCustoms = loadCustomsUnsafe()

        NotificationCenter.default.post(name: .customThemeCatalogChanged, object: nil)
    }

    /// Force-reload the cached customs (call this on app start or when you detect changes).
    static func reloadCustoms() {
        cachedCustoms = loadCustomsUnsafe()
    }

    // Old public function replaced by the cache. Keep private unsafe loader.
    private static func loadCustomsOnce() -> [Item] {
        loadCustomsUnsafe()
    }

    /// Read from disk/user defaults; no notifications; no side effects.
    private static func loadCustomsUnsafe() -> [Item] {
        let paths = UserDefaults.standard.stringArray(forKey: CUSTOMS_KEY) ?? []
        return paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return Item(displayName: shortName(from: name),
                        category: .beautiful,
                        source: .file(path))
        }
    }
    
    @discardableResult
    static func savePNG(image: UIImage, filename: String) -> String? {
        // Save the AI image at its original resolution (1024x1792 from the API).
        // No re-rendering or upscaling — preserves every pixel of quality.
        let safe = filename
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
            .prefix(32)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("\(safe).png")

        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            print("❌ Save error:", error)
            return nil
        }
    }


    // MARK: - Image providers for SwiftUI
    static func image(for item: Item) -> Image {
        switch item.source {
        case .asset(let name):
            return Image(name)
        case .file(let path):
            if let ui = UIImage(contentsOfFile: path) {
                return Image(uiImage: ui)
            } else {
                return Image(systemName: "photo")
            }
        }
    }

    // MARK: - Selection persistence (unchanged)
    static let CURRENT_KEY = "theme.current.source"

    static func encode(_ s: Source) -> String {
        switch s {
        case .asset(let n): return "asset:\(n)"
        case .file(let p):  return "file:\(p)"
        }
    }
    static func decodeSource(_ raw: String) -> Source? {
        if raw.hasPrefix("asset:") { return .asset(String(raw.dropFirst(6))) }
        if raw.hasPrefix("file:")  { return .file(String(raw.dropFirst(5))) }
        return nil
    }

    static func uiImage(for item: Item) -> UIImage? {
        switch item.source {
        case .asset(let name): return UIImage(named: name)
        case .file(let path):  return UIImage(contentsOfFile: path)
        }
    }

    static func shortName(from s: String) -> String {
        let clean = s.replacingOccurrences(of: "_", with: " ")
                      .replacingOccurrences(of: "-", with: " ")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(clean.prefix(22))
    }
}

// Global scope
extension Notification.Name {
    static let customThemeCatalogChanged = Notification.Name("customThemeCatalogChanged")
}
