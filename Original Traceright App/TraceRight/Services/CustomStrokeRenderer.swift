import UIKit

final class CustomStrokeRenderer {
    static func render(strokes: [TracingStroke], in context: CGContext, lineWidth: CGFloat = AppConstants.defaultStrokeWidth) {
        for stroke in strokes {
            guard stroke.points.count >= 2 else {
                if let point = stroke.points.first {
                    let color = point.isInsideLetter ? AppConstants.insideGreenCG : AppConstants.outsideRedCG
                    context.setFillColor(color)
                    let r = lineWidth / 2
                    context.fillEllipse(in: CGRect(
                        x: point.location.x - r,
                        y: point.location.y - r,
                        width: lineWidth,
                        height: lineWidth
                    ))
                }
                continue
            }

            for i in 1..<stroke.points.count {
                let prev = stroke.points[i - 1]
                let curr = stroke.points[i]

                let color = curr.isInsideLetter ? AppConstants.insideGreenCG : AppConstants.outsideRedCG

                // Width based on force
                let force = max(curr.force, 0.1)
                let width = AppConstants.minStrokeWidth + (AppConstants.maxStrokeWidth - AppConstants.minStrokeWidth) * force

                context.setStrokeColor(color)
                context.setLineWidth(width)
                context.setLineCap(.round)
                context.setLineJoin(.round)

                context.beginPath()
                context.move(to: prev.location)
                context.addLine(to: curr.location)
                context.strokePath()
            }
        }
    }
}
