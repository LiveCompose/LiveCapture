//
//  ZoomRingView.swift
//  LiveCapture
//
//  变焦环视图组件
//
//  ## 文件作用
//  提供线性排列的变焦预设按钮
//  支持快捷切换不同焦距镜头
//  提供直观的变焦倍率选择界面
//
//  ## 主要组件
//  ### ZoomRingView
//  变焦环视图
//
//  ### Configuration 结构体
//  变焦环配置
//  
//  属性:
//  - presets: [CameraManager.ZoomPreset] - 预设列表
//  - range: ClosedRange<CGFloat> - 变焦范围
//  - state: CameraManager.ZoomState - 当前变焦状态
//  - onPresetTap: (ZoomPreset) -> Void - 预设点击回调
//  - onDragChanged: (CGFloat) -> Void - 拖动变化回调
//  - onDragEnded: (CGFloat) -> Void - 拖动结束回调
//
//  ### LensButtonItem 结构体
//  镜头按钮项（私有）
//  
//  属性:
//  - preset: ZoomPreset - 关联的预设
//  - title: String - 显示标题
//  - id: UUID - 唯一标识符
//
//  ## 状态
//  - hoveredItem: UUID? - 当前悬停的按钮 ID
//
//  ## UI 布局
//  - 水平排列的预设按钮
//  - 间距 32pt
//  - 水平内边距 24pt
//  - 垂直内边距 16pt
//  - 底部阴影效果
//
//  ## 按钮样式
//  - 圆角矩形背景
//  - 半透明毛玻璃材质
//  - 当前激活预设高亮显示
//  - 悬停效果
//  - 倍率文字 + 焦距标注
//
//  ## 交互
//  - 点击预设按钮切换焦距
//  - 长按拖动实现连续变焦
//  - 悬停高亮反馈
//
//  ## 辅助属性
//  - lensButtonItems: [LensButtonItem]
//    从配置生成按钮项列表
//
//  ## 子视图
//  - presetButton(_:): 单个预设按钮
//    参数: item - LensButtonItem
//    返回: some View
//    样式:
//      - 激活状态：白色背景，蓝色文字
//      - 未激活：半透明背景，白色文字
//      - 显示倍率和焦距
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
		HStack(alignment: .center, spacing: 16) {
			ForEach(lensButtonItems) { item in
				presetButton(item)
			}
		}
		.frame(maxWidth: .infinity)
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
			//HapticManager.shared.zoomSnap()
			config.onPresetTap(item.preset)
		} label: {
			VStack(spacing: 2) {
				// 主按钮
				ZStack {
					// 背景圆圈
					Circle()
						.fill(
							isActive
								? Color.black.opacity(0.3)
								: Color.white.opacity(0.15)
						)
						.frame(width: 44, height: 44)
					
					// 文字
					Text(item.title)
						.font(.system(size: 14, weight: .bold, design: .rounded))
						.foregroundStyle(
							isActive
								? Color.white
								: Color.black
						)
						.shadow(
							color: isActive ? .clear : .white.opacity(0.8),
							radius: isActive ? 0 : 2,
							x: 0,
							y: isActive ? 0 : 1
						)
				}
			}
			//.scaleEffect(isActive ? 1.05 : (hoveredItem == item.id ? 1.02 : 1.0))
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
