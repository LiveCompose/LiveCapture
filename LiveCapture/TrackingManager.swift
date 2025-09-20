//
//  TrackingManager.swift
//  LiveCapture
//

import Foundation
import Vision
import AVFoundation

final class TrackingManager {
    private var request: VNTrackObjectRequest?
    private let queue = DispatchQueue(label: "livecapture.tracking.queue")

    var onUpdate: ((CGRect, Float) -> Void)? // boundingBox (normalized), confidence

    func startTracking(from initialBox: CGRect, pixelBuffer: CVPixelBuffer) {
        queue.async {
            let observation = VNDetectedObjectObservation(boundingBox: initialBox)
            let req = VNTrackObjectRequest(detectedObjectObservation: observation)
            req.trackingLevel = .accurate
            self.request = req
            self.track(pixelBuffer: pixelBuffer)
        }
    }

    func reset() {
        queue.async { self.request = nil }
    }

    func track(pixelBuffer: CVPixelBuffer) {
        guard let req = self.request else { return }
        queue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            do {
                try handler.perform([req])
                if let obs = req.results?.first as? VNDetectedObjectObservation {
                    self.onUpdate?(obs.boundingBox, obs.confidence)
                }
            } catch {
                // ignore error
            }
        }
    }
}


