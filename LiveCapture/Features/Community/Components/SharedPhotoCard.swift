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
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .padding(4)
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
