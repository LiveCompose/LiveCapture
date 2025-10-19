//
//  MotionStabilityMonitor.swift
//  LiveCapture
//

import Foundation
import Combine
import CoreGraphics
import CoreMotion

#if os(iOS)
import CoreMotion

/// 负责监控设备运动稳定性并将陀螺仪姿态映射到屏幕偏移。
final class MotionStabilityMonitor: ObservableObject {
    /// Core Motion 管理器，用于访问传感器数据。
    private let motion = CMMotionManager()
    // 使用串行队列确保线程安全
    private let dataQueue = DispatchQueue(label: "livecapture.motion.data", qos: .userInitiated)

    /// 指示当前是否处于稳定状态。
    @Published var isStable: Bool = false
    /// 调试说明文字，展示传感器统计信息。
    @Published var debugInfo: String = "初始化中..."
    /// 原始设备姿态数据。
	@Published var deviceMotion: CMDeviceMotion?

    // configurable - 针对跟踪场景优化的阈值
    var windowSeconds: TimeInterval = 0.8        // 增加窗口时间以获得更稳定的判断
    var accelerationStdThreshold: Double = 0.12  // 稍微收紧加速度阈值
    var gyroStdThreshold: Double = 0.08         // 稍微收紧陀螺仪阈值，减少微小抖动
    
    // 添加连续稳定帧计数以避免频繁切换
    private var consecutiveStableFrames = 0
    private var consecutiveUnstableFrames = 0
    private let requiredStableFrames = 10      // 需要连续10帧稳定才认为真正稳定
    private let maxUnstableFrames = 5          // 超过5帧不稳定就认为不稳定
    
    // 限流机制，避免updateStability被过于频繁调用
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.05  // 最多每50ms更新一次

    private var accSamples: [(t: TimeInterval, v: CMAcceleration)] = []
    private var gyroSamples: [(t: TimeInterval, v: CMRotationRate)] = []
    private var lastPitch: Double = 0
    private var lastRoll: Double = 0
    private var referencePitch: Double?
    private var referenceRoll: Double?
    private let maxAngle: Double = .pi / 6 // 控制映射到界面的最大角度（约 30°）
    private var offsetSmoother = UniformPointSmoother(response: 0.25)

