import UIKit
import CoreText

final class MaskRenderer {
    private(set) var pixelData: [UInt8] = []
    private(set) var width: Int = 0
    private(set) var height: Int = 0
    private(set) var lineOrigins: [CGPoint] = []
    private(set) var lineHeights: [CGFloat] = []
    private(set) var scale: CGFloat = 1.0

    struct LayoutInfo {
        let lineOrigins: [CGPoint]
        let lineHeights: [CGFloat]
        let totalHeight: CGFloat
        let frameRect: CGRect
    }

    func generateMask(text: String, levelConfig: LevelConfig, canvasSize: CGSize, screenScale: CGFloat) -> LayoutInfo {
        self.scale = screenScale
        let pixelWidth = Int(canvasSize.width * screenScale)
        let pixelHeight = Int(canvasSize.height * screenScale)
        self.width = pixelWidth
        self.height = pixelHeight

        guard pixelWidth > 0 && pixelHeight > 0 else {
            pixelData = []
            return LayoutInfo(lineOrigins: [], lineHeights: [], totalHeight: 0, frameRect: .zero)
        }

        let font = levelConfig.font
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = levelConfig.lineSpacing - font.pointSize
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)

        let margin = AppConstants.horizontalMargin
        let textWidth = canvasSize.width - margin * 2
        let framePath = CGPath(rect: CGRect(x: margin, y: 0, width: textWidth, height: canvasSize.height), transform: nil)

        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), framePath, nil)

        let lines = CTFrameGetLines(ctFrame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &origins)

        // CoreText uses bottom-left origin; convert to top-left for UIKit
        var uiKitOrigins: [CGPoint] = []
        var computedLineHeights: [CGFloat] = []

        for (i, line) in lines.enumerated() {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            let coreTextY = origins[i].y
            let baselineY = canvasSize.height - coreTextY
            let lineHeight = ascent + descent + leading

            uiKitOrigins.append(CGPoint(x: origins[i].x + margin, y: baselineY))
            computedLineHeights.append(lineHeight)
        }

        self.lineOrigins = uiKitOrigins
        self.lineHeights = computedLineHeights

        // Render mask bitmap
        let bitsPerComponent = 8
        let bytesPerRow = pixelWidth
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            pixelData = []
            return LayoutInfo(lineOrigins: uiKitOrigins, lineHeights: computedLineHeights, totalHeight: canvasSize.height, frameRect: .zero)
        }

        // Fill with black (outside)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // Scale for Retina
        context.scaleBy(x: screenScale, y: screenScale)

        // Flip coordinate system for UIKit-style drawing (CGContext is bottom-left by default)
        context.translateBy(x: 0, y: canvasSize.height)
        context.scaleBy(x: 1, y: -1)

        // Draw white text using the same attributed string and layout
        let drawAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let drawAttrString = NSAttributedString(string: text, attributes: drawAttributes)

        // Use CoreText to draw in the same frame for pixel-perfect alignment
        let drawFramesetter = CTFramesetterCreateWithAttributedString(drawAttrString)
        let drawFrame = CTFramesetterCreateFrame(drawFramesetter, CFRangeMake(0, drawAttrString.length), framePath, nil)

        // CoreText draws bottom-up, but we've flipped the context, so we need to flip back for CoreText
        context.saveGState()
        context.translateBy(x: 0, y: canvasSize.height)
        context.scaleBy(x: 1, y: -1)
        CTFrameDraw(drawFrame, context)
        context.restoreGState()

        // Extract pixel data
        if let data = context.data {
            let buffer = data.bindMemory(to: UInt8.self, capacity: pixelWidth * pixelHeight)
            pixelData = Array(UnsafeBufferPointer(start: buffer, count: pixelWidth * pixelHeight))
        } else {
            pixelData = [UInt8](repeating: 0, count: pixelWidth * pixelHeight)
        }

        let totalHeight = uiKitOrigins.isEmpty ? 0 : (uiKitOrigins.last!.y + (computedLineHeights.last ?? 0))
        return LayoutInfo(
            lineOrigins: uiKitOrigins,
            lineHeights: computedLineHeights,
            totalHeight: totalHeight,
            frameRect: CGRect(x: margin, y: 0, width: textWidth, height: canvasSize.height)
        )
    }

    func isLetterPixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        let index = y * width + x
        guard index >= 0, index < pixelData.count else { return false }
        return pixelData[index] > 127
    }

    func isInsideLetter(point: CGPoint, tolerance: Int) -> Bool {
        let px = Int(point.x * scale)
        let py = Int(point.y * scale)

        if tolerance == 0 {
            return isLetterPixel(x: px, y: py)
        }

        // Circular tolerance check
        for dx in -tolerance...tolerance {
            for dy in -tolerance...tolerance {
                if dx * dx + dy * dy <= tolerance * tolerance {
                    if isLetterPixel(x: px + dx, y: py + dy) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
