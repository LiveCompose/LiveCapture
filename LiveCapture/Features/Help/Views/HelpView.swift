import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    headerSection
                    usageSections
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("使用帮助")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("快速上手 LiveCapture")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Usage Sections

    private var usageSections: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HelpCard(
                icon: "camera.fill",
                title: "开始拍摄",
                description: "在主页点击「开始拍摄」按钮进入相机。将手机对准拍摄对象，App 会自动分析画面并给出构图建议。"
            )

            HelpCard(
                icon: "wand.and.stars",
                title: "智能构图",
                description: "点击拍摄界面底部的魔法棒按钮开启构图流水线。屏幕中央会出现辅助框和对齐圆点，移动手机将圆点对准中心即可触发自动拍摄。"
            )

            HelpCard(
                icon: "rectangle.3.group",
                title: "浏览照片",
                description: "拍摄的照片会自动保存在主页的相册网格中。点击照片可进入全屏浏览模式，左右滑动切换照片，点击分享按钮可生成精美分享卡片。"
            )

            HelpCard(
                icon: "hand.draw",
                title: "变焦操作",
                description: "在拍摄界面双指捏合可连续变焦，或点击变焦环上的预设镜头快速切换。支持超广角、广角、长焦等多种镜头。"
            )

            HelpCard(
                icon: "arrow.triangle.2.circlepath.camera",
                title: "切换摄像头",
                description: "点击屏幕底部的切换按钮可在前置和后置摄像头之间切换。智能构图同时支持前后摄像头。"
            )

            HelpCard(
                icon: "gearshape",
                title: "拍摄设置",
                description: "通过顶部菜单可开启自动拍照模式、设置拍照延迟时间。开启自动拍照后，对准构图框即可自动触发拍摄，无需手动按快门。"
            )
        }
    }
}

// MARK: - Help Card

private struct HelpCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(DesignSystem.Colors.primary.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(description)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .lineSpacing(2)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.backgroundSecondary)
        )
    }
}
