import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String, Hashable {
        case home
        case community
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("相册", systemImage: selectedTab == .home ? "photo.fill" : "photo")
                }
                .tag(Tab.home)

            CommunityView()
                .tabItem {
                    Label("社区", systemImage: selectedTab == .community ? "square.and.arrow.up.fill" : "square.and.arrow.up")
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
