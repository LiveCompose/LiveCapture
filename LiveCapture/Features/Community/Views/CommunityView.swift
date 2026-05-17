import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sharedRecords.isEmpty {
                    emptyStateView
                } else {
                    photoGrid
                }
            }
            .navigationTitle("Community")
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 2), count: 3),
                spacing: 2
            ) {
                ForEach(viewModel.sharedRecords) { record in
                    SharedPhotoCard(
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
        if let photoURL = viewModel.photoURL(for: record.id) {
            ShareLink(
                item: photoURL,
                preview: SharePreview("LiveCapture Photo")
            )
        }

        Button(role: .destructive) {
            viewModel.removeFromCommunity(record.id)
        } label: {
            Label("Remove from Community", systemImage: "square.and.arrow.up.slash")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("No shared photos")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("Long press a photo in the Photos tab to share it to the community")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
