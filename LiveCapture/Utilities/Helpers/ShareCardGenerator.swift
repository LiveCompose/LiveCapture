import UIKit

enum ShareCardGenerator {
    private static let cardWidth: CGFloat = 1080
    private static let photoInset: CGFloat = 60
    private static let topPadding: CGFloat = 120
    private static let bottomReserved: CGFloat = 220

    static func generate(photo: UIImage) -> UIImage? {
        let photoSize = photo.size
        guard photoSize.width > 0, photoSize.height > 0 else { return nil }

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
            // 白色背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: cardSize))

            // 照片区域
            let photoRect = CGRect(x: photoInset, y: topPadding, width: photoAreaWidth, height: photoAreaHeight)
            photo.draw(in: photoRect)

            // 照片边框
            UIColor(white: 0.9, alpha: 1).setStroke()
            let borderPath = UIBezierPath(rect: photoRect)
            borderPath.lineWidth = 1
            borderPath.stroke()

            // 底部文字
            let bottomY = photoRect.maxY + 36

            let titleText = "LiveCapture"
            let titleFont = UIFont.systemFont(ofSize: 52, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(
                in: CGRect(x: (cardWidth - titleSize.width) / 2, y: bottomY, width: titleSize.width, height: titleSize.height),
                withAttributes: titleAttr
            )

            let subText = "构妙 · 智能构图助手"
            let subFont = UIFont.systemFont(ofSize: 28, weight: .regular)
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor(white: 0.4, alpha: 1)
            ]
            let subSize = subText.size(withAttributes: subAttr)
            subText.draw(
                in: CGRect(x: (cardWidth - subSize.width) / 2, y: bottomY + titleSize.height + 8, width: subSize.width, height: subSize.height),
                withAttributes: subAttr
            )

            // 分隔线
            let lineY = bottomY + titleSize.height + subSize.height + 24
            let line = UIBezierPath()
            line.move(to: CGPoint(x: cardWidth * 0.25, y: lineY))
            line.addLine(to: CGPoint(x: cardWidth * 0.75, y: lineY))
            UIColor(white: 0.85, alpha: 1).setStroke()
            line.lineWidth = 1
            line.stroke()
        }
    }
}
