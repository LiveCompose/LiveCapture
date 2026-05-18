import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.medium) {
                // App 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(DesignSystem.Colors.primaryGradient)
                        .frame(width: 88, height: 88)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.white)
                }

                // App 名称
                Text("LiveCapture")
                    .font(DesignSystem.Typography.title1)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // 副标题
                Text("构妙 · 智能构图助手")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                // 版本
                Text("版本 1.0")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.6))
            }

            Spacer()

            // 底部信息
            VStack(spacing: DesignSystem.Spacing.xxSmall) {
                Text("由 JettyCoffee 开发")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text("使用 SwiftUI 构建")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.6))
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}
