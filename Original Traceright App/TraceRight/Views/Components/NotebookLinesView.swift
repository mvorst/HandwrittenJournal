import SwiftUI

struct NotebookLinesView: View {
    let lineOrigins: [CGPoint]
    let lineHeights: [CGFloat]

    var body: some View {
        Canvas { context, size in
            let lineColor = Color(hex: 0xE5E5EA)

            for (i, origin) in lineOrigins.enumerated() {
                guard i < lineHeights.count else { break }
                let baselineY = origin.y

                // Solid baseline
                var path = Path()
                path.move(to: CGPoint(x: AppConstants.horizontalMargin, y: baselineY))
                path.addLine(to: CGPoint(x: size.width - AppConstants.horizontalMargin, y: baselineY))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
        }
    }
}
