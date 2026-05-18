import Foundation

struct PhotoRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let creationDate: Date
    var localIdentifier: String?

    init(id: UUID = UUID(),
         creationDate: Date = Date(),
         localIdentifier: String? = nil) {
        self.id = id
        self.creationDate = creationDate
        self.localIdentifier = localIdentifier
    }
}

extension PhotoRecord {
    static func photoFilename(for id: UUID) -> String { "\(id.uuidString).jpg" }
    static func thumbnailFilename(for id: UUID) -> String { "\(id.uuidString)_thumb.jpg" }
}
