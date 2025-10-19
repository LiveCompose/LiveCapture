//
//  CameraPreviewSection.swift
//  LiveCapture
//
//  相机预览区域组件
//
//  ## 文件作用
//  组合相机预览视图和内容覆盖层
//  负责计算和管理 3:4 构图区域
//  处理视图尺寸变化时的布局更新
//
//  ## 主要组件
//  ### CameraPreviewSection
//  相机预览区域视图
//
//  ## 输入参数
//  - session: AVCaptureSession - 相机会话对象
//  - compositionRect: CGRect - 已计算的构图区域
//  - canvasSize: CGSize - 画布尺寸
//  - cropRectInView: CGRect? - 检测到的裁切框
//  - boxCenterInView: CGPoint? - 追踪点位置
//  - isAligned: Bool - 是否对齐
//  - distanceToCenter: CGFloat? - 到中心距离
//  - onCompositionRectUpdate: (CGRect) -> Void - 构图区域更新回调
//
//  ## 子组件
//  - CameraPreviewView: 实际的相机预览层
//  - ContentOverlayView: 覆盖层（显示框线、引导等）
//
//  ## 布局逻辑
//  - 使用 GeometryReader 获取可用空间
//  - 调用 compositionRect(in:) 计算 3:4 区域
//  - 将预览居中显示在构图区域内
//  - 覆盖层覆盖整个画布
//
//  ## 辅助方法
//  - compositionRect(in:): 计算 3:4 构图区域
//    参数: size - CGSize 容器尺寸
//    返回: CGRect 构图区域
//    逻辑:
//      - 宽度填满容器
//      - 高度按 4:3 比例计算
//      - 垂直居中
//
//  ## 响应式更新
//  - onAppear: 初始化时通知构图区域
//  - onChange(of: size): 尺寸变化时重新计算并通知
//

import SwiftUI
import AVFoundation

#if os(iOS)

/// 相机预览区域
struct CameraPreviewSection: View {
	let session: AVCaptureSession
	let compositionRect: CGRect
	let canvasSize: CGSize
	let cropRectInView: CGRect?
	let boxCenterInView: CGPoint?
	let isAligned: Bool
	let distanceToCenter: CGFloat?
	let onCompositionRectUpdate: (CGRect) -> Void
	
	var body: some View {
		GeometryReader { previewGeo in
			let composition = Self.compositionRect(in: previewGeo.size)
			let canvas = CGRect(origin: .zero, size: previewGeo.size)
			
			ZStack {
				CameraPreviewView(session: session)
					.frame(width: composition.width, height: composition.height)
					.position(x: composition.midX, y: composition.midY)
					.clipped()
				
				ContentOverlayView(
					compositionRect: composition,
					canvasRect: canvas,
					cropRectInView: cropRectInView,
					boxCenterInView: boxCenterInView,
					isAligned: isAligned,
					distanceToCenter: distanceToCenter
				)
			}
			.onAppear {
				onCompositionRectUpdate(composition)
			}
			.onChange(of: previewGeo.size) { _, newSize in
				onCompositionRectUpdate(Self.compositionRect(in: newSize))
			}
		}
	}
	
	/// 根据容器尺寸计算 3:4 构图区域
	private static func compositionRect(in size: CGSize) -> CGRect {
		let width = size.width
		let targetHeight = width * 4.0 / 3.0
		let height = min(size.height, targetHeight)
		let originY = (size.height - height) * 0.5
		return CGRect(x: 0, y: originY, width: width, height: height)
	}
}

#endif
