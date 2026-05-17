import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.records.isEmpty {
                    emptyStateView
                } else {
                    photoGrid
                }
            }
            .navigationTitle("LiveCapture")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.records.isEmpty {
                        Text("\(viewModel.records.count) photos")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 2), count: 3),
                spacing: 2
            ) {
                ForEach(viewModel.records) { record in
                    PhotoCard(
                        record: record,
                        thumbnailProvider: { [weak viewModel] id in
                            viewModel?.thumbnail(for: id)
                        }
                    )
                    .contextMenu { contextMenu(for: record) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for record: PhotoRecord) -> some View {
        Button {
            viewModel.toggleShared(record.id)
        } label: {
            Label(
                record.isShared ? "Remove from Community" : "Show in Community",
                systemImage: record.isShared ? "square.and.arrow.up.slash" : "square.and.arrow.up"
            )
        }

        if let photoURL = PhotoStorageService.shared.photoURL(for: record.id) {
            ShareLink(
                item: photoURL,
                preview: SharePreview("LiveCapture Photo")
            )
        }

        Divider()

        Button(role: .destructive) {
            viewModel.deleteRecord(record.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("No photos yet")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("Tap the Capture tab to start taking photos")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Spacer()
        }
    }
}
