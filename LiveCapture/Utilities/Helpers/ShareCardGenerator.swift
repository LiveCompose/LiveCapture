import UIKit

enum ShareCardGenerator {
    private static let cardAspectRatio: CGFloat = 3.0 / 4.0
    private static let cardWidth: CGFloat = 1080

    static func generate(photo: UIImage) -> UIImage? {
        let photoSize = photo.size
        guard photoSize.width > 0, photoSize.height > 0 else { return nil }

        let cardHeight = cardWidth / cardAspectRatio
        let cardSize = CGSize(width: cardWidth, height: cardHeight)

        let renderer = UIGraphicsImageRenderer(size: cardSize, format: {
            let f = UIGraphicsImageRendererFormat.default()
            f.scale = 1
            f.opaque = true
            return f
        }())

        return renderer.image { ctx in
            // 白色背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: cardSize))

            // 照片区域：白色边框 + 照片
            let borderWidth: CGFloat = 40
            let topPadding: CGFloat = 100
            let bottomReserved: CGFloat = 200
            let photoAreaWidth = cardWidth - borderWidth * 2
            let photoAreaHeight = cardHeight - topPadding - bottomReserved
            let photoRect = CGRect(x: borderWidth, y: topPadding, width: photoAreaWidth, height: photoAreaHeight)

            // 在照片区域内按比例缩放居中放置照片
            let photoAspect = photoSize.width / photoSize.height
            let areaAspect = photoAreaWidth / photoAreaHeight

            var drawWidth: CGFloat
            var drawHeight: CGFloat
            if photoAspect > areaAspect {
                drawWidth = photoAreaWidth
                drawHeight = photoAreaWidth / photoAspect
            } else {
                drawHeight = photoAreaHeight
                drawWidth = photoAreaHeight * photoAspect
            }
            let drawX = photoRect.midX - drawWidth / 2
            let drawY = photoRect.midY - drawHeight / 2
            let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)

            // 裁剪圆角遮罩
            let clipPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            ctx.cgContext.addPath(clipPath.cgPath)
            ctx.cgContext.clip()
            photo.draw(in: drawRect)
            ctx.cgContext.resetClip()

            // 白色边框描边
            UIColor.white.setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            borderPath.lineWidth = 3
            borderPath.stroke()

            // 底部 Logo + 文字区域
            let bottomY = photoRect.maxY + 30

            // LiveCapture 文字
            let titleText = "LiveCapture"
            let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            let titleRect = CGRect(
                x: (cardWidth - titleSize.width) / 2,
                y: bottomY,
                width: titleSize.width,
                height: titleSize.height
            )
            titleText.draw(in: titleRect, withAttributes: titleAttributes)

            // 中文副标题
            let subtitleText = "构妙 · 智能构图助手"
            let subtitleFont = UIFont.systemFont(ofSize: 28, weight: .regular)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor(white: 0.4, alpha: 1)
            ]
            let subtitleSize = subtitleText.size(withAttributes: subtitleAttributes)
            let subtitleRect = CGRect(
                x: (cardWidth - subtitleSize.width) / 2,
                y: titleRect.maxY + 8,
                width: subtitleSize.width,
                height: subtitleSize.height
            )
            subtitleText.draw(in: subtitleRect, withAttributes: subtitleAttributes)

            // 微信风格分隔线 + 标识
            let lineY = subtitleRect.maxY + 20
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: cardWidth * 0.2, y: lineY))
            linePath.addLine(to: CGPoint(x: cardWidth * 0.8, y: lineY))
            UIColor(white: 0.85, alpha: 1).setStroke()
            linePath.lineWidth = 1
            linePath.stroke()
        }
    }
}
