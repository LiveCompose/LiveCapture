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

	/// 使用给定配置初始化控件。
	init(config: Configuration) {
		self.config = config
	}

	/// 构建线性排列的预设按钮。
	var body: some View {
		HStack(alignment: .center, spacing: 28) {
			ForEach(lensButtonItems) { item in
				presetButton(item)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.horizontal, 24)
		.padding(.vertical, 12)
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
		let activeFill = Color.white
		let inactiveFill = Color.white.opacity(0.18)
		let activeTextColor = Color.black
		let inactiveTextColor = Color.white

		return Button {
			config.onPresetTap(item.preset)
		} label: {
			Circle()
				.fill(isActive ? activeFill : inactiveFill)
				.frame(width: 40, height: 40)
				.overlay(
					Circle()
						.stroke(Color.white.opacity(isActive ? 0.0 : 0.4), lineWidth: 1)
					)
				.overlay(
					Text(item.title)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(isActive ? activeTextColor : inactiveTextColor)
				)
		}
		.buttonStyle(.plain)
		.animation(.easeInOut(duration: 0.12), value: isActive)
	}
}

#endif
