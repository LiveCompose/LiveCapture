import SwiftUI

struct LiveComposeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    logoSection

                    introSection

                    developerSection

                    linksSection

                    projectsSection

                    techSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Spacer().frame(height: 40)

            Image("logo-LiveCompose")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(22)

            Text("构妙 LiveCompose")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("让每一次快门，都定格最美的瞬间")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(icon: "sparkles", title: "关于我们")

            Text("构妙 LiveCompose 致力于让每一位普通用户都能轻松拍出专业级构图照片。不同于传统相机的静态九宫格辅助线，我们通过 AI 实时分析取景画面，结合设备陀螺仪实现物理级追踪引导，主动「告诉」用户如何移动手机以获得最佳构图，并在对齐完美构图时自动拍摄。")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .lineSpacing(4)
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(icon: "folder", title: "项目仓库")

            ProjectCard(
                icon: "app.badge",
                name: "LiveCapture",
                desc: "iOS 客户端 App — 基于 SwiftUI 构建，集成 Adacrop 美学裁切模型、陀螺仪运动追踪与实时构图引导。支持 Vision / Fast / Pro 三种检测引擎，可在端侧离线运行。",
                url: "https://github.com/LiveCompose/LiveCapture"
            )

            ProjectCard(
                icon: "cpu",
                name: "LiveCompose",
                desc: "核心模型仓库 — 包含 Adacrop 强化学习训练框架、模型定义与实验配置。基于 PyTorch 构建，通过知识蒸馏产出 Student/Teacher 两种规格的 CoreML 模型，供端侧部署。",
                url: "https://github.com/LiveCompose/LiveCompose"
            )
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(icon: "link", title: "资源链接")

            LinkRow(
                imageName: "icon-github",
                title: "GitHub 组织",
                subtitle: "github.com/LiveCompose",
                url: "https://github.com/LiveCompose"
            )

            LinkRow(
                imageName: "icon-huggingface",
                title: "HuggingFace 模型库",
                subtitle: "huggingface.co/LiveCompose",
                url: "https://huggingface.co/LiveCompose"
            )
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Tech

    private var techSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(icon: "gearshape.2", title: "核心技术")

            VStack(spacing: 0) {
                techRow("cpu", "Adacrop 强化学习模型",
                        "基于 Actor-Critic 架构的自适应美学裁切。BBox 网络定位兴趣区域，Actor 网络输出 7 种构图调整动作（平移/缩放/终止），通过知识蒸馏产出 Fast（Student）与 Pro（Teacher）两种端侧模型。")
                Divider().background(DesignSystem.Colors.backgroundSecondary)
                techRow("gyroscope", "陀螺仪运动追踪",
                        "实时采集设备角速度与加速度，自适应平滑算法将物理移动映射为取景框内的对齐指引。含磁吸归中、速度预测与滞后防抖机制。")
                Divider().background(DesignSystem.Colors.backgroundSecondary)
                techRow("eye", "Vision 原生检测",
                        "集成 Apple Vision 框架的人脸、人体与显著性区域检测，在无 CoreML 模型时提供快速零依赖构图建议。")
                Divider().background(DesignSystem.Colors.backgroundSecondary)
                techRow("camera.aperture", "多镜头智能变焦",
                        "自动识别超广角、广角、长焦等多种物理镜头，提供离散预设与连续变焦两种模式，覆盖 0.5×–5× 焦段。")
            }
            .background(cardBackground)
        }
    }

    // MARK: - Developers

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(icon: "person.3", title: "核心开发者")

            DeveloperRow(
                avatarName: "avatar-JettyCoffee",
                name: "Ziqian Chen",
                role: "项目负责人",
                url: "https://github.com/JettyCoffee"
            )

            DeveloperRow(
                avatarName: "avatar-ZyanNo1",
                name: "Zeyan Li",
                role: "核心开发者",
                url: "https://github.com/ZyanNo1"
            )

            DeveloperRow(
                avatarName: "avatar-zzsyppt",
                name: "Jialiang Li",
                role: "核心开发者",
                url: "https://github.com/zzsyppt"
            )
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .fill(DesignSystem.Colors.backgroundSecondary)
    }

    private func techRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(desc)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .lineSpacing(3)
            }
        }
        .padding(DesignSystem.Spacing.medium)
    }
}

// MARK: - Shared Components

private struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

private struct ProjectCard: View {
    let icon: String
    let name: String
    let desc: String
    let url: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text(name)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Button {
                    if let u = URL(string: url) { openURL(u) }
                } label: {
                    Image(systemName: "arrow.up.forward.circle")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            Text(desc)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .lineSpacing(3)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.backgroundTertiary)
        )
    }
}

private struct LinkRow: View {
    let imageName: String
    let title: String
    let subtitle: String
    let url: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let u = URL(string: url) { openURL(u) }
        } label: {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.circle")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.backgroundTertiary)
        )
    }
}

private struct DeveloperRow: View {
    let avatarName: String
    let name: String
    let role: String
    let url: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let u = URL(string: url) { openURL(u) }
        } label: {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(avatarName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(role)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.circle")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.backgroundTertiary)
        )
    }
}
