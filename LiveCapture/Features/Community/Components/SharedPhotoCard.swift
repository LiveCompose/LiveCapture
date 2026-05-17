import SwiftUI

struct SharedPhotoCard: View {
    let record: PhotoRecord
    let thumbnailProvider: (UUID) -> UIImage?
    @State private var thumbnail: UIImage?

    var body: some View {
        Rectangle()
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(DesignSystem.Colors.backgroundSecondary)
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if let photoURL = PhotoStorageService.shared.photoURL(for: record.id) {
                    ShareLink(
                        item: photoURL,
                        preview: SharePreview("LiveCapture Photo")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .padding(6)
                    }
                }
            }
            .onAppear {
                guard thumbnail == nil else { return }
                DispatchQueue.global(qos: .utility).async {
                    let image = thumbnailProvider(record.id)
                    DispatchQueue.main.async {
                        thumbnail = image
                    }
                }
            }
    }
}
