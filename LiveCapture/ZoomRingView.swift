//
//  ZoomRingView.swift
//  LiveCapture
//
//  Created by Codex on 2025/03/17.
//

import SwiftUI

#if os(iOS)

/// 线性排列的变焦预设按钮，提供镜头快捷切换。
struct ZoomRingView: View {
	/// 控件的外部配置项集合。
	struct Configuration {
		let presets: [CameraManager.ZoomPreset]
		let range: ClosedRange<CGFloat>
		let state: CameraManager.ZoomState
		let onPresetTap: (CameraManager.ZoomPreset) -> Void
		let onDragChanged: (CGFloat) -> Void
		let onDragEnded: (CGFloat) -> Void
	}

	private struct LensButtonItem: Identifiable {
		let preset: CameraManager.ZoomPreset
		let title: String
		var id: CameraManager.ZoomPreset.ID { preset.id }
	}

	private let config: Configuration
	@State private var hoveredItem: CameraManager.ZoomPreset.ID?

	/// 使用给定配置初始化控件。
	init(config: Configuration) {
		self.config = config
	}

	/// 构建线性排列的预设按钮。
	var body: some View {
		HStack(alignment: .center, spacing: 32) {
			ForEach(lensButtonItems) { item in
				presetButton(item)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
		.background(
			Capsule()
				.fill(.ultraThinMaterial)
				.overlay(
					Capsule()
						.fill(Color.white.opacity(0.05))
				)
		)
		.overlay(
			Capsule()
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.3),
							Color.white.opacity(0.1)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		)
		.shadow(color: .black.opacity(0.3), radius: 15, y: 5)
	}

	/// 生成用于展示的按钮模型集合。
	private var lensButtonItems: [LensButtonItem] {
		let sortedPresets = config.presets.sorted { $0.zoomFactor < $1.zoomFactor }
		var selected: [CameraManager.ZoomPreset] = []

		if let ultra = sortedPresets.first(where: { $0.lens == .ultraWide }) {
			selected.append(ultra)
		}

		let primaryCandidates: [CameraManager.LensKind] = config.presets.contains(where: { $0.lens == .front }) ? [.front, .wide] : [.wide, .front]
		if let standard = sortedPresets.first(where: { primaryCandidates.contains($0.lens) }) {
			if !selected.contains(where: { $0.id == standard.id }) {
				selected.append(standard)
			}
		}

		if let tele = sortedPresets.filter({ $0.lens == .telephoto }).min(by: { $0.zoomFactor < $1.zoomFactor }) {
			selected.append(tele)
		}

		for preset in sortedPresets where selected.count < 3 {
			if !selected.contains(where: { $0.id == preset.id }) {
				selected.append(preset)
			}
		}

		return selected.prefix(3).map {
			LensButtonItem(preset: $0,
				title: $0.label)
		}
	}

	private func presetButton(_ item: LensButtonItem) -> some View {
		let isActive = abs(item.preset.zoomFactor - config.state.currentFactor) < 0.05
		
		return Button {
			HapticManager.shared.zoomSnap()
			config.onPresetTap(item.preset)
		} label: {
			VStack(spacing: 6) {
				// 主按钮
				ZStack {
					// 背景圆圈
					Circle()
						.fill(
							isActive
								? DesignSystem.Colors.primaryGradient
								: LinearGradient(
									colors: [Color.white.opacity(0.2)],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
						)
						.frame(width: 52, height: 52)
					
					// 发光效果（仅激活时）
					if isActive {
						Circle()
							.stroke(Color.white.opacity(0.6), lineWidth: 2)
							.frame(width: 52, height: 52)
							.blur(radius: 4)
					}
					
					// 边框
					Circle()
						.strokeBorder(
							isActive
								? Color.white.opacity(0.5)
								: Color.white.opacity(0.3),
							lineWidth: 1.5
						)
						.frame(width: 52, height: 52)
					
					// 文字
					Text(item.title)
						.font(.system(size: 16, weight: .bold, design: .rounded))
						.foregroundStyle(
							isActive
								? Color.white
								: Color.white.opacity(0.9)
						)
				}
				.shadow(
					color: isActive ? Color.blue.opacity(0.5) : Color.clear,
					radius: 12,
					y: 4
				)
				
				// 小标签（可选）
				if isActive {
					Text("已选择")
						.font(.system(size: 10, weight: .semibold))
						.foregroundColor(.white.opacity(0.8))
						.padding(.horizontal, 8)
						.padding(.vertical, 3)
						.background(
							Capsule()
								.fill(Color.white.opacity(0.15))
						)
						.transition(.scale.combined(with: .opacity))
				}
			}
			.scaleEffect(isActive ? 1.05 : (hoveredItem == item.id ? 1.02 : 1.0))
			.animation(DesignSystem.Animation.quick, value: isActive)
			.animation(DesignSystem.Animation.quick, value: hoveredItem)
		}
		.buttonStyle(.plain)
		.simultaneousGesture(
			DragGesture(minimumDistance: 0)
				.onChanged { _ in
					if hoveredItem != item.id {
						hoveredItem = item.id
						HapticManager.shared.soft()
					}
				}
				.onEnded { _ in
					hoveredItem = nil
				}
		)
	}
}

#endif
