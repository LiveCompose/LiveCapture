//
//  MainView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS) || os(tvOS)

enum AppMode: String, CaseIterable, Identifiable {
    case user
    case debug
    var id: String { rawValue }
    var title: String { self == .user ? "用户模式" : "调试模式" }
    var description: String {
        switch self {
        case .user:
            return "简洁拍摄界面，参考系统相机布局。"
        case .debug:
            return "显示稳定性、相似度、模板缩略图等调试信息。"
        }
    }
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
                    Text("建议在光线充足下体验用户模式；调试模式将显示更多传感器与匹配参数。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("LiveCapture")
            .navigationDestination(for: AppMode.self) { mode in
                ContentView(mode: mode)
            }
        }
    }
}

#endif
