import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("社区")
                                    .font(DesignSystem.Typography.largeTitle)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text("分享你的精彩瞬间")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    if !viewModel.sharedRecords.isEmpty {
                        Divider()
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    if viewModel.sharedRecords.isEmpty {
                        emptyStateView
                    } else {
                        photoGrid
                            .padding(.horizontal, 2)
                    }
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedPhotoIndex) { index in
                PhotoBrowserView(
                    records: viewModel.sharedRecords,
                    initialIndex: index,
                    photoProvider: { [weak viewModel] id in
                        viewModel?.fullPhoto(for: id)
                    }
                )
            }
        }
    }

    private var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(Array(viewModel.sharedRecords.enumerated()), id: \.element.id) { index, record in
                Button {
                    selectedPhotoIndex = index
                } label: {
                    SharedPhotoCard(
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

    @ViewBuilder
    private func contextMenu(for record: PhotoRecord) -> some View {
        Button(role: .destructive) {
            viewModel.removeFromCommunity(record.id)
        } label: {
            Label("从社区移除", systemImage: "square.and.arrow.up.slash")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer().frame(height: 60)
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 56))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("暂无分享")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("在相册中长按照片，选择「分享到社区」")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
