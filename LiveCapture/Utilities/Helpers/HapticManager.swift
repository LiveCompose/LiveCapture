//
//  HapticManager.swift
//  LiveCapture
//
//  触觉反馈管理器
//
//  ## 文件作用
//  提供统一的触觉反馈（震动）接口
//  封装 UIKit 的 Haptic Feedback API
//  为应用的所有交互提供一致的反馈体验
//
//  ## 主要类
//  ### HapticManager
//  触觉反馈管理器（单例模式）
//
//  ## 使用方式
//  ```swift
//  HapticManager.shared.light()      // 轻触反馈
//  HapticManager.shared.success()    // 成功反馈
//  HapticManager.shared.capture()    // 拍照反馈
//  ```
//
//  ## 反馈类型
//
//  ### 通用交互反馈
//  - light(): 轻触反馈
//    用途: 按钮点击、轻量操作
//    强度: 最轻
//
//  - medium(): 中等反馈
//    用途: 重要操作、模式切换
//    强度: 中等
//
//  - heavy(): 重度反馈
//    用途: 关键操作、删除确认
//    强度: 最重
//
//  - soft(): 柔和反馈
//    用途: 微妙的状态变化
//    强度: 轻柔
//
//  - rigid(): 刚性反馈
//    用途: 精确操作、锁定状态
//    强度: 明确清脆
//
//  ### 选择反馈
//  - selection(): 选择反馈
//    用途: 菜单选择、选项切换
//    特点: 轻快连续
//
//  ### 通知反馈
//  - success(): 成功反馈
//    用途: 操作成功、任务完成
//    模式: 成功提示音振动
//
//  - warning(): 警告反馈
//    用途: 需要注意、状态异常
//    模式: 警告提示音振动
//
//  - error(): 错误反馈
//    用途: 操作失败、错误发生
//    模式: 错误提示音振动
//
//  ### 专用场景反馈
//  - capture(): 拍照反馈
//    组合: medium + success
//    用途: 拍照快门
//    特点: 即时反馈 + 成功确认
//
//  - focusLock(): 对焦锁定反馈
//    组合: soft + success（延迟）
//    用途: 追踪点对齐中心
//    特点: 柔和触发 + 确认反馈
//
//  - alignmentChange(): 对齐状态变化反馈
//    用途: 进入/离开对齐状态
//    实现: light
//
//  ## 实现细节
//
//  ### 预生成引擎
//  - 在初始化时创建所有反馈生成器
//  - 避免使用时的延迟
//  - 提升响应速度
//
//  ### prepare() 方法
//  - 预热所有震动引擎
//  - 减少首次触发延迟
//  - 在应用启动时调用
//
//  ### 自动准备
//  - 每次触发后自动 prepare()
//  - 确保下次触发的低延迟
//
//  ## 底层 API
//  - UIImpactFeedbackGenerator: 物理冲击反馈
//    样式: light, medium, heavy, soft, rigid
//
//  - UISelectionFeedbackGenerator: 选择反馈
//    无样式参数，固定轻快风格
//
//  - UINotificationFeedbackGenerator: 通知反馈
//    类型: success, warning, error
//
//  ## 最佳实践
//  - 使用语义化方法名
//  - 避免过度使用震动
//  - 匹配反馈强度与操作重要性
//  - 在关键时刻提供反馈
//

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
