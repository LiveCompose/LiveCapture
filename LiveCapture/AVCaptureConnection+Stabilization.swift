//
//  AVCaptureConnection+Stabilization.swift
//  LiveCapture
//
//  Centralizes best-effort video stabilization selection for camera and preview.
//

import AVFoundation

#if os(iOS) && !targetEnvironment(macCatalyst)
extension AVCaptureConnection {
    func applyBestVideoStabilizationMode() {
        guard isVideoStabilizationSupported else { return }
        guard let device = inputPorts
            .compactMap({ $0.input as? AVCaptureDeviceInput })
            .first?.device else { return }

        var candidateModes: [AVCaptureVideoStabilizationMode] = []
        if #available(iOS 13.0, *) {
            candidateModes.append(contentsOf: [.cinematicExtended, .cinematic])
        }
        candidateModes.append(contentsOf: [.auto, .standard])

        guard let bestMode = candidateModes.first(where: { device.activeFormat.isVideoStabilizationModeSupported($0) }) else { return }
        preferredVideoStabilizationMode = bestMode
    }
}
#else
extension AVCaptureConnection {
    func applyBestVideoStabilizationMode() {
        // Video stabilization selection is only available when building for iOS
    }
}
#endif
