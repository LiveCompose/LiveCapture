//
//  AdacropModel.swift
//  LiveCapture
//

import Foundation
import Vision
import CoreML
import AVFoundation

struct CropBox {
    let rectInNormalizedImage: CGRect // origin at bottom-left in Vision coordinates
}

final class AdacropModel {
    private let request: VNCoreMLRequest
    private let handlerQueue = DispatchQueue(label: "livecapture.adacrop.queue")

    init?(mlModelURL: URL) {
        do {
            let compiled = try MLModel.compileModel(at: mlModelURL)
            let model = try MLModel(contentsOf: compiled)
            let vnModel = try VNCoreMLModel(for: model)
            self.request = VNCoreMLRequest(model: vnModel)
            self.request.imageCropAndScaleOption = .scaleFill
        } catch {
            return nil
        }
    }

    func predictCropBox(pixelBuffer: CVPixelBuffer, completion: @escaping (CropBox?) -> Void) {
        let req = self.request
        handlerQueue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([req])
                if let obs = req.results?.first as? VNRectangleObservation {
                    completion(CropBox(rectInNormalizedImage: obs.boundingBox))
                } else if let obs = req.results?.first as? VNDetectedObjectObservation {
                    completion(CropBox(rectInNormalizedImage: obs.boundingBox))
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
    }
}


