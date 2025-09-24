//
//  LiveCaptureApp.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI

#if os(iOS) || os(tvOS)
@main
struct LiveCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#else
struct LiveCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Unsupported Platform")
        }
    }
}
#endif