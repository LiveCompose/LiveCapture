//
//  MotionStabilityMonitor.swift
//  LiveCapture
//

import Foundation
import CoreMotion

final class MotionStabilityMonitor: ObservableObject {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    @Published var isStable: Bool = false

    // configurable
    var windowSeconds: TimeInterval = 0.5
    var accelerationStdThreshold: Double = 0.02
    var gyroStdThreshold: Double = 0.02

    private var accSamples: [(t: TimeInterval, v: CMAcceleration)] = []
    private var gyroSamples: [(t: TimeInterval, v: CMRotationRate)] = []

    func start() {
        guard motion.isAccelerometerAvailable || motion.isGyroAvailable else { return }
        motion.accelerometerUpdateInterval = 1.0 / 60.0
        motion.gyroUpdateInterval = 1.0 / 60.0

        if motion.isAccelerometerAvailable {
            motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.appendAccSample(data.acceleration)
                self.updateStability()
            }
        }
        if motion.isGyroAvailable {
            motion.startGyroUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.appendGyroSample(data.rotationRate)
                self.updateStability()
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        motion.stopGyroUpdates()
        DispatchQueue.main.async { self.isStable = false }
    }

    private func appendAccSample(_ v: CMAcceleration) {
        let now = Date().timeIntervalSince1970
        accSamples.append((now, v))
        trim(&accSamples, now: now)
    }

    private func appendGyroSample(_ v: CMRotationRate) {
        let now = Date().timeIntervalSince1970
        gyroSamples.append((now, v))
        trim(&gyroSamples, now: now)
    }

    private func trim<T>(_ arr: inout [(t: TimeInterval, v: T)], now: TimeInterval) {
        let cutoff = now - windowSeconds
        while let first = arr.first, first.t < cutoff { arr.removeFirst() }
    }

    private func updateStability() {
        guard !accSamples.isEmpty || !gyroSamples.isEmpty else { return }

        func stdDev(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return .zero }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            return sqrt(variance)
        }

        let accXYZ = accSamples.map { [$0.v.x, $0.v.y, $0.v.z] }
        let gyroXYZ = gyroSamples.map { [$0.v.x, $0.v.y, $0.v.z] }

        let accStd = stdDev(accXYZ.flatMap { $0 })
        let gyroStd = stdDev(gyroXYZ.flatMap { $0 })

        let stable = accStd < accelerationStdThreshold && gyroStd < gyroStdThreshold
        DispatchQueue.main.async { self.isStable = stable }
    }
}


