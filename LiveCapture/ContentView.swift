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
    @Environment(\.dismiss) private var dismiss // 用于关闭当前视图

    /// 主视图内容，包含顶部控制区、取景区和底部控制栏。
    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets

            ZStack {
                // 底层黑色背景，扩展到安全区域之外确保覆盖整屏
                Color.black
                    .ignoresSafeArea()
                    .zIndex(0)

                // 底层为相机预览（固定在黑色底之上）
                previewSection()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .zIndex(0)

                // 顶层 UI（所有控制项都叠加在预览之上）
                VStack(spacing: 0) {
                    topSection

                    Spacer()

                    bottomSection(bottomInset: max(safeInsets.bottom, 16))
                        .padding(.bottom, safeInsets.bottom > 0 ? 0 : 16)
                }
                .zIndex(1)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            topControlBar

            if showDebugInfo {
                debugPanel
            }

        }
        .padding(.horizontal, 20)
    }

    private func previewSection() -> some View {
        GeometryReader { previewGeo in
            let compositionRect = Self.compositionRect(in: previewGeo.size)
            let canvasRect = CGRect(origin: .zero, size: previewGeo.size)

            ZStack {
                CameraPreviewView(session: viewModel.session)
                    .frame(width: compositionRect.width, height: compositionRect.height)
                    .position(x: compositionRect.midX, y: compositionRect.midY)
                    .clipped()

                ContentOverlayView(
                    compositionRect: compositionRect,
                    canvasRect: canvasRect,
                    cropRectInView: viewModel.cropRectInView,
                    boxCenterInView: viewModel.boxCenterInView,
                    isAligned: viewModel.isAligned,
                    topAdjustment: 0
                )
            }
            .onAppear {
                viewModel.registerCompositionRect(compositionRect)
            }
            .onChange(of: previewGeo.size) { newSize in
                viewModel.registerCompositionRect(Self.compositionRect(in: newSize))
            }
        }
    }

    private func bottomSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 25) {
                captureButton
            }

            HStack {
                secondaryCircleButton(systemName: "photo.on.rectangle") {
                    viewModel.openSystemPhotoLibrary()
                }
                Spacer()
                secondaryCircleButton(systemName: "arrow.triangle.2.circlepath.camera") {
                    viewModel.toggleCameraPosition()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    /// 顶部控制栏，包含返回、重置、调试显示和菜单操作。
    private var topControlBar: some View {
        ZStack {
            // 左右两端的按钮使用 HStack 布局，确保左侧按钮左对齐、右侧菜单右对齐
            HStack {
                topCircleButton(systemName: "chevron.left") { dismiss() }

                Spacer()

                Menu {
                    Button {
                        showDebugInfo.toggle()
                    } label: {
                        Label(showDebugInfo ? "隐藏调试模式" : "打开调试模式", systemImage: showDebugInfo ? "eye.slash" : "eye")
                    }

                    Button { resetDetectionState() } label: {
                        Label("刷新状态", systemImage: "arrow.counterclockwise")
                    }

                } label: {
                    topCircleLabel(systemName: "ellipsis")
                }
            }
            // 中心显示进度条，使用 ZStack 居中叠放，给进度条左右留出间距以避免与两侧按钮重叠
            statusProgressView
                .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var statusProgressView: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.pipelineProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(.green)
                .frame(height: 4)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: 80, alignment: .center) // 水平居中
        .frame(height: 40) // 与旁边圆形按钮高度一致（topCircleLabel 为 40x40）
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var captureButton: some View {
        Button(action: { viewModel.capturePhoto() }) {
            Circle()
                .strokeBorder(Color.white, lineWidth: 10)
                .frame(width: 78, height: 78)
                .overlay(Circle().fill(Color.white.opacity(0.15)))
        }
    }

    private func controlIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
                .opacity(0.9)
        }
    }

    private func secondaryCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                )
        }
    }

    private func topCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            topCircleLabel(systemName: systemName)
        }
    }

    private func topCircleLabel(systemName: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            )
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
