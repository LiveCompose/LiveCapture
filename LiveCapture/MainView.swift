//
//  MainView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS) || os(tvOS)

enum AppMode: String, CaseIterable, Identifiable {
    case user
    var id: String { rawValue }
    var title: String { "拍摄模式" }
    var description: String { "默认界面，可通过右下角按钮切换调试信息。" }
}

struct MainView: View {
    @State private var selection: AppMode? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("选择模式") {
                    ForEach(AppMode.allCases) { mode in
                        NavigationLink(value: mode) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title).font(.headline)
                                Text(mode.description).font(.subheadline).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Section("提示") {
                    Text("点击取景界面底部的“眼睛”按钮可随时显示或隐藏调试信息。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("LiveCapture")
            .navigationDestination(for: AppMode.self) { _ in
                ContentView()
            }
        }
    }
}

#endif
