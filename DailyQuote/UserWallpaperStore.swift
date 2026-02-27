import SwiftUI

struct UserWallpaper: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fullFilename: String
    var thumbFilename: String
}

final class UserWallpaperStore: ObservableObject {
    static let shared = UserWallpaperStore()

    @Published private(set) var items: [UserWallpaper] = []
    private let listKey = "user.wallpapers.list.v1"

    private var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: listKey),
           let arr = try? JSONDecoder().decode([UserWallpaper].self, from: data) {
            items = arr
        }
    }

    private func saveList() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    @discardableResult
    func addCreation(name: String, fullImage: UIImage,
                     tileSize: CGSize = CGSize(width: 160, height: 220)) throws -> UserWallpaper {
        let id = UUID()
        let base = id.uuidString
        let full = "\(base).jpg"
        let thumb = "\(base)_thumb.jpg"

        let thumbnail = makeThumbnail(from: fullImage, targetSize: tileSize)
        guard let fullData = fullImage.jpegData(compressionQuality: 0.9),
              let thumbData = thumbnail.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "image.save", code: -1)
        }

        try fullData.write(to: docsURL.appendingPathComponent(full), options: .atomic)
        try thumbData.write(to: docsURL.appendingPathComponent(thumb), options: .atomic)

        let display = Self.shortName(from: name)
        let item = UserWallpaper(id: id, name: display, fullFilename: full, thumbFilename: thumb)
        items.insert(item, at: 0)
        saveList()
        return item
    }

    func fullImage(for item: UserWallpaper) -> UIImage? {
        UIImage(contentsOfFile: docsURL.appendingPathComponent(item.fullFilename).path)
    }

    func thumbImage(for item: UserWallpaper) -> UIImage? {
        UIImage(contentsOfFile: docsURL.appendingPathComponent(item.thumbFilename).path)
    }

    func delete(_ item: UserWallpaper) {
        try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(item.fullFilename))
        try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(item.thumbFilename))
        items.removeAll { $0.id == item.id }
        saveList()
    }

    private static func shortName(from prompt: String) -> String {
        let s = prompt.replacingOccurrences(of: "_", with: " ")
                       .replacingOccurrences(of: "-", with: " ")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(s.prefix(24))
    }
}
