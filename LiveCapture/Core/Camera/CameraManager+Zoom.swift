//
//  CameraManager+Zoom.swift
//  LiveCapture
//
//  相机变焦控制扩展
//
//  ## 文件作用
//  实现相机的变焦功能，包括离散预设变焦和连续交互式变焦
//  管理虚拟设备的镜头切换点和变焦能力配置
//
//  ## 主要方法
//
//  ### 变焦控制
//  - selectZoomPreset(_:): 选择预设变焦倍率（如 0.5x, 1x, 2x）
//    参数: preset - ZoomPreset 预设变焦配置
//    特点: 带平滑动画过渡
//
//  - updateInteractiveZoom(to:): 交互式变焦时实时更新倍率
//    参数: factor - CGFloat 目标变焦倍率
//    特点: 无动画，立即响应用户拖动
//
//  - finalizeInteractiveZoom(at:smooth:): 交互式变焦结束时锁定倍率
//    参数: 
//      - factor: CGFloat 最终变焦倍率
//      - smooth: Bool 是否使用平滑过渡
//
//  ### 变焦能力配置
//  - configureZoomCapabilities(for:position:): 配置设备的变焦能力
//    参数:
//      - device: AVCaptureDevice 当前相机设备
//      - position: AVCaptureDevice.Position 摄像头位置
//    功能:
//      - 读取硬件支持的变焦范围
//      - 识别虚拟设备的镜头切换点
//      - 生成可用镜头列表和预设
//      - 更新 UI 显示的变焦选项
//
//  ### 内部实现
//  - applyZoomFactor(_:animated:isContinuous:): 实际执行变焦操作
//    参数:
//      - factor: CGFloat 目标倍率
//      - animated: Bool 是否使用动画
//      - isContinuous: Bool 是否为连续变焦模式
//    功能:
//      - 在 sessionQueue 上执行
//      - 锁定设备配置
//      - 设置 videoZoomFactor
//      - 更新变焦状态到主线程
//
//  - refreshZoomState(with:isContinuous:): 刷新变焦状态模型
//    参数:
//      - factor: CGFloat 当前倍率
//      - isContinuous: Bool 是否为连续模式
//    功能:
//      - 计算显示倍率和焦距
//      - 确定当前使用的镜头类型
//      - 更新 @Published zoomState
//
//  ## 变焦策略
//  - 后置摄像头：支持超广角(0.5x)、广角(1x)、长焦(2x+)
//  - 前置摄像头：通常固定 1x
//  - 使用虚拟设备切换点优化多镜头切换体验
//
//  ## 线程安全
//  - 所有变焦操作在 sessionQueue 上执行
//  - 状态更新通过 DispatchQueue.main 回到主线程
//

import Foundation
import AVFoundation

#if os(iOS)

extension CameraManager {
    /// 点按预设快捷按钮触发的变焦请求。
    func selectZoomPreset(_ preset: ZoomPreset) {
        sessionQueue.async {
            self.applyZoomFactor(preset.zoomFactor, animated: true, isContinuous: false)
        }
    }

    /// 拖动过程中实时更新变焦倍率。
    func updateInteractiveZoom(to factor: CGFloat) {
        sessionQueue.async {
            self.applyZoomFactor(factor, animated: false, isContinuous: true)
        }
    }

    /// 拖动结束后锁定最终倍率，可选平滑过渡。
    func finalizeInteractiveZoom(at factor: CGFloat, smooth: Bool) {
        sessionQueue.async {
            self.applyZoomFactor(factor, animated: smooth, isContinuous: false)
        }
    }
    
    /// 读取硬件变焦能力并刷新预设、镜头列表与状态。
    func configureZoomCapabilities(for device: AVCaptureDevice, position: AVCaptureDevice.Position) {
        let minFactor = max(CGFloat(device.minAvailableVideoZoomFactor), 0.50)
        let maxFactor = CGFloat(device.maxAvailableVideoZoomFactor)
        let switchPoints = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }.sorted()
        virtualDeviceSwitchPoints = switchPoints

        let lenses: [LensKind]
        if position == .front {
            lenses = [.front]
        } else {
            let constituents = device.constituentDevices
            var kinds: Set<LensKind> = []
            for sub in constituents {
                switch sub.deviceType {
                case .builtInUltraWideCamera:
                    kinds.insert(.ultraWide)
                case .builtInTelephotoCamera:
                    kinds.insert(.telephoto)
                default:
                    kinds.insert(.wide)
                }
            }
            if kinds.isEmpty {
                kinds.insert(.wide)
            }
            lenses = kinds.sorted { lensOrder(lhs: $0, rhs: $1) }
        }

