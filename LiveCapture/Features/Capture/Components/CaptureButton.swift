//
//  CaptureButton.swift
//  LiveCapture
//
//  主拍照按钮组件
//
//  ## 文件作用
//  提供拍摄界面的主要拍照按钮
//  模拟相机应用的经典圆形快门按钮设计
//  支持缩放动画效果
//
//  ## 主要组件
//  ### CaptureButton
//  主拍照按钮视图
//
//  ## 输入参数
//  - isScaled: Bool - 是否处于缩放状态
//  - action: () -> Void - 点击回调
//
//  ## UI 设计
//  双圆环设计：
//  - 外层大圆：
//    - 直径 84pt
//    - 白色渐变描边（6pt 宽度）
//    - 顶部到底部渐变透明度
//    - 外发光阴影效果
//  
//  - 内层圆：
//    - 直径 70pt
//    - 放射状渐变填充
//    - 从中心向外透明度递减
//    - 底部投影
//
//  ## 交互效果
//  - 按下时缩放到 0.95
//  - 松开恢复到 1.0
//  - 使用 spring 动画提供弹性感
//  - 响应 isScaled 参数（用于拍照动画）
//
//  ## 视觉特点
//  - 经典快门按钮造型
//  - 渐变和阴影增加立体感
//  - 流畅的交互反馈
//

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
