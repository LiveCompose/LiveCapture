//
//  ContentView.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// iOS 主取景界面与功能入口，仅在 iOS 平台编译。
#if os(iOS)

/// iOS 主取景界面，负责相机预览、模板匹配以及提示反馈。
struct ContentView: View {
    /// 业务逻辑容器。
    @StateObject private var viewModel = ContentViewModel()
    /// 默认隐藏调试栏，由按钮控制。
    @State private var showDebugInfo = false

    /// 主视图内容，包含相机预览、覆盖层以及底部控制栏。
    var body: some View {
        GeometryReader { geo in
            let compositionRect = Self.compositionRect(in: geo.size)
            let canvasRect = CGRect(origin: .zero, size: geo.size)
            let topAdjustment = Self.topAdjustment()

            ZStack {
                Color.black
                    .ignoresSafeArea()

                CameraPreviewView(session: viewModel.session)
                    .frame(width: compositionRect.width, height: compositionRect.height)
                    .position(x: compositionRect.midX, y: compositionRect.midY - topAdjustment)
                    .clipped()

                ContentOverlayView(
                    compositionRect: compositionRect,
                    canvasRect: canvasRect,
                    cropRectInView: viewModel.cropRectInView,
                    boxCenterInView: viewModel.boxCenterInView,
                    isAligned: viewModel.isAligned,
                    topAdjustment: topAdjustment
                )

                bottomControlBar
            }
            .onAppear {
                viewModel.registerCompositionRect(compositionRect)
            }
            .onChange(of: geo.size) { newSize in
                viewModel.registerCompositionRect(Self.compositionRect(in: newSize))
            }
            .overlay(alignment: .top) { topOverlay }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    @ViewBuilder
    private var bottomControlBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 25) {
                Button(action: {}) {
                    Image(systemName: "bolt.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(0.9)
                }
                Button(action: { showDebugInfo.toggle() }) {
                    Image(systemName: showDebugInfo ? "eye.slash.circle" : "eye.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(0.9)
                }
                Spacer()
                Button(action: { viewModel.capturePhoto() }) {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 10)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().fill(Color.white.opacity(0.15)))
                }
                Spacer()
                Button(action: { resetDetectionState() }) {
                    Image(systemName: "gobackward")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(0.9)
                }
                Button(action: {}) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(0.9)
                }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 75)
        }
    }

    @ViewBuilder
    private var topOverlay: some View {
        VStack(spacing: 8) {
            if showDebugInfo {
                debugPanel
            }

            if viewModel.showSaveToast {
                Text("已保存")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var debugPanel: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("调试信息")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("隐藏") { showDebugInfo = false }
                        .font(.caption2)
                }

                Text("状: \(viewModel.debugMessage)")
                    .font(.caption2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("稳定性: \(viewModel.motionIsStable ? "稳定" : "不稳定")")
                        Spacer()
                        if let center = viewModel.boxCenterInView {
                            Text("跟踪: (\(Int(center.x)), \(Int(center.y)))")
                        } else {
                            Text("跟踪: 无")
                        }
                    }
                    HStack {
                        if let sim = viewModel.lastSimilarity {
                            Text("相似度: \(String(format: "%.2f", sim)) / \(String(format: "%.2f", viewModel.similarityThreshold))")
                        } else {
                            Text("相似度: --")
                        }
                        Spacer()
                        Text(viewModel.templateReady ? "模板: 已就绪" : "模板: 未就绪")
                    }
                }
                .font(.caption2)

                Text("对准: \(viewModel.isAligned ? "已对准" : "未对准")")
                    .font(.caption2)
                    .foregroundColor(viewModel.isAligned ? .green : .primary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)

            #if canImport(UIKit)
            HStack(spacing: 8) {
                if let img = viewModel.templatePreviewImage() {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                        .frame(width: 64, height: 64)
                        .border(Color.white.opacity(0.8), width: 1)
                        .overlay(Text("T").font(.caption2).padding(2), alignment: .topLeading)
                }
                if let centerImg = viewModel.centerPreviewImage() {
                    Image(uiImage: centerImg)
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                        .frame(width: 64, height: 64)
                        .border(Color.white.opacity(0.8), width: 1)
                        .overlay(Text("C").font(.caption2).padding(2), alignment: .topLeading)
                }
            }
            .padding(.horizontal, 16)
            #endif
        }
    }

    private static func topAdjustment() -> CGFloat {
        var inset: CGFloat = 0
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            inset = window.safeAreaInsets.top
        }
        #endif
        return inset + 24
    }

    private static func compositionRect(in size: CGSize) -> CGRect {
        let width = size.width
        let targetHeight = width * 4.0 / 3.0
        let height = min(size.height, targetHeight)
        let originY = (size.height - height) * 0.5
        return CGRect(x: 0, y: originY, width: width, height: height)
    }

    private func resetDetectionState() {
        viewModel.resetDetectionState()
    }
}
#endif
