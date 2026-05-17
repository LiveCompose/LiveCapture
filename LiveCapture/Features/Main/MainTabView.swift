import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .capture

    enum Tab: String, Hashable {
        case home
        case capture
        case community
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Photos", systemImage: selectedTab == .home ? "photo.fill" : "photo")
                }
                .tag(Tab.home)

            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: selectedTab == .capture ? "camera.fill" : "camera")
                }
                .tag(Tab.capture)

            CommunityView()
                .tabItem {
                    Label("Community", systemImage: selectedTab == .community ? "square.and.arrow.up.fill" : "square.and.arrow.up")
                }
                .tag(Tab.community)
        }
        .tint(DesignSystem.Colors.primary)
        .preferredColorScheme(.dark)
        .onAppear {
            _ = PhotoStorageService.shared.loadRecords()
        }
    }
}
