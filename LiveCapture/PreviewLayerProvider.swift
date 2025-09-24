//
//  PreviewLayerProvider.swift
//  LiveCapture
//

import Foundation
import Combine
import AVFoundation

final class PreviewLayerProvider: ObservableObject {
    let objectWillChange: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
    weak var layer: AVCaptureVideoPreviewLayer? {
        willSet { objectWillChange.send() }
    }
}


