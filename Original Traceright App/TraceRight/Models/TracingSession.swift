import CoreGraphics
import Foundation

struct TracingPoint {
    let location: CGPoint
    let timestamp: TimeInterval
    let force: CGFloat
    let isInsideLetter: Bool
}

struct TracingStroke {
    var points: [TracingPoint]

    var insideRatio: CGFloat {
        let insideCount = points.filter(\.isInsideLetter).count
        return CGFloat(insideCount) / CGFloat(max(points.count, 1))
    }
}

struct TracingSession {
    let text: String
    let level: Int
    var strokes: [TracingStroke]

    var overallAccuracy: CGFloat {
        let allPoints = strokes.flatMap(\.points)
        let insideCount = allPoints.filter(\.isInsideLetter).count
        return CGFloat(insideCount) / CGFloat(max(allPoints.count, 1))
    }

    var totalPoints: Int {
        strokes.flatMap(\.points).count
    }

    var insidePoints: Int {
        strokes.flatMap(\.points).filter(\.isInsideLetter).count
    }

    init(text: String, level: Int, strokes: [TracingStroke] = []) {
        self.text = text
        self.level = level
        self.strokes = strokes
    }
}
