//
//  LiveCaptureApp.swift
//  LiveCapture
//
//  应用程序入口文件
//
//  ## 文件作用
//  定义应用程序的主入口点，使用 SwiftUI 的 @main 标记
//  配置应用的根视图和生命周期
//
//  ## 主要组件
//  - LiveCaptureApp: 应用程序结构体，继承自 App 协议
//
//  ## 依赖关系
//  - MainView: 应用的主界面视图
//

import SwiftUI

#if os(iOS)
@main
/// 应用入口
struct LiveCaptureApp: App {
	var body: some Scene {
		WindowGroup {
			MainTabView()
		}
	}
}
#endif