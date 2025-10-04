//
//  TrackingManager.swift
//  LiveCapture
//

import Foundation
import Vision
import AVFoundation

/// 基于 Vision 的目标跟踪辅助类，为模板匹配提供平滑的中心点。
final class TrackingManager {
    /// Vision 跟踪请求实例。
    private var request: VNTrackObjectRequest?
    /// 串行队列，确保 Vision 请求与状态更新线程安全。
    private let queue: DispatchQueue = DispatchQueue(label: "livecapture.tracking.queue")
    
    // 用于平滑跟踪结果的缓冲区
    /// 最近的跟踪矩形样本。
    private var recentBoxes: [CGRect] = []
    /// 最近的置信度样本。
    private var recentConfidences: [Float] = []
    private let smoothingWindowSize = 3
    
    // 跟踪质量评估
    private var consecutiveGoodFrames = 0
    private var consecutiveBadFrames = 0
    private let requiredGoodFrames = 1    // 需要连续2帧好的结果才认为跟踪稳定
    private let maxBadFrames = 5000          // 超过5帧差的结果才重置跟踪，给予更多容错

    /// 跟踪更新回调，返回归一化矩形与置信度。
    var onUpdate: ((CGRect, Float) -> Void)? // boundingBox (normalized), confidence
    /// 跟踪失败时的回调。
    var onTrackingLost: (() -> Void)?         // 跟踪丢失回调

    /// 从初始检测框开始跟踪目标。
    func startTracking(from initialBox: CGRect, pixelBuffer: CVPixelBuffer) {
        queue.async {
            // 重置跟踪状态
            self.recentBoxes.removeAll()
            self.recentConfidences.removeAll()
            self.consecutiveGoodFrames = 0
            self.consecutiveBadFrames = 0
            
            let observation: VNDetectedObjectObservation = VNDetectedObjectObservation(boundingBox: initialBox)
            let req: VNTrackObjectRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
            req.trackingLevel = .accurate
            req.isLastFrame = false  // 确保持续跟踪
            self.request = req
            self.track(pixelBuffer: pixelBuffer)
        }
    }

    /// 清空跟踪状态与缓存。
    func reset() {
        queue.async { 
            self.request = nil
            self.recentBoxes.removeAll()
            self.recentConfidences.removeAll()
            self.consecutiveGoodFrames = 0
            self.consecutiveBadFrames = 0
        }
    }

    /// 续帧跟踪：在最新像素缓冲上运行 Vision 请求。
    func track(pixelBuffer: CVPixelBuffer) {
        guard let req: VNTrackObjectRequest = self.request else { return }
        queue.async {
            let handler: VNImageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            do {
                try handler.perform([req])
                if let obs: VNDetectedObjectObservation = req.results?.first as? VNDetectedObjectObservation {
                    self.processTrackingResult(boundingBox: obs.boundingBox, confidence: obs.confidence)
                } else {
                    // 没有跟踪结果，处理为失败情况
                    self.processTrackingResult(boundingBox: .zero, confidence: 0.0)
                }
            } catch {
                // 处理跟踪错误
                self.processTrackingResult(boundingBox: .zero, confidence: 0.0)
            }
        }
    }
    
    /// 根据单帧跟踪结果更新平滑状态与回调。
    private func processTrackingResult(boundingBox: CGRect, confidence: Float) {
        // 降低置信度阈值，提高跟踪稳定性
        let minConfidence: Float = 0.3
        let isGoodFrame = confidence >= minConfidence && boundingBox != .zero
        
        if isGoodFrame {
            consecutiveBadFrames = 0
            consecutiveGoodFrames += 1
            
            // 添加到平滑缓冲区
            recentBoxes.append(boundingBox)
            recentConfidences.append(confidence)
            
            // 限制缓冲区大小
            if recentBoxes.count > smoothingWindowSize {
                recentBoxes.removeFirst()
                recentConfidences.removeFirst()
            }
            
            // 只有连续几帧都好才开始输出稳定的跟踪结果
            if consecutiveGoodFrames >= requiredGoodFrames {
                let smoothedBox = calculateSmoothedBoundingBox()
                let avgConfidence = recentConfidences.reduce(0, +) / Float(recentConfidences.count)
                self.onUpdate?(smoothedBox, avgConfidence)
            }
            
        } else {
            consecutiveGoodFrames = 0
            consecutiveBadFrames += 1
            
            // 如果连续失败帧太多，通知跟踪丢失
            if consecutiveBadFrames >= maxBadFrames {
                self.onTrackingLost?()
                self.reset()
            }
        }
    }
    
    // 计算平滑后的边界框
    /// 对最近的跟踪矩形求平均，输出平滑结果。
    private func calculateSmoothedBoundingBox() -> CGRect {
        guard !recentBoxes.isEmpty else { return .zero }
        
        let avgX = recentBoxes.map { $0.origin.x }.reduce(0, +) / CGFloat(recentBoxes.count)
        let avgY = recentBoxes.map { $0.origin.y }.reduce(0, +) / CGFloat(recentBoxes.count)
        let avgWidth = recentBoxes.map { $0.size.width }.reduce(0, +) / CGFloat(recentBoxes.count)
        let avgHeight = recentBoxes.map { $0.size.height }.reduce(0, +) / CGFloat(recentBoxes.count)
        
        return CGRect(x: avgX, y: avgY, width: avgWidth, height: avgHeight)
    }
}