        let presets = buildZoomPresets(range: minFactor...maxFactor, lenses: lenses)
        self.applyZoomConfiguration(range: minFactor...maxFactor,
                                lenses: lenses,
                                presets: presets,
                                targetFactor: max(minFactor, self.zoomState.currentFactor),
                                isContinuous: false)
    }

    /// 基于支持范围与镜头集合构建变焦预设列表。
    func buildZoomPresets(range: ClosedRange<CGFloat>, lenses: [LensKind]) -> [ZoomPreset] {
        guard !lenses.isEmpty else { return [] }

        var presets: [ZoomPreset] = []
        /// 将符合条件的变焦预设加入结果集合。
        func append(lens: LensKind, factor: CGFloat, style: ZoomPreset.Style) {
            guard range.contains(factor) else { return }
            let focal = estimateFocalLength(for: factor, lens: lens)
            let preset = ZoomPreset(lens: lens,
                                    zoomFactor: factor,
                                    focalLength: focal,
                                    style: style)
            if !presets.contains(where: { abs($0.zoomFactor - factor) < 0.01 }) {
                presets.append(preset)
            }
        }

        if lenses.contains(.ultraWide) {
            append(lens: .ultraWide, factor: 0.5, style: .secondary)
        }
        let primaryLens: LensKind = lenses.contains(.front) ? .front : .wide
        append(lens: primaryLens, factor: 1.0, style: .primary)
        //if lenses.contains(.telephoto) {
        //    append(lens: .telephoto, factor: 3.0, style: .secondary)
        //    if range.contains(5.0) {
        //        append(lens: .telephoto, factor: 5.0, style: .secondary)
        //    }
        //} 
        if range.contains(2.0) && primaryLens != .front {
            append(lens: primaryLens, factor: 2.0, style: .secondary)
        }

        return presets.sorted { $0.zoomFactor < $1.zoomFactor }
    }

    /// 为镜头类型提供排序规则，便于稳定展示。
    func lensOrder(lhs: LensKind, rhs: LensKind) -> Bool {
        let ranking: [LensKind] = [.ultraWide, .wide, .telephoto, .front]
        return ranking.firstIndex(of: lhs) ?? 0 < ranking.firstIndex(of: rhs) ?? 0
    }

    /// 估算给定变焦倍率与镜头对应的等效焦距。
    func estimateFocalLength(for factor: CGFloat, lens: LensKind) -> Int {
        let base: Double = 24.0
        let precise = Double(factor) * base
        switch lens {
        case .ultraWide, .front:
            return max(10, Int(round(precise)))
        case .wide:
            return Int(round(precise))
        case .telephoto:
            // 使用更接近长焦原生焦段的预设
            let optical = Double(lens.approximateFocalLength)
            if abs(precise - optical) < 8 {
                return Int(round(optical))
            }
            return Int(round(precise))
        }
    }

    /// 根据最新变焦结果刷新发布的状态模型。
    func refreshZoomState(with factor: CGFloat, isContinuous: Bool) {
        let clamped = clampZoom(factor)
        let lens = currentLensKind(for: clamped)
        let focal = estimateFocalLength(for: clamped, lens: lens)
        let display = (clamped * 100).rounded() / 100
        let state = ZoomState(currentFactor: clamped,
                             displayedFactor: display,
                             focalLength: focal,
                             activeLens: lens,
                             isContinuous: isContinuous)
        updateZoomState(state)
    }

    /// 将目标变焦倍率限制在硬件支持的区间内。
    func clampZoom(_ factor: CGFloat) -> CGFloat {
        let lower = zoomRange.lowerBound
        let upper = 10.0
        return min(max(factor, lower), upper)
    }

    /// 根据变焦倍率推断当前使用的镜头类型。
    func currentLensKind(for factor: CGFloat) -> LensKind {
        if currentPosition == .front {
            return .front
        }
        let sortedLenses = availableLenses.sorted { lensOrder(lhs: $0, rhs: $1) }
        guard sortedLenses.count > 1 else {
            return sortedLenses.first ?? .wide
        }
        if virtualDeviceSwitchPoints.count == sortedLenses.count - 1 {
            for (idx, point) in virtualDeviceSwitchPoints.enumerated() {
                if factor < point {
                    return sortedLenses[idx]
                }
            }
            return sortedLenses.last ?? .wide
        } else {
            if sortedLenses.contains(.ultraWide) && factor < 0.9 {
                return .ultraWide
            }
            if sortedLenses.contains(.telephoto) && factor > 2.4 {
                return .telephoto
            }
            return .wide
        }
    }

    /// 根据目标倍率挑选平滑过渡的变焦速率。
    func optimalRampRate(for factor: CGFloat) -> Float {
        if factor < 1.0 {
            return 5.0
        } else if factor > 3.0 {
            return 10.0
        } else {
            return 8.0
        }
    }

    /// 执行变焦倍率的应用逻辑，支持动画与状态回写。
    func applyZoomFactor(_ factor: CGFloat, animated: Bool, isContinuous: Bool) {
        let target = clampZoom(factor)
        guard let device = activeVideoDevice else {
            refreshZoomState(with: target, isContinuous: isContinuous)
            return
        }

        do {
            try device.lockForConfiguration()
            if animated {
                let rate = optimalRampRate(for: target)
                device.ramp(toVideoZoomFactor: target, withRate: rate)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            let fallbackState = ZoomState(currentFactor: target,
                        displayedFactor: (target * 100).rounded() / 100,
                        focalLength: self.estimateFocalLength(for: target, lens: self.currentLensKind(for: target)),
                        activeLens: self.currentLensKind(for: target),
                        isContinuous: isContinuous)
            self.updateZoomState(fallbackState)
            return
        }

        refreshZoomState(with: target, isContinuous: isContinuous)
    }
}

#endif
