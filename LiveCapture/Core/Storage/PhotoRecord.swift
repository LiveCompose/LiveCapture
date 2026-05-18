import Foundation

struct PhotoRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let creationDate: Date
    var localIdentifier: String?

    // 检测方法
    var detectionMethod: String?

    // EXIF 元数据
    var iso: Float?
    var shutterSpeed: Double?
    var aperture: Double?
    var imageWidth: Int?
    var imageHeight: Int?

    init(id: UUID = UUID(),
         creationDate: Date = Date(),
         localIdentifier: String? = nil,
         detectionMethod: String? = nil,
         iso: Float? = nil,
         shutterSpeed: Double? = nil,
         aperture: Double? = nil,
         imageWidth: Int? = nil,
         imageHeight: Int? = nil) {
        self.id = id
        self.creationDate = creationDate
        self.localIdentifier = localIdentifier
        self.detectionMethod = detectionMethod
        self.iso = iso
        self.shutterSpeed = shutterSpeed
        self.aperture = aperture
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

extension PhotoRecord {
    static func photoFilename(for id: UUID) -> String { "\(id.uuidString).jpg" }
    static func thumbnailFilename(for id: UUID) -> String { "\(id.uuidString)_thumb.jpg" }
}
