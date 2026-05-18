import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedPhotoIndex: Int?
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部栏
                    HStack {
                        Text("图库")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        if isSelectionMode {
                            Spacer()
                            Button {
                                viewModel.deleteRecords(Array(selectedIDs))
                                selectedIDs.removeAll()
                                isSelectionMode = false
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedIDs.isEmpty ? DesignSystem.Colors.textTertiary : .red)
                                    .padding(12)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                            .disabled(selectedIDs.isEmpty)

                            Button {
                                isSelectionMode = false
                                selectedIDs.removeAll()
                            } label: {
                                Text("取消")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .padding(.leading, 8)
                            }
                        } else {
                            Spacer()
                            if !viewModel.records.isEmpty {
                                Text("\(viewModel.records.count) 张照片")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if !isSelectionMode && !viewModel.records.isEmpty {
                        guidanceBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    if viewModel.records.isEmpty {
                        emptyStateView
                    } else {
                        photoGrid
                            .padding(.horizontal, 2)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedPhotoIndex) { index in
                PhotoBrowserView(
                    records: viewModel.records,
                    initialIndex: index,
                    photoProvider: { [weak viewModel] id in
                        viewModel?.fullPhoto(for: id)
                    }
                )
            }
        }
    }

    // MARK: - Guidance

    private var guidanceBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.primary)
            Text("点击照片浏览 · 长按多选删除 · 进入照片可导出精美卡片")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.backgroundSecondary)
        )
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                Button {
                    if isSelectionMode {
                        toggleSelection(record.id)
                    } else {
                        selectedPhotoIndex = index
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        PhotoCard(
                            record: record,
                            thumbnailProvider: { [weak viewModel] id in
                                viewModel?.thumbnail(for: id)
                            }
                        )

                        if isSelectionMode {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.black.opacity(0.4))

                            Image(systemName: selectedIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(selectedIDs.contains(record.id) ? DesignSystem.Colors.primary : .white.opacity(0.7))
                                .padding(6)
                        }
                    }
                }
                .contextMenu { contextMenu(for: record) }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        if !isSelectionMode {
                            isSelectionMode = true
                            selectedIDs = [record.id]
                        }
                    }
                )
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            if selectedIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            selectedIDs.insert(id)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for record: PhotoRecord) -> some View {
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
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 56))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("暂无照片")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("使用下方拍摄按钮开始创作")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
