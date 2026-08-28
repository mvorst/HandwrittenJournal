import CoreGraphics
import Foundation

/// One sampled point of the child's pen.
struct StrokePoint: Equatable {
    var location: CGPoint
    var force: CGFloat      // 0…1, drives width between 1.5 and 5.0 pt at Large
    var isInside: Bool      // inside the letterform when it was drawn
    var letterIndex: Int    // which glyph it was attributed to, -1 if none
}

/// A single pen-down to pen-up gesture.
struct TracingStroke: Equatable {
    var points: [StrokePoint] = []
    var isEmpty: Bool { points.count < 2 }

    mutating func append(_ point: StrokePoint) { points.append(point) }

    func bounds() -> CGRect {
        guard let first = points.first else { return .zero }
        var rect = CGRect(origin: first.location, size: .zero)
        for p in points.dropFirst() {
            rect = rect.union(CGRect(origin: p.location, size: .zero))
        }
        return rect
    }
}

extension Array where Element == TracingStroke {
    var pointCount: Int { reduce(0) { $0 + $1.points.count } }
}
