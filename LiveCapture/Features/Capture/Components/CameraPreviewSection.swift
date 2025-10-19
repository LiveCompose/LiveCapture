//
//  CameraPreviewSection.swift
//  LiveCapture
//
//  相机预览区域组件

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
