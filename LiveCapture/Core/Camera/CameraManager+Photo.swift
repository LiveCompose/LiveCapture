import Foundation
import AVFoundation
import CoreImage
import ImageIO

#if os(iOS)

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func capturePhoto() {
        let settings: AVCapturePhotoSettings = AVCapturePhotoSettings()
        if self.photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }
        settings.isHighResolutionPhotoEnabled = true
        if photoOutput.isStillImageStabilizationSupported {
            settings.isAutoStillImageStabilizationEnabled = true
        }
        if #available(iOS 16.0, tvOS 16.0, *) {
            settings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error: any Error = error {
            print("Photo processing error: \(error)")
            DispatchQueue.main.async { self.lastPhotoSaved = false }
            return
        }
        guard let data: Data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.lastPhotoSaved = false }
            return
        }
        onPhotoDataReady?(data)
        DispatchQueue.main.async { self.lastPhotoSaved = true }
    }

    func processPhotoData(photo: AVCapturePhoto, originalData: Data) -> Data? {
        guard let pixelBuffer = photo.pixelBuffer,
              let croppedBuffer = cropPixelBufferToThreeByFour(pixelBuffer,
                                                               orientation: photoOrientation(from: photo)),
              let jpegData = jpegData(from: croppedBuffer) else {
            return nil
        }
        return jpegData
    }

    func cropPixelBufferToThreeByFour(_ pixelBuffer: CVPixelBuffer,
                                      orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let extent = oriented.extent
        let desiredAspect: CGFloat = 3.0 / 4.0
        var cropRect = extent
        let currentAspect = extent.width / extent.height

        if currentAspect > desiredAspect {
            let newWidth = extent.height * desiredAspect
            cropRect.origin.x = extent.midX - newWidth * 0.5
            cropRect.size.width = newWidth
        } else if currentAspect < desiredAspect {
            let newHeight = extent.width / desiredAspect
            cropRect.origin.y = extent.midY - newHeight * 0.5
            cropRect.size.height = newHeight
        }

        let cropped = oriented.cropped(to: cropRect)

        var output: CVPixelBuffer?
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(cropRect.width),
                                         Int(cropRect.height),
                                         pixelFormat,
                                         attributes as CFDictionary,
                                         &output)
        guard status == kCVReturnSuccess, let buffer = output else { return nil }

        photoContext.render(cropped, to: buffer)
        return buffer
    }

    func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return photoContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [:])
    }

    func photoOrientation(from photo: AVCapturePhoto) -> CGImagePropertyOrientation {
        if let value = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
           let orientation = CGImagePropertyOrientation(rawValue: value) {
            return orientation
        }
        return .right
    }
}

#endif
