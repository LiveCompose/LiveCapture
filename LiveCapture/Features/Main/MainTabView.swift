import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String, Hashable {
        case home
        case help
        case about
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("主页", systemImage: selectedTab == .home ? "house.fill" : "house")
                }
                .tag(Tab.home)

            HelpView()
                .tabItem {
                    Label("帮助", systemImage: selectedTab == .help ? "questionmark.circle.fill" : "questionmark.circle")
                }
                .tag(Tab.help)

            AboutView()
                .tabItem {
                    Label("关于", systemImage: selectedTab == .about ? "info.circle.fill" : "info.circle")
                }
                .tag(Tab.about)
        }
        .tint(DesignSystem.Colors.primary)
        .preferredColorScheme(.dark)
        .onAppear {
            _ = PhotoStorageService.shared.loadRecords()
        }
    }
}
