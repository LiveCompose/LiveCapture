//
//  CameraManager+Models.swift
//  LiveCapture
//
//  Created by GitHub Copilot on 2025/10/13.
//

import Foundation
import AVFoundation

#if os(iOS)

extension CameraManager {
    /// 枚举当前可用的镜头类型，便于描述 UI 与硬件的映射关系。
    enum LensKind: String, CaseIterable, Identifiable {
        case ultraWide
        case wide
        case telephoto
        case front

        var id: String { rawValue }

        /// 以 iOS 默认焦段为参考给出大致焦距，用于 UI 展示。
        var approximateFocalLength: Int {
            switch self {
            case .ultraWide: return 13
            case .wide: return 24
            case .telephoto: return 77
            case .front: return 24
            }
        }

        /// 对应的默认变焦倍率。
        var opticalZoomFactor: CGFloat {
            switch self {
            case .ultraWide: return 0.5
            case .wide: return 1.0
            case .telephoto: return 3.0
            case .front: return 1.0
            }
        }

        var displayName: String {
            switch self {
            case .ultraWide: return "0.5×"
            case .wide: return "1×"
            case .telephoto: return "3×"
            case .front: return "1×"
            }
        }

        /// 与镜头类型匹配的 SF Symbol 名称，用于 UI 图标展示。
        var symbolName: String {
            switch self {
            case .ultraWide:
                return "arrow.down.left.and.arrow.up.right"
            case .wide:
                return "circle.grid.3x3.fill"
            case .telephoto:
                return "scope"
            case .front:
                return "person.crop.square"
            }
        }
    }

    /// 变焦环所需的离散预设点描述。
    struct ZoomPreset: Identifiable, Hashable {
        enum Style {
            case primary // 用于突出当前镜头（例如 1×）
            case secondary
        }

        let id = UUID()
        let lens: LensKind
        let zoomFactor: CGFloat
        let focalLength: Int
        let style: Style

        var label: String {
            let rounded = (zoomFactor * 10).rounded() / 10
            if abs(Double(rounded) - Double(Int(rounded))) < 0.001 {
                return "\(Int(rounded))×"
            } else {
                return String(format: "%.1f×", rounded)
            }
        }
        var focalLengthLabel: String { "\(focalLength)mm" }
    }

    /// 保持实时变焦状态，供 UI 绑定。
    struct ZoomState: Equatable {
        var currentFactor: CGFloat
        var displayedFactor: CGFloat
        var focalLength: Int
        var activeLens: LensKind
        var isContinuous: Bool
    }
    /// 相机可抛出的错误类型，用于向上层反馈具体失败原因。
    enum CameraError: Error {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case photoDataMissing
        case saveFailed
        case notAuthorized
    }
}

#endif
