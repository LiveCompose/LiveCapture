//
//  LiveCaptureApp.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS)
@main
/// 应用入口
struct LiveCaptureApp: App {
	var body: some Scene {
		WindowGroup {
			MainView()
		}
	}
}
#endif