    /// 启动传感器采集与稳定性分析。
    func start() {
        guard motion.isAccelerometerAvailable || motion.isGyroAvailable || motion.isDeviceMotionAvailable else { return }
        motion.accelerometerUpdateInterval = 1.0 / 60.0
        motion.gyroUpdateInterval = 1.0 / 60.0
        motion.deviceMotionUpdateInterval = 1.0 / 60.0

        if motion.isAccelerometerAvailable {
            motion.startAccelerometerUpdates(to: OperationQueue()) { [weak self] data, _ in
                guard let self, let data else { return }
                // 所有数据操作都在串行队列中进行，确保线程安全
                self.dataQueue.async {
                    self.appendAccSample(data.acceleration)
                    self.updateStabilityIfNeeded()
                }
            }
        }
        if motion.isGyroAvailable {
            motion.startGyroUpdates(to: OperationQueue()) { [weak self] data, _ in
                guard let self, let data else { return }
                // 所有数据操作都在串行队列中进行，确保线程安全
                self.dataQueue.async {
                    self.appendGyroSample(data.rotationRate)
                    self.updateStabilityIfNeeded()
                }
            }
        }
        if motion.isDeviceMotionAvailable {
            motion.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] data, _ in
                guard let self, let data else { return }
                self.dataQueue.async {
                    self.updateDeviceMotion(with: data)
                }
            }
        }
    }

    /// 停止传感器采集并清理内部状态。
    func stop() {
        motion.stopAccelerometerUpdates()
        motion.stopGyroUpdates()
        motion.stopDeviceMotionUpdates()
        // 在数据队列中安全地重置状态
        dataQueue.async {
            self.consecutiveStableFrames = 0
            self.consecutiveUnstableFrames = 0
            self.accSamples.removeAll()
            self.gyroSamples.removeAll()
            self.referencePitch = nil
            self.referenceRoll = nil
            self.offsetSmoother.reset()
        }
        DispatchQueue.main.async { 
            self.isStable = false
            self.debugInfo = "已停止"
            self.deviceMotion = nil
        }
    }

    /// 将当前姿态设为零点，用于随后偏移计算。
    func lockReferenceAttitude() {
        // 将当前姿态记为参考零点，供 3D -> 2D 偏移换算使用
        dataQueue.async {
            self.referencePitch = self.lastPitch
            self.referenceRoll = self.lastRoll
            self.offsetSmoother.reset(to: .zero)
            DispatchQueue.main.async {
                self.deviceMotion = nil
            }
        }
    }

    /// 清空姿态零点，重新开始偏移估计。
    func resetReferenceAttitude() {
        // 清除参考姿态，同时把偏移归零
        dataQueue.async {
            self.referencePitch = nil
            self.referenceRoll = nil
            self.offsetSmoother.reset(to: .zero)
            DispatchQueue.main.async {
                self.deviceMotion = nil
            }
        }
    }

    /// 根据最新陀螺仪姿态计算屏幕坐标系中的偏移。
    private func updateDeviceMotion(with data: CMDeviceMotion) {
        // 将陀螺仪的俯仰/横滚角映射到屏幕上的二维偏移
        let pitch = data.attitude.pitch
        let roll = data.attitude.roll
        lastPitch = pitch
        lastRoll = roll

        DispatchQueue.main.async {
            self.deviceMotion = data
        }
    }

    /// 记录一条加速度样本并裁剪窗口。
    private func appendAccSample(_ v: CMAcceleration) {
        let now = Date().timeIntervalSince1970
        accSamples.append((now, v))
        trim(&accSamples, now: now)
    }

    /// 记录一条陀螺仪样本并裁剪窗口。
    private func appendGyroSample(_ v: CMRotationRate) {
        let now = Date().timeIntervalSince1970
        gyroSamples.append((now, v))
        trim(&gyroSamples, now: now)
    }

    /// 剪去超出滑动窗口的历史样本。
    private func trim<T>(_ arr: inout [(t: TimeInterval, v: T)], now: TimeInterval) {
        let cutoff = now - windowSeconds
        while let first = arr.first, first.t < cutoff { arr.removeFirst() }
    }
    
    // 限流版本的更新稳定性函数
    /// 按节流逻辑触发稳定性计算，避免过度频繁。
    private func updateStabilityIfNeeded() {
        let now = Date().timeIntervalSince1970
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now
        updateStability()
    }

    /// 汇总传感器标准差并评估连续稳定帧。
    private func updateStability() {
        guard !accSamples.isEmpty || !gyroSamples.isEmpty else { return }

        func stdDev(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return .zero }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            return sqrt(variance)
        }

        // 计算每个样本的加速度和角速度大小，然后计算标准差
        let accMagnitudes = accSamples.map { sqrt($0.v.x*$0.v.x + $0.v.y*$0.v.y + $0.v.z*$0.v.z) }
        let gyroMagnitudes = gyroSamples.map { sqrt($0.v.x*$0.v.x + $0.v.y*$0.v.y + $0.v.z*$0.v.z) }

        let accStd = stdDev(accMagnitudes)
        let gyroStd = stdDev(gyroMagnitudes)

        let currentFrameStable = accStd < accelerationStdThreshold && gyroStd < gyroStdThreshold
        
        // 使用连续帧计数来避免频繁的稳定性切换
        if currentFrameStable {
            consecutiveUnstableFrames = 0
            consecutiveStableFrames += 1
        } else {
            consecutiveStableFrames = 0
            consecutiveUnstableFrames += 1
        }
        
        // 判断整体稳定性状态
        let overallStable: Bool
        if isStable {
            // 如果当前是稳定状态，需要连续不稳定帧超过阈值才切换为不稳定
            overallStable = consecutiveUnstableFrames < maxUnstableFrames
        } else {
            // 如果当前是不稳定状态，需要连续稳定帧达到阈值才切换为稳定
            overallStable = consecutiveStableFrames >= requiredStableFrames
        }
        
        // 创建详细的调试信息，包含连续帧信息
        let debugText = "加速度: \(String(format: "%.3f", accStd))/\(String(format: "%.2f", accelerationStdThreshold)), 陀螺仪: \(String(format: "%.3f", gyroStd))/\(String(format: "%.2f", gyroStdThreshold)), 连续稳定: \(consecutiveStableFrames)"
        
        #if DEBUG
        print("稳定性检测 - \(debugText), 整体稳定: \(overallStable)")
        #endif
        
        DispatchQueue.main.async { 
            self.isStable = overallStable
            self.debugInfo = debugText
        }
    }
}

#endif
