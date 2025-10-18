//
//  ContentView.swift
//  LiveCapture
//

/// iOS 主取景界面与功能入口，仅在 iOS 平台编译。
#if os(iOS)
import SwiftUI
import UIKit
/// iOS 主取景界面，负责相机预览、模板匹配以及提示反馈。
struct ContentView: View {
    /// 业务逻辑容器。
    @StateObject private var viewModel = ContentViewModel()
    /// 默认隐藏调试栏，由按钮控制。
    @State private var showDebugInfo = false
    /// 记录双指缩放起始时的倍率，便于根据手势比例计算目标倍率。
    @State private var pinchInitialFactor: CGFloat = 1.0
    /// 标记当前是否正在执行双指缩放，避免重复初始化起始倍率。
    @State private var pinchActive = false
    @Environment(\.dismiss) private var dismiss // 用于关闭当前视图

    /// 主视图内容，包含顶部控制区、取景区和底部控制栏。
    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets // 考虑刘海屏等安全区域

            ZStack {
                // 底层黑色背景，扩展到安全区域之外确保覆盖整屏
                Color.black
                    .ignoresSafeArea()
                    .zIndex(0)

                // 底层为相机预览（固定在黑色底之上）
                CameraPreviewSection()
                    .frame(width: geo.size.width, height: geo.size.height) // 适配全屏
                    .ignoresSafeArea() //
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

    /// 顶部区域，包含控制栏与可选调试面板。
    private var topSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            topControlBar
            if showDebugInfo {
                debugPanel
            }
        }
        .padding(.horizontal, 20)
    }

    /// 构建相机预览与覆盖层的组合视图。
    private func CameraPreviewSection() -> some View {
        GeometryReader { previewGeo in
            let compositionRect = Self.compositionRect(in: previewGeo.size) // 3:4 构图区域
            let canvasRect = CGRect(origin: .zero, size: previewGeo.size) // 整个画布区域

            ZStack {
                CameraPreviewView(session: viewModel.session)
                    .frame(width: compositionRect.width, height: compositionRect.height)
                    .position(x: compositionRect.midX, y: compositionRect.midY)
                    .clipped()

                ContentOverlayView(
                    compositionRect: compositionRect,
                    canvasRect: canvasRect,
                    cropRectInView: viewModel.cropRectInView, // 裁剪框（可选）
                    boxCenterInView: viewModel.boxCenterInView, // 跟踪框中心（可选）
                    isAligned: viewModel.isAligned, // 对齐状态
                    distanceToCenter: viewModel.distanceToCenter // 距离中心的距离（用于颜色渐变）
                )
            }
            .onAppear {
                viewModel.registerCompositionRect(compositionRect)
            }
            .onChange(of: previewGeo.size) { _, newSize in
                viewModel.registerCompositionRect(Self.compositionRect(in: newSize))
            }
        }
        .gesture(pinchZoomGesture)
    }

    /// 底部控制区，包含变焦环与功能按钮。
    private func bottomSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 18) {
            zoomRing
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

    /// 变焦环控件，当支持连续变焦或多个预设时显示。
    @ViewBuilder
    private var zoomRing: some View {
        let span = viewModel.zoomRange.upperBound - viewModel.zoomRange.lowerBound
        if span > CGFloat(0.05) || viewModel.zoomPresets.count > 1 {
            ZoomRingView(
                config: .init(
                    presets: viewModel.zoomPresets,
                    range: viewModel.zoomRange,
                    state: viewModel.zoomState,
                    onPresetTap: { preset in
                        viewModel.selectZoomPreset(preset)
                    },
                    onDragChanged: { factor in
                        viewModel.updateZoomInteractively(to: factor)
                    },
                    onDragEnded: { factor in
                        viewModel.finalizeZoomInteractively(at: factor, smooth: true)
                    }
                )
            )
            .frame(height: 120)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    /// 顶部控制栏，包含返回、重置、调试显示和菜单操作。
    private var topControlBar: some View {
        ZStack {
			// 左右两端的按钮使用 HStack 布局，确保左侧按钮左对齐、右侧菜单右对齐
			HStack {
				topCircleButton(systemName: "arrow.clockwise") { 
					viewModel.resetDetectionState()
				}

				Spacer()
				
				Menu {
					Button {
						showDebugInfo.toggle()
					} label: {
						Label(showDebugInfo ? "隐藏调试模式" : "打开调试模式", systemImage: showDebugInfo ? "eye.slash" : "eye")
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

    /// 顶部居中的进度提示视图。
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

    /// 主拍照按钮样式。
    private var captureButton: some View {
        Button(action: { viewModel.capturePhoto() }) {
            Circle()
                .strokeBorder(Color.white, lineWidth: 10)
                .frame(width: 78, height: 78)
                .overlay(Circle().fill(Color.white.opacity(0.15)))
        }
    }

    /// 构建次要圆形按钮，适用于辅助操作。
    private func secondaryCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                )
        }
    }

    /// 生成顶部控制栏使用的圆形按钮。
    private func topCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            topCircleLabel(systemName: systemName)
        }
    }

    /// 顶部圆形按钮的内部标签样式。
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
    /// 展示调试信息与图像预览的面板。
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
                        if let distance = viewModel.distanceToCenter {
                            Text("距离中心: \(String(format: "%.1f", distance)) pts")
                        } else {
                            Text("距离中心: --")
                        }
                        Spacer()
                        Text(viewModel.detectionReady ? "检测: 已就绪" : "检测: 未就绪")
                    }
                }
                .font(.caption2)

                Text("变焦: \(viewModel.zoomDisplayText) / \(viewModel.focalLengthText)")
                    .font(.caption2)

                Text("对准: \(viewModel.isAligned ? "已对准" : "未对准")")
                    .font(.caption2)
                    .foregroundColor(viewModel.isAligned ? .green : .primary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
        }
    }

    /// 根据容器尺寸计算 3:4 构图区域。
    private static func compositionRect(in size: CGSize) -> CGRect {
        let width = size.width
        let targetHeight = width * 4.0 / 3.0
        let height = min(size.height, targetHeight)
        let originY = (size.height - height) * 0.5
        return CGRect(x: 0, y: originY, width: width, height: height)
    }

    /// 双指缩放手势，并实时驱动相机变焦。
    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if !pinchActive {
                    pinchInitialFactor = viewModel.zoomState.currentFactor
                    pinchActive = true
                }
                let target = clampedZoomFactor(for: pinchInitialFactor * scale)
                viewModel.updateZoomInteractively(to: target)
            }
            .onEnded { scale in
                let target = clampedZoomFactor(for: pinchInitialFactor * scale)
                viewModel.finalizeZoomInteractively(at: target, smooth: true)
                pinchActive = false
            }
    }

    /// 将目标倍率限制在相机支持的范围内。
    private func clampedZoomFactor(for factor: CGFloat) -> CGFloat {
        min(max(factor, viewModel.zoomRange.lowerBound), viewModel.zoomRange.upperBound)
    }
}
#endif