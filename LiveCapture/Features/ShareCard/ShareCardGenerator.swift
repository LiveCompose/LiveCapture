import UIKit

enum ShareCardGenerator {
    private static let cardWidth: CGFloat = 1080
    private static let cornerRadius: CGFloat = 24
    private static let photoInset: CGFloat = 48
    private static let topPadding: CGFloat = 96
    private static let bottomReserved: CGFloat = 260
    private static let maxPhotoDimension: CGFloat = 1920

    /// 将照片缩放到适合绘制的大小，避免大图在后台线程绘制失败
    private static func scaledPhoto(from photo: UIImage) -> UIImage? {
        let size = photo.size
        guard size.width > 0, size.height > 0 else { return nil }

        let maxDim = max(size.width, size.height)
        guard maxDim > maxPhotoDimension else { return photo }

        let ratio = maxPhotoDimension / maxDim
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        photo.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? photo
    }

    static func generate(photo: UIImage) -> UIImage? {
        guard let photo = scaledPhoto(from: photo) else { return nil }

        let photoSize = photo.size
        let photoAspect = photoSize.width / photoSize.height
        let photoAreaWidth = cardWidth - photoInset * 2
        let photoAreaHeight = photoAreaWidth / photoAspect
        let cardHeight = topPadding + photoAreaHeight + bottomReserved
        let cardSize = CGSize(width: cardWidth, height: cardHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: cardSize, format: format)

        return renderer.image { ctx in
            let cardRect = CGRect(origin: .zero, size: cardSize)

            // 卡片背景（浅灰白底色）
            UIColor(white: 0.97, alpha: 1).setFill()
            let bgPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
            bgPath.fill()

            // 照片区域
            let photoRect = CGRect(x: photoInset, y: topPadding, width: photoAreaWidth, height: photoAreaHeight)

            // 照片白色底板 + 圆角
            UIColor.white.setFill()
            let photoBgPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            photoBgPath.fill()

            // 裁剪照片到圆角
            ctx.cgContext.saveGState()
            photoBgPath.addClip()
            photo.draw(in: photoRect)
            ctx.cgContext.restoreGState()

            // 照片描边
            UIColor(white: 0.88, alpha: 1).setStroke()
            photoBgPath.lineWidth = 1
            photoBgPath.stroke()

            // 底部水印区域
            let bottomY = photoRect.maxY + 42

            // App 图标占位（圆形）
            let iconSize: CGFloat = 64
            let iconRect = CGRect(x: (cardWidth - iconSize) / 2, y: bottomY, width: iconSize, height: iconSize)
            let iconPath = UIBezierPath(roundedRect: iconRect, cornerRadius: 14)
            UIColor.black.setFill()
            iconPath.fill()

            // 图标内文字
            let iconLabel = "LC"
            let iconFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let iconAttr: [NSAttributedString.Key: Any] = [.font: iconFont, .foregroundColor: UIColor.white]
            let iconLabelSize = iconLabel.size(withAttributes: iconAttr)
            iconLabel.draw(
                in: CGRect(x: iconRect.midX - iconLabelSize.width / 2, y: iconRect.midY - iconLabelSize.height / 2,
                           width: iconLabelSize.width, height: iconLabelSize.height),
                withAttributes: iconAttr
            )

            // 标题
            let titleY = iconRect.maxY + 18
            let titleText = "LiveCapture"
            let titleFont = UIFont.systemFont(ofSize: 44, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(
                in: CGRect(x: (cardWidth - titleSize.width) / 2, y: titleY, width: titleSize.width, height: titleSize.height),
                withAttributes: titleAttr
            )

            // 副标题
            let subText = "构妙 · 智能构图助手"
            let subFont = UIFont.systemFont(ofSize: 26, weight: .regular)
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor(white: 0.4, alpha: 1)
            ]
            let subSize = subText.size(withAttributes: subAttr)
            subText.draw(
                in: CGRect(x: (cardWidth - subSize.width) / 2, y: titleY + titleSize.height + 6,
                           width: subSize.width, height: subSize.height),
                withAttributes: subAttr
            )

            // 底部分隔线
            let lineY = titleY + titleSize.height + subSize.height + 20
            let line = UIBezierPath()
            line.move(to: CGPoint(x: cardWidth * 0.3, y: lineY))
            line.addLine(to: CGPoint(x: cardWidth * 0.7, y: lineY))
            UIColor(white: 0.8, alpha: 1).setStroke()
            line.lineWidth = 1
            line.stroke()
        }
    }
}
