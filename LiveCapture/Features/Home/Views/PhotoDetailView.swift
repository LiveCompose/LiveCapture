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
                    metadataSection(record)
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            Group {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                } else {
                    ProgressView("正在生成分享卡片...")
                }
            }
        }
    }

    // MARK: - Metadata Section

    private func metadataSection(_ record: PhotoRecord) -> some View {
        VStack(spacing: 6) {
            Text(formattedDate(record.creationDate))
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            HStack(spacing: 16) {
                MetadataBadge(label: record.detectionMethod ?? "未知引擎")

                if let iso = record.iso {
                    MetadataBadge(label: "ISO \(Int(iso))")
                }

                if let shutter = record.shutterSpeed {
                    MetadataBadge(label: shutterDisplay(shutter))
                }

                if let aperture = record.aperture {
                    MetadataBadge(label: "f/\(String(format: "%.1f", aperture))")
                }
            }

            if let w = record.imageWidth, let h = record.imageHeight {
                Text("\(w) × \(h)")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.5))
            }
        }
    }

    // MARK: - Helpers

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

    private func shutterDisplay(_ speed: Double) -> String {
        if speed >= 1 {
            return "\(Int(speed))s"
        } else {
            return "1/\(Int(1.0 / speed))s"
        }
    }

    private func generateAndShare() {
        // 立即显示 sheet 以提供反馈
        showShareSheet = true

        guard let record = records[safe: currentIndex] else { return }

        // 如果照片尚未加载，等待加载完成
        if let photo = loadedPhotos[record.id] {
            generateCard(from: photo)
        } else {
            // 照片未加载，主动加载
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                if let photo = photoProvider(record.id) {
                    DispatchQueue.main.async {
                        self.loadedPhotos[record.id] = photo
                        self.generateCard(from: photo)
                    }
                }
            }
        }
    }

    private func generateCard(from photo: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let card = ShareCardGenerator.generate(photo: photo) else {
                DispatchQueue.main.async {
                    self.showShareSheet = false
                }
                return
            }
            DispatchQueue.main.async {
                self.shareImage = card
            }
        }
    }
}

// MARK: - Metadata Badge

private struct MetadataBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
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
