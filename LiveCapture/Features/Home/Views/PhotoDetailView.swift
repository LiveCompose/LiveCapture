import SwiftUI

struct PhotoDetailView: View {
    let record: PhotoRecord
    let photo: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    Button {
                        generateAndShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // 照片
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12)

                Spacer()

                // 底部信息
                VStack(spacing: 4) {
                    Text(formattedDate)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: record.creationDate)
    }

    private func generateAndShare() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let card = ShareCardGenerator.generate(photo: photo) else { return }
            DispatchQueue.main.async {
                shareImage = card
                showShareSheet = true
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
