//
//  HapticManager.swift
//  LiveCapture
//
//  触觉反馈管理器，为应用提供统一的震动效果

#if os(iOS)
import UIKit

/// 触觉反馈管理器，封装所有震动效果
final class HapticManager {
    /// 单例实例
    static let shared = HapticManager()
    
    // 预生成的震动引擎，提升响应速度
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // 预热所有生成器以减少延迟
        prepare()
    }
    
    /// 预热所有震动引擎
    func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - 通用交互反馈
    
    /// 轻触反馈 - 用于按钮点击
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }
    
    /// 中等反馈 - 用于重要操作
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }
    
    /// 重击反馈 - 用于关键操作
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }
    
    /// 柔和反馈 - 用于细微交互
    func soft() {
        impactSoft.impactOccurred()
        impactSoft.prepare()
    }
    
    /// 硬朗反馈 - 用于确定性操作
    func rigid() {
        impactRigid.impactOccurred()
        impactRigid.prepare()
    }
    
    /// 选择反馈 - 用于切换、选择操作
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    // MARK: - 通知类反馈
    
    /// 成功通知
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// 警告通知
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// 错误通知
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
    
    // MARK: - 自定义场景反馈
    
    /// 拍照反馈 - 模拟快门音效
    func capture() {
        impactMedium.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.impactLight.impactOccurred()
            self?.impactMedium.prepare()
            self?.impactLight.prepare()
        }
    }
    
    /// 对焦成功反馈
    func focusLock() {
        impactSoft.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.impactSoft.impactOccurred()
            self?.impactSoft.prepare()
        }
    }
    
    /// 缩放反馈 - 到达预设点
    func zoomSnap() {
        impactRigid.impactOccurred()
        impactRigid.prepare()
    }
    
    /// 连续反馈 - 用于拖拽、滑动
    func continuous(intensity: CGFloat = 0.5) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: intensity)
    }
    
    /// 渐进式反馈序列 - 用于倒计时等场景
    func countdown(step: Int, total: Int) {
        if step == total {
            heavy()
        } else if step > total / 2 {
            medium()
        } else {
            light()
        }
    }
}

// MARK: - SwiftUI Button Extension

import SwiftUI

/// 为 View 添加触觉反馈支持
extension View {
    /// 添加触觉反馈的按钮修饰器
    func hapticFeedback(_ feedbackType: HapticFeedbackType = .light, onTap: Bool = true) -> some View {
        self.modifier(HapticFeedbackModifier(feedbackType: feedbackType, onTap: onTap))
    }
}

/// 触觉反馈类型
enum HapticFeedbackType {
    case light, medium, heavy, soft, rigid, selection
    case success, warning, error
    case capture, focusLock, zoomSnap
    
    func trigger() {
        let haptic = HapticManager.shared
        switch self {
        case .light: haptic.light()
        case .medium: haptic.medium()
        case .heavy: haptic.heavy()
        case .soft: haptic.soft()
        case .rigid: haptic.rigid()
        case .selection: haptic.selection()
        case .success: haptic.success()
        case .warning: haptic.warning()
        case .error: haptic.error()
        case .capture: haptic.capture()
        case .focusLock: haptic.focusLock()
        case .zoomSnap: haptic.zoomSnap()
        }
    }
}

/// 触觉反馈修饰器
private struct HapticFeedbackModifier: ViewModifier {
    let feedbackType: HapticFeedbackType
    let onTap: Bool
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        if onTap {
                            feedbackType.trigger()
                        }
                    }
            )
    }
}

#endif
