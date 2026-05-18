import SwiftUI

struct MainTabView: View {
    @AppStorage("detectionMode") private var detectionMode: DetectionMode = .fast
    @AppStorage("autoCaptureEnabled") private var autoCaptureEnabled = true
    @AppStorage("captureDelay") private var captureDelay: Double = 1.0
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @State private var selectedTab: Tab = .livecompose
    @State private var showCapture = false

    enum Tab: String, Hashable {
        case gallery, livecompose, settings, camera
    }

    private var resolvedScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LiveComposeView()
                .tabItem {
                    Label("构妙", systemImage: "house.fill")
                }
                .tag(Tab.livecompose)

            GalleryView()
                .tabItem {
                    Label("图库", systemImage: selectedTab == .gallery ? "photo.on.rectangle.fill" : "photo.on.rectangle")
                }
                .tag(Tab.gallery)

            Color.clear
                .tabItem {
                    Image(systemName: "camera.fill")
                        .environment(\.symbolVariants, .none)
                    Text("拍摄")
                }
                .tag(Tab.camera)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(DesignSystem.Colors.primary)
        .preferredColorScheme(resolvedScheme)
        .onAppear {
            _ = PhotoStorageService.shared.loadRecords()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .camera {
                showCapture = true
                DispatchQueue.main.async {
                    selectedTab = .livecompose
                }
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView(
                detectionMode: detectionMode,
                isAutoCaptureEnabled: autoCaptureEnabled,
                captureDelay: captureDelay
            )
            .preferredColorScheme(.dark)
        }
    }
}
