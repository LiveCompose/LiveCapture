//
//  MainView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS)

/// 应用模式选项，便于扩展更多使用场景。
enum AppMode: String, CaseIterable, Identifiable {
    case user
    var id: String { rawValue }
    var title: String { "智能拍摄" }
    var description: String { "AI 辅助构图，捕捉完美瞬间" }
    var icon: String { "camera.aperture" }
    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.6, blue: 1.0),
                Color(red: 0.6, green: 0.4, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 应用首页，提供模式选择与导航到取景界面。
struct MainView: View {
    /// 当前选中的应用模式。
    @State private var selection: AppMode? = nil
    @State private var isAnimating = false

    /// 构建模式列表与导航栈。
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // App Logo 和标题
                    VStack(spacing: 16) {
                        // Logo 图标
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.5, blue: 1.0),
                                            Color(red: 0.5, green: 0.3, blue: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: Color.blue.opacity(0.5), radius: 30, y: 10)
                            
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 60, weight: .light))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                .animation(
                                    .linear(duration: 20)
                                        .repeatForever(autoreverses: false),
                                    value: isAnimating
                                )
                        }
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        
                        Text("LiveCapture")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(y: isAnimating ? 0 : 20)
                        
                        Text("AI 智能构图助手")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(y: isAnimating ? 0 : 20)
                    }
                    .padding(.bottom, 40)
                    
                    // 模式选择卡片
                    VStack(spacing: 20) {
                        ForEach(AppMode.allCases) { mode in
                            NavigationLink(value: mode) {
                                ModeCard(mode: mode)
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    HapticManager.shared.medium()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 30)
                    
                    Spacer()
                    
                    // 底部提示
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(DesignSystem.Colors.accent)
                            Text("使用提示")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Text("点击取景界面右上角菜单可显示调试信息和调整设置")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .glassmorphism(cornerRadius: DesignSystem.CornerRadius.large, opacity: 0.1)
                    .padding(.horizontal, 24)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AppMode.self) { _ in
                ContentView()
            }
            .onAppear {
                withAnimation(DesignSystem.Animation.smooth.delay(0.2)) {
                    isAnimating = true
                }
            }
        }
    }
}

/// 模式选择卡片
private struct ModeCard: View {
    let mode: AppMode
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 20) {
            // 图标
            ZStack {
                Circle()
                    .fill(mode.gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)
                
                Image(systemName: mode.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // 文字信息
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(mode.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 箭头图标
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                        .fill(Color.white.opacity(0.05))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
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
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DesignSystem.Animation.quick, value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#endif
