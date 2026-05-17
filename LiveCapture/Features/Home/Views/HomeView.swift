import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部标题区
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // 拍摄入口按钮
                    captureButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // 分隔线
                    if !viewModel.records.isEmpty {
                        Divider()
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    // 照片网格 / 空状态
                    if viewModel.records.isEmpty {
                        emptyStateView
                    } else {
                        photoGrid
                            .padding(.horizontal, 2)
                    }
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $viewModel.showCapture) {
                ZStack {
                    CaptureView()

                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                viewModel.showCapture = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 56)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LiveCapture")
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("智能构图助手")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                Spacer()
                if !viewModel.records.isEmpty {
                    Text("\(viewModel.records.count) 张照片")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            viewModel.showCapture = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                Text("开始拍摄")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("使用智能构图，捕捉完美瞬间")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(viewModel.records) { record in
                NavigationLink {
                    PhotoDetailView(
                        record: record,
                        photo: viewModel.fullPhoto(for: record.id) ?? UIImage()
                    )
                } label: {
                    PhotoCard(
                        record: record,
                        thumbnailProvider: { [weak viewModel] id in
                            viewModel?.thumbnail(for: id)
                        }
                    )
                }
                .contextMenu { contextMenu(for: record) }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for record: PhotoRecord) -> some View {
        Button {
            viewModel.toggleShared(record.id)
        } label: {
            Label(
                record.isShared ? "从社区移除" : "分享到社区",
                systemImage: record.isShared ? "square.and.arrow.up.slash" : "square.and.arrow.up"
            )
        }

        Divider()

        Button(role: .destructive) {
            viewModel.deleteRecord(record.id)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer().frame(height: 60)
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("暂无照片")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("点击上方按钮开始拍摄")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
}
