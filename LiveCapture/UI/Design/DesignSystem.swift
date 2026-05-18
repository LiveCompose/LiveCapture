//
//  DesignSystem.swift
//  LiveCapture
//
//  统一的设计系统
//
//  ## 文件作用
//  定义应用的所有视觉设计规范
//  包括颜色、字体、动画、圆角等常量
//  确保整个应用的视觉一致性
//
//  ## 主要枚举
//
//  ### Colors 颜色系统
//  
//  #### 主色调
//  - primary: Color - 清新蓝色 (0.0, 0.48, 1.0)
//  - secondary: Color - 紫罗兰 (0.35, 0.34, 0.84)
//  - accent: Color - 活力橙 (1.0, 0.58, 0.0)
//
//  #### 语义化颜色
//  - success: Color - 成功绿 (0.2, 0.78, 0.35)
//  - warning: Color - 警告黄 (1.0, 0.8, 0.0)
//  - error: Color - 错误红 (1.0, 0.23, 0.19)
//  - info: Color - 信息蓝 (0.35, 0.78, 0.98)
//
//  #### 文字颜色
//  - textPrimary: Color - 主文字（白色）
//  - textSecondary: Color - 次要文字（80% 白色）
//  - textTertiary: Color - 三级文字（60% 白色）
//
//  #### 背景颜色
//  - backgroundPrimary: Color - 主背景（黑色）
//  - backgroundSecondary: Color - 次背景（10% 白色）
//  - backgroundTertiary: Color - 三级背景（5% 白色）
//
//  #### 渐变色
//  - primaryGradient: LinearGradient - 主色调渐变
//  - accentGradient: LinearGradient - 强调色渐变
//  - successGradient: LinearGradient - 成功色渐变
//  - warningGradient: LinearGradient - 警告色渐变
//  - errorGradient: LinearGradient - 错误色渐变
//
//  ### Typography 字体系统
//  
//  #### 标题
//  - largeTitle: Font - 大标题 (34pt, bold, rounded)
//  - title1: Font - 一级标题 (28pt, bold, rounded)
//  - title2: Font - 二级标题 (22pt, bold, rounded)
//  - title3: Font - 三级标题 (20pt, semibold, rounded)
//
//  #### 正文
//  - headline: Font - 标题文字 (17pt, semibold, rounded)
//  - body: Font - 正文 (17pt, regular, rounded)
//  - callout: Font - 提示文字 (16pt, regular, rounded)
//  - subheadline: Font - 子标题 (15pt, regular, rounded)
//  - footnote: Font - 脚注 (13pt, regular, rounded)
//  - caption1: Font - 说明文字1 (12pt, regular, rounded)
//  - caption2: Font - 说明文字2 (11pt, regular, rounded)
//
//  ### Spacing 间距系统
//  标准化的间距值：
//  - xxSmall: CGFloat = 4
//  - xSmall: CGFloat = 8
//  - small: CGFloat = 12
//  - medium: CGFloat = 16
//  - large: CGFloat = 24
//  - xLarge: CGFloat = 32
//  - xxLarge: CGFloat = 48
//
//  ### CornerRadius 圆角系统
//  标准化的圆角值：
//  - small: CGFloat = 8
//  - medium: CGFloat = 12
//  - large: CGFloat = 16
//  - xLarge: CGFloat = 24
//  - circle: CGFloat = .infinity
//
//  ### Shadow 阴影系统
//  预定义的阴影效果：
//  - small: (color, radius, x, y)
//    轻微阴影，用于卡片
//  - medium: (color, radius, x, y)
//    中等阴影，用于浮动元素
//  - large: (color, radius, x, y)
//    深度阴影，用于模态对话框
//
//  ### Animation 动画系统
//  标准化的动画配置：
//  - quick: Animation - 快速动画 (0.2s, easeOut)
//  - smooth: Animation - 平滑动画 (0.3s, easeInOut)
//  - bouncy: Animation - 弹性动画 (spring, 0.5s, 0.7)
//  - gentle: Animation - 柔和动画 (spring, 0.6s, 0.8)
//
//  ## 使用示例
//  ```swift
//  Text("标题")
//      .font(DesignSystem.Typography.title1)
//      .foregroundColor(DesignSystem.Colors.textPrimary)
//  
//  Rectangle()
//      .fill(DesignSystem.Colors.primaryGradient)
//      .cornerRadius(DesignSystem.CornerRadius.large)
//  
//  withAnimation(DesignSystem.Animation.smooth) {
//      // 动画代码
//  }
//  ```
//
//  ## 设计原则
//  - 一致性：统一的视觉语言
//  - 可访问性：清晰的颜色对比
//  - 可维护性：集中管理设计参数
//  - 灵活性：易于调整和扩展
//

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
        
        // 中性色（自适应深色/浅色模式）
        static let textPrimary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        })
        static let textSecondary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.8) : UIColor.black.withAlphaComponent(0.65)
        })
        static let textTertiary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.6) : UIColor.black.withAlphaComponent(0.45)
        })

        // 背景色（自适应深色/浅色模式）
        static let backgroundPrimary = Color(uiColor: .systemBackground)
        static let backgroundSecondary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.1) : UIColor.black.withAlphaComponent(0.06)
        })
        static let backgroundTertiary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.05) : UIColor.black.withAlphaComponent(0.03)
        })
        
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
