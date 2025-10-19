//
//  CameraManager+Zoom.swift
//  LiveCapture
//
//  Created by GitHub Copilot on 2025/10/13.
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
