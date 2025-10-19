//
//  DesignSystem.swift
//  LiveCapture
//
//  统一的设计系统，定义颜色、字体、样式等

#if os(iOS)
import SwiftUI

/// 设计系统 - 统一的 UI 规范
enum DesignSystem {
    
    // MARK: - Colors
    
    enum Colors {
        // 主色调
        static let primary = Color(red: 0.0, green: 0.48, blue: 1.0) // 清新蓝色
        static let secondary = Color(red: 0.35, green: 0.34, blue: 0.84) // 紫罗兰
        static let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // 活力橙
        
        // 语义化颜色
        static let success = Color(red: 0.2, green: 0.78, blue: 0.35) // 成功绿
        static let warning = Color(red: 1.0, green: 0.8, blue: 0.0) // 警告黄
        static let error = Color(red: 1.0, green: 0.23, blue: 0.19) // 错误红
        static let info = Color(red: 0.35, green: 0.78, blue: 0.98) // 信息蓝
        
        // 中性色
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.8)
        static let textTertiary = Color.white.opacity(0.6)
        
        // 背景色
        static let backgroundPrimary = Color.black
        static let backgroundSecondary = Color.white.opacity(0.1)
        static let backgroundTertiary = Color.white.opacity(0.05)
        
        // 渐变色
        static let primaryGradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [accent, Color(red: 1.0, green: 0.4, blue: 0.4)],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let successGradient = LinearGradient(
            colors: [success, Color(red: 0.4, green: 0.9, blue: 0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // 单等宽字体
        static let monoBody = Font.system(size: 17, weight: .regular, design: .monospaced)
        static let monoCaption = Font.system(size: 13, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
        static let xxxLarge: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let circle: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static func small(color: Color = .black) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.1), 4, 0, 2)
        }
        
        static func medium(color: Color = .black) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.2), 8, 0, 4)
        }
        
        static func large(color: Color = .black) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.3), 16, 0, 8)
        }
        
        static func glow(color: Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.6), 12, 0, 0)
        }
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.9)
        
        static let easeIn = SwiftUI.Animation.easeIn(duration: 0.2)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - View Modifiers

/// 玻璃态效果
struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.medium
    var opacity: Double = 0.15
    var blur: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white.opacity(opacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// 新拟态效果
struct NeumorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.medium
    var isPressed: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))
                    .shadow(color: .white.opacity(isPressed ? 0.1 : 0.2), radius: isPressed ? 2 : 8, x: isPressed ? 2 : -8, y: isPressed ? 2 : -8)
                    .shadow(color: .black.opacity(isPressed ? 0.4 : 0.3), radius: isPressed ? 2 : 8, x: isPressed ? -2 : 8, y: isPressed ? -2 : 8)
            )
    }
}

/// 发光效果
struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 12
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
    }
}

/// 脉动动画
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    var color: Color
    var duration: Double = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
            )
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// 应用玻璃态效果
    func glassmorphism(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium, opacity: Double = 0.15) -> some View {
        self.modifier(GlassmorphismModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    /// 应用新拟态效果
    func neumorphism(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium, isPressed: Bool = false) -> some View {
        self.modifier(NeumorphismModifier(cornerRadius: cornerRadius, isPressed: isPressed))
    }
    
    /// 应用发光效果
    func glow(color: Color, radius: CGFloat = 12) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius))
    }
    
    /// 应用脉动效果
    func pulse(color: Color, duration: Double = 1.5) -> some View {
        self.modifier(PulseModifier(color: color, duration: duration))
    }
    
    /// 添加标准阴影
    func standardShadow(style: ShadowStyle = .medium) -> some View {
        let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
        switch style {
        case .small:
            shadow = DesignSystem.Shadows.small()
        case .medium:
            shadow = DesignSystem.Shadows.medium()
        case .large:
            shadow = DesignSystem.Shadows.large()
        }
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

enum ShadowStyle {
    case small, medium, large
}

// MARK: - Custom Button Styles

/// 主按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(isEnabled ? DesignSystem.Colors.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

/// 次要按钮样式
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .glassmorphism()
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

#endif
