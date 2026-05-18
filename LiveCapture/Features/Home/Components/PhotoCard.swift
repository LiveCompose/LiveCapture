import SwiftUI

struct PhotoCard: View {
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
