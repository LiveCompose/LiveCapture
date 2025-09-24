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
    let detectionType: String         // 用于调试，说明使用了哪种检测方法
}

final class AdacropModel {
    private let handlerQueue = DispatchQueue(label: "livecapture.adacrop.queue")

    init() {
        // 简化初始化，不再需要模型文件
    }

    func predictCropBox(pixelBuffer: CVPixelBuffer, completion: @escaping (CropBox?) -> Void) {
        handlerQueue.async {
            // 寻找最佳跟踪区域，优先选择特征丰富的区域
            let (bestRect, detectionType) = self.findBestTrackingRegionWithType(in: pixelBuffer)
            completion(CropBox(rectInNormalizedImage: bestRect, detectionType: detectionType))
        }
    }
    
    private func findBestTrackingRegionWithType(in pixelBuffer: CVPixelBuffer) -> (CGRect, String) {
        // 优先寻找特征丰富的静态区域，避免跟踪可能移动的对象（如人脸）
        
        // 首先尝试使用角点和轮廓检测找到最佳区域
        if let cornerBasedRegion = findCornerRichRegion(in: pixelBuffer) {
            return (cornerBasedRegion, "轮廓特征")
        }
        
        // 如果角点检测失败，尝试检测静态矩形物体
        if let rectangleRegion = findStaticRectangularRegion(in: pixelBuffer) {
            return (rectangleRegion, "矩形物体")
        }
        
        // 最后的备选：检测人脸但作为最后选择（因为人可能移动）
        if let faceRegion = findFaceRegionAsLastResort(in: pixelBuffer) {
            return (faceRegion, "人脸区域")
        }
        
        // 如果所有检测都失败，使用中心加权区域
        return (findCenterWeightedRegion(), "默认中心")
    }
    
    // 新增：基于角点检测的特征区域选择
    private func findCornerRichRegion(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        // 使用轮廓检测来找到特征丰富的区域
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 512 // 限制处理尺寸以提高性能
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([request])
            
            if let contoursObservation = request.results?.first {
                let contours = contoursObservation.topLevelContours
                
                // 寻找最复杂的轮廓（点数最多的）
                let complexContour = contours.max { contour1, contour2 in
                    contour1.normalizedPoints.count < contour2.normalizedPoints.count
                }
                
                if let contour = complexContour, contour.normalizedPoints.count > 20 {
                    // 基于轮廓创建边界框
                    let points = contour.normalizedPoints
                    let xs = points.map { $0.x }
                    let ys = points.map { $0.y }
                    
                    guard let minX = xs.min(), let maxX = xs.max(),
                          let minY = ys.min(), let maxY = ys.max() else {
                        return nil
                    }
                    
                    let width = maxX - minX
                    let height = maxY - minY
                    
                    // 确保区域大小合适且不在边缘
                    if width > 0.1 && width < 0.7 && height > 0.1 && height < 0.7 &&
                       minX > 0.1 && maxX < 0.9 && minY > 0.1 && maxY < 0.9 {
                        // CGRect的初始化参数需要是CGFloat类型
                        return CGRect(x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(width), height: CGFloat(height))
                    }
                }
            }
        } catch {
            // 轮廓检测失败，继续尝试其他方法
        }
        
        return nil
    }
    
    // 新增：检测静态矩形区域（可能是桌子、墙壁、书本等）
    private func findStaticRectangularRegion(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5  // 更保守的长宽比
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.15        // 更大的最小尺寸确保是实际物体
        request.maximumObservations = 5
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([request])
            
            if let rectangles = request.results, !rectangles.isEmpty {
                // 优先选择中心区域的矩形（更可能是静态的）
                let centerWeightedRect = rectangles.max { rect1, rect2 in
                    let center = CGPoint(x: 0.5, y: 0.5)
                    let dist1 = hypot(rect1.boundingBox.midX - center.x, rect1.boundingBox.midY - center.y)
                    let dist2 = hypot(rect2.boundingBox.midX - center.x, rect2.boundingBox.midY - center.y)
                    return dist1 > dist2  // 距离中心更近的优先
                }
                
                return centerWeightedRect?.boundingBox
            }
        } catch {
            // 矩形检测失败
        }
        
        return nil
    }
    
    // 新增：人脸检测作为最后备选（因为人可能移动）
    private func findFaceRegionAsLastResort(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([request])
            
            if let faceObservation = request.results?.first {
                let faceRect = faceObservation.boundingBox
                // 适度扩大人脸区域
                let expandedRect = CGRect(
                    x: max(0, faceRect.origin.x - faceRect.width * 0.05),
                    y: max(0, faceRect.origin.y - faceRect.height * 0.05),
                    width: min(1.0 - faceRect.origin.x, faceRect.width * 1.1),
                    height: min(1.0 - faceRect.origin.y, faceRect.height * 1.1)
                )
                return expandedRect
            }
        } catch {
            // 人脸检测失败
        }
        
        return nil
    }
    
    
    private func findCenterWeightedRegion() -> CGRect {
        // 在图像中心区域选择一个适合跟踪的矩形
        // 优先选择可能包含静态物体的区域（避开顶部天空、底部地面）
        
        // 定义优先级排序的候选区域
        let candidateRegions = [
            // 中心偏上区域 - 通常包含桌面、书本、墙面等静态物体
            CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.35),
            // 中心偏下区域 - 可能是桌面或其他平面
            CGRect(x: 0.25, y: 0.6, width: 0.5, height: 0.25),
            // 中心区域 - 通用备选
            CGRect(x: 0.35, y: 0.45, width: 0.3, height: 0.3),
            // 左中区域 - 可能有墙面或家具
            CGRect(x: 0.15, y: 0.4, width: 0.35, height: 0.35),
            // 右中区域 - 可能有墙面或家具  
            CGRect(x: 0.5, y: 0.4, width: 0.35, height: 0.35)
        ]
        
        // 选择第一个候选区域作为最佳选择
        // 这个区域最可能包含静态的、特征丰富的背景物体
        return candidateRegions[0]
    }
}


