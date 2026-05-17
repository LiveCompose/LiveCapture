import UIKit
import ImageIO

enum ThumbnailGenerator {
    static func generate(from jpegData: Data, maxDimension: CGFloat = 300) -> Data? {
        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}
