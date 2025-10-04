//
//  MainView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS)

/// 应用模式选项，便于扩展更多使用场景。
enum AppMode: String, CaseIterable, Identifiable {
    case user
    var id: String { rawValue }
    var title: String { "点击进入拍摄" }
    var description: String { "原神启动！" }
}

/// 应用首页，提供模式选择与导航到取景界面。
struct MainView: View {
    /// 当前选中的应用模式。
    @State private var selection: AppMode? = nil

    /// 构建模式列表与导航栈。
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
