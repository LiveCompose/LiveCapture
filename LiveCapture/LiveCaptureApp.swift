//
//  LiveCaptureApp.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI

#if os(iOS)
@main
/// 应用入口，托管 SwiftUI 场景并加载主界面。
struct LiveCaptureApp: App {
    /// 定义应用主窗口与默认根视图。
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif