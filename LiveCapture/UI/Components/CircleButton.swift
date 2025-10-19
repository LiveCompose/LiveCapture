//
//  CircleButton.swift
//  LiveCapture
//
//  通用圆形按钮组件

import SwiftUI

#if os(iOS)

/// 次要功能圆形按钮 (大尺寸)
struct SecondaryCircleButton: View {
	let systemName: String
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			ZStack {
				Circle()
					.fill(Color.black.opacity(0.5))
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.3))
					)
					.frame(width: 56, height: 56)
				
				Image(systemName: systemName)
					.font(.system(size: 22, weight: .medium))
					.foregroundStyle(.white)
			}
		}
	}
}

/// 顶部控制栏圆形按钮 (小尺寸)
struct TopCircleButton: View {
	let systemName: String
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			ZStack {
				Circle()
					.fill(Color.black.opacity(0.5))
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.3))
					)
					.frame(width: 38, height: 38)
				
				Image(systemName: systemName)
					.font(.system(size: 18, weight: .semibold))
					.foregroundStyle(.white)
			}
		}
	}
}

#endif
