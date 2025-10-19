//
//  ToastView.swift
//  LiveCapture
//
//  优雅的 Toast 提示组件

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
