//
//  ToastView.swift
//  LiveCapture
//
//  Toast 提示组件（已弃用）
//
//  ## 文件作用
//  提供轻量级的浮动提示消息
//  用于显示操作结果反馈
//  
//  注意: 此组件已不再使用，保留用于参考
//  当前版本使用 UserGuidanceView 替代 Toast 功能
//
//  ## 主要类型
//
//  ### ToastStyle 枚举
//  Toast 提示样式
//  
//  case:
//  - success: 成功提示（绿色，对勾图标）
//  - error: 错误提示（红色，叉号图标）
//  - warning: 警告提示（黄色，感叹号图标）
//  - info: 信息提示（蓝色，信息图标）
//  
//  属性:
//  - icon: String - SF Symbol 图标名称
//  - color: Color - 主题颜色
//
//  ### ToastView 结构体
//  Toast 提示视图
//  
//  参数:
//  - message: String - 提示消息文本
//  - style: ToastStyle - 样式类型
//  - isShowing: Binding<Bool> - 显示状态绑定
//  
//  UI 设计:
//  - 顶部居中显示
//  - 圆角卡片设计
//  - 半透明背景
//  - 图标 + 文字布局
//  - 滑入/滑出动画
//
//  ### ToastModifier 结构体
//  Toast 修饰器
//  
//  ViewModifier 实现，方便使用
//  
//  参数:
//  - isShowing: Binding<Bool> - 显示状态
//  - message: String - 消息文本
//  - style: ToastStyle - 样式
//  - duration: TimeInterval - 显示时长
//  
//  功能:
//  - 自动计时隐藏
//  - Z 轴层级管理
//  - 动画过渡
//
//  ## View 扩展
//  
//  ### toast(isShowing:message:style:duration:)
//  便捷方法添加 Toast
//  
//  参数:
//  - isShowing: Binding<Bool> - 显示控制
//  - message: String - 消息内容
//  - style: ToastStyle - 样式（默认 .info）
//  - duration: TimeInterval - 持续时间（默认 2.0s）
//  
//  使用示例:
//  ```swift
//  .toast(
//      isShowing: $showToast,
//      message: "保存成功",
//      style: .success,
//      duration: 2.0
//  )
//  ```
//
//  ## 弃用原因
//  - 与新的 UserGuidanceView 功能重复
//  - UserGuidanceView 提供更好的上下文集成
//  - 减少 UI 层级复杂度
//

#if os(iOS)
import SwiftUI

/// Toast 提示样式
enum ToastStyle {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return DesignSystem.Colors.success
        case .error: return DesignSystem.Colors.error
        case .warning: return DesignSystem.Colors.warning
        case .info: return DesignSystem.Colors.info
        }
    }
}

/// Toast 提示视图
struct ToastView: View {
    let message: String
    let style: ToastStyle
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            if isShowing {
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(style.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: style.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(style.color)
                    }
                    
                    // 消息文字
                    Text(message)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    style.color.opacity(0.5),
                                    style.color.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: style.color.opacity(0.3), radius: 15, y: 8)
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .animation(DesignSystem.Animation.bouncy, value: isShowing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

/// Toast 修饰器，方便使用
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let style: ToastStyle
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            ToastView(message: message, style: style, isShowing: $isShowing)
                .padding(.top, 80)
                .zIndex(999)
        }
        .onChange(of: isShowing) { _, newValue in
            if newValue {
                // 触发触觉反馈
                switch style {
                case .success:
                    HapticManager.shared.success()
                case .error:
                    HapticManager.shared.error()
                case .warning:
                    HapticManager.shared.warning()
                case .info:
                    HapticManager.shared.light()
                }
                
                // 自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

extension View {
    /// 添加 Toast 提示
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        style: ToastStyle = .info,
        duration: TimeInterval = 2.0
    ) -> some View {
        self.modifier(ToastModifier(
            isShowing: isShowing,
            message: message,
            style: style,
            duration: duration
        ))
    }
}

#endif
