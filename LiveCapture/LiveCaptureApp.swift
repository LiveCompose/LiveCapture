//
//  LiveCaptureApp.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI

#if os(iOS)
@main
struct LiveCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
#endif