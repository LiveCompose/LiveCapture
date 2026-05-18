import Foundation
import Combine
import UIKit
import ImageIO

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let storageQueue = DispatchQueue(label: "livecapture.storage", qos: .utility)
    private var records: [PhotoRecord] = []
    private var isLoaded = false

    let recordsPublisher = CurrentValueSubject<[PhotoRecord], Never>([])

    private var baseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("LiveCapture", isDirectory: true)
    }

    private var recordsURL: URL {
        baseURL.appendingPathComponent("records.json")
    }

    private var photosDir: URL {
        baseURL.appendingPathComponent("photos", isDirectory: true)
    }

    private var thumbnailsDir: URL {
        baseURL.appendingPathComponent("thumbnails", isDirectory: true)
    }

    private init() {}

    // MARK: - Public API

    func loadRecords() -> [PhotoRecord] {
        if isLoaded { return records }
        ensureDirectories()
        if let data = try? Data(contentsOf: recordsURL),
           let decoded = try? JSONDecoder().decode([PhotoRecord].self, from: data) {
            records = decoded
        }
        isLoaded = true
        DispatchQueue.main.async {
            self.recordsPublisher.send(self.records)
        }
        return records
    }

    func savePhoto(data: Data, detectionMethod: String? = nil) {
        let id = UUID()
        let photoURL = photosDir.appendingPathComponent(PhotoRecord.photoFilename(for: id))
        let thumbURL = thumbnailsDir.appendingPathComponent(PhotoRecord.thumbnailFilename(for: id))

        // 提取 EXIF 元数据
        var exif: (iso: Float?, shutter: Double?, aperture: Double?, width: Int?, height: Int?) = (nil, nil, nil, nil, nil)
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            if let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                if let isoValues = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Float] {
                    exif.iso = isoValues.first
                }
                exif.shutter = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
                exif.aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double
            }
            exif.width = props[kCGImagePropertyPixelWidth as String] as? Int
            exif.height = props[kCGImagePropertyPixelHeight as String] as? Int
        }

        storageQueue.async { [weak self] in
            guard let self else { return }
            self.ensureDirectories()

            do {
                try data.write(to: photoURL, options: .atomic)
            } catch {
                print("PhotoStorageService: failed to write photo \(error)")
                return
            }

            if let thumbData = ThumbnailGenerator.generate(from: data) {
                try? thumbData.write(to: thumbURL, options: .atomic)
            }

            let record = PhotoRecord(id: id, creationDate: Date(),
                                     detectionMethod: detectionMethod,
                                     iso: exif.iso, shutterSpeed: exif.shutter, aperture: exif.aperture,
                                     imageWidth: exif.width, imageHeight: exif.height)
            self.records.insert(record, at: 0)
            self.persist()
        }
    }

    func deleteRecord(_ id: UUID) {
        storageQueue.async { [weak self] in
            guard let self else { return }
            self.records.removeAll { $0.id == id }
            let photoURL = self.photosDir.appendingPathComponent(PhotoRecord.photoFilename(for: id))
            let thumbURL = self.thumbnailsDir.appendingPathComponent(PhotoRecord.thumbnailFilename(for: id))
            try? FileManager.default.removeItem(at: photoURL)
            try? FileManager.default.removeItem(at: thumbURL)
            self.persist()
        }
    }

    func thumbnail(for id: UUID) -> UIImage? {
        let thumbURL = thumbnailsDir.appendingPathComponent(PhotoRecord.thumbnailFilename(for: id))
        return UIImage(contentsOfFile: thumbURL.path)
    }

    func photoURL(for id: UUID) -> URL? {
        let url = photosDir.appendingPathComponent(PhotoRecord.photoFilename(for: id))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Private

    private func ensureDirectories() {
        let dirs = [baseURL, photosDir, thumbnailsDir]
        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func persist() {
        let snapshot = records
        let url = recordsURL
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            print("PhotoStorageService: persist failed \(error)")
        }
        DispatchQueue.main.async {
            self.recordsPublisher.send(snapshot)
        }
    }
}
