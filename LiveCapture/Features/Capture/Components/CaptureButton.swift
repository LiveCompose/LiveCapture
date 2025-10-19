//
//  CaptureButton.swift
//  LiveCapture
//
//  主拍照按钮组件

import SwiftUI

#if os(iOS)

/// 主拍照按钮
struct CaptureButton: View {
	let isScaled: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			ZStack {
				// 外层大圆
				Circle()
					.strokeBorder(
						LinearGradient(
							colors: [
								Color.white,
								Color.white.opacity(0.8)
							],
							startPoint: .top,
							endPoint: .bottom
						),
						lineWidth: 6
					)
					.frame(width: 84, height: 84)
					.shadow(color: .white.opacity(0.4), radius: 10, y: 0)
				
				// 内层圆
				Circle()
					.fill(
						RadialGradient(
							colors: [
								Color.white.opacity(0.9),
								Color.white.opacity(0.3)
							],
							center: .center,
							startRadius: 10,
							endRadius: 35
						)
					)
					.frame(width: 70, height: 70)
					.shadow(color: .black.opacity(0.3), radius: 8, y: 4)
			}
		}
		.scaleEffect(isScaled ? 0.95 : 1.0)
		.animation(DesignSystem.Animation.quick, value: isScaled)
	}
}

#endif
