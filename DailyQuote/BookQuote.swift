import Foundation

struct BookQuote: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let author: String
    let category: String?
    let book: String?

    init(id: UUID = UUID(), text: String, author: String, category: String? = nil, book: String? = nil) {
        self.id = id
        self.text = text
        self.author = author
        self.category = category
        self.book = book
    }

    enum CodingKeys: String, CodingKey {
        case id, text, author, category, book
    }
}
