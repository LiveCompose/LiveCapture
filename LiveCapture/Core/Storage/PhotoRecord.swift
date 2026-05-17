import Foundation

struct PhotoRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let creationDate: Date
    var isShared: Bool
    var caption: String?
    var localIdentifier: String?

    init(id: UUID = UUID(),
         creationDate: Date = Date(),
         isShared: Bool = false,
         caption: String? = nil,
         localIdentifier: String? = nil) {
        self.id = id
        self.creationDate = creationDate
        self.isShared = isShared
        self.caption = caption
        self.localIdentifier = localIdentifier
    }
}

extension PhotoRecord {
    static func photoFilename(for id: UUID) -> String { "\(id.uuidString).jpg" }
    static func thumbnailFilename(for id: UUID) -> String { "\(id.uuidString)_thumb.jpg" }
}
