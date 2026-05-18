import UIKit

enum ShareCardGenerator {
    private static let cardWidth: CGFloat = 1080
    private static let cardAspectRatio: CGFloat = 3.0 / 4.0
    private static var cardHeight: CGFloat { cardWidth / cardAspectRatio }
    private static let cornerRadius: CGFloat = 24
    private static let photoInsetHorizontal: CGFloat = 80
    private static let photoInsetVertical: CGFloat = 72
    private static let topPadding: CGFloat = 120
    private static let bottomReserved: CGFloat = 300
    private static let maxPhotoDimension: CGFloat = 1920

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

    private static func loadLogo() -> UIImage? {
        return UIImage(named: "logo-glass-LiveCompose")
    }

    static func generate(
        photo: UIImage,
        date: Date = Date(),
        detectionMethod: String? = nil,
        iso: Float? = nil,
        shutterSpeed: Double? = nil,
        aperture: Double? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil
    ) -> UIImage? {
        guard let photo = scaledPhoto(from: photo) else { return nil }

        let cardSize = CGSize(width: cardWidth, height: cardHeight)
        let photoAreaWidth = cardWidth - photoInsetHorizontal * 2

        // 照片按 3:4 区域适配
        let photoSize = photo.size
        let photoAspect = photoSize.width / photoSize.height
        let targetAspect = cardAspectRatio // 3:4

        // 计算照片在可用区域内的实际尺寸（保持原始比例）
        var drawWidth = photoAreaWidth
        var drawHeight = drawWidth / photoAspect

        // 如果照片太高，限制高度
        let maxPhotoHeight = cardHeight - topPadding - bottomReserved
        if drawHeight > maxPhotoHeight {
            drawHeight = maxPhotoHeight
            drawWidth = drawHeight * photoAspect
        }

        let photoRect = CGRect(
            x: (cardWidth - drawWidth) / 2,
            y: topPadding + (maxPhotoHeight - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: cardSize, format: format)

        let logo = loadLogo()
        let dateStr = formattedDate(date)

        return renderer.image { ctx in
            let cardRect = CGRect(origin: .zero, size: cardSize)

            // 白色背景
            UIColor.white.setFill()
            let bgPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
            bgPath.fill()

            // 照片白色底板
            UIColor.white.setFill()
            let photoBgPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            photoBgPath.fill()

            ctx.cgContext.saveGState()
            photoBgPath.addClip()
            photo.draw(in: photoRect)
            ctx.cgContext.restoreGState()

            UIColor(white: 0.88, alpha: 1).setStroke()
            photoBgPath.lineWidth = 1
            photoBgPath.stroke()

            // 底部水印区域
            let bottomY = photoRect.maxY + 36

            // Logo
            if let logo {
                let logoSize: CGFloat = 56
                let logoRect = CGRect(x: (cardWidth - logoSize) / 2, y: bottomY, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
            }

            // 标题
            let titleY = bottomY + 64
            let titleText = "构妙 · LiveCompose"
            let titleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(
                in: CGRect(x: (cardWidth - titleSize.width) / 2, y: titleY, width: titleSize.width, height: titleSize.height),
                withAttributes: titleAttr
            )

            // 日期
            let dateFont = UIFont.systemFont(ofSize: 22, weight: .regular)
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor(white: 0.4, alpha: 1)
            ]
            let dateSize = dateStr.size(withAttributes: dateAttr)
            let dateY = titleY + titleSize.height + 8
            dateStr.draw(
                in: CGRect(x: (cardWidth - dateSize.width) / 2, y: dateY, width: dateSize.width, height: dateSize.height),
                withAttributes: dateAttr
            )

            // 参数行
            let paramsY = dateY + dateSize.height + 14
            var paramParts: [String] = []
            if let method = detectionMethod { paramParts.append(method) }
            if let iso { paramParts.append("ISO \(Int(iso))") }
            if let s = shutterSpeed { paramParts.append(shutterDisplay(s)) }
            if let a = aperture { paramParts.append("f/\(String(format: "%.1f", a))") }
            if let w = imageWidth, let h = imageHeight { paramParts.append("\(w)×\(h)") }

            let paramsText = paramParts.joined(separator: "  ·  ")
            let paramsFont = UIFont.systemFont(ofSize: 20, weight: .regular)
            let paramsAttr: [NSAttributedString.Key: Any] = [
                .font: paramsFont,
                .foregroundColor: UIColor(white: 0.5, alpha: 1)
            ]
            let paramsSize = paramsText.size(withAttributes: paramsAttr)
            paramsText.draw(
                in: CGRect(x: max((cardWidth - paramsSize.width) / 2, photoInsetHorizontal),
                           y: paramsY, width: min(paramsSize.width, cardWidth - photoInsetHorizontal * 2),
                           height: paramsSize.height),
                withAttributes: paramsAttr
            )

            // 底部分隔线
            let lineY = paramsY + paramsSize.height + 22
            let line = UIBezierPath()
            line.move(to: CGPoint(x: cardWidth * 0.25, y: lineY))
            line.addLine(to: CGPoint(x: cardWidth * 0.75, y: lineY))
            UIColor(white: 0.8, alpha: 1).setStroke()
            line.lineWidth = 1
            line.stroke()
        }
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private static func shutterDisplay(_ speed: Double) -> String {
        if speed >= 1 { return "\(Int(speed))s" }
        else { return "1/\(Int(1.0 / speed))s" }
    }
}
