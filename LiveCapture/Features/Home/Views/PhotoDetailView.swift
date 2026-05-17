import SwiftUI

struct PhotoBrowserView: View {
    let records: [PhotoRecord]
    let initialIndex: Int
    let photoProvider: (UUID) -> UIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var loadedPhotos: [UUID: UIImage] = [:]

    init(records: [PhotoRecord], initialIndex: Int, photoProvider: @escaping (UUID) -> UIImage?) {
        self.records = records
        self.initialIndex = initialIndex
        self.photoProvider = photoProvider
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("返回")
                                .font(DesignSystem.Typography.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    Text("\(currentIndex + 1) / \(records.count)")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

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

                // 照片浏览器
                TabView(selection: $currentIndex) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        Group {
                            if let photo = loadedPhotos[record.id] {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .tag(index)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .tag(index)
                                    .onAppear {
                                        loadPhoto(for: record)
                                    }
                            }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 底部信息
                if let record = records[safe: currentIndex] {
                    VStack(spacing: 4) {
                        Text(formattedDate(record.creationDate))
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    private func loadPhoto(for record: PhotoRecord) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let photo = photoProvider(record.id) {
                DispatchQueue.main.async {
                    loadedPhotos[record.id] = photo
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func generateAndShare() {
        guard let record = records[safe: currentIndex],
              let photo = loadedPhotos[record.id] else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let card = ShareCardGenerator.generate(photo: photo) else { return }
            DispatchQueue.main.async {
                shareImage = card
                showShareSheet = true
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
