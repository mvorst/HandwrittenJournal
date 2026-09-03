import CoreGraphics
import Foundation
import SwiftUI

/// One sampled point of the child's pen.
struct StrokePoint: Equatable {
    var location: CGPoint
    var force: CGFloat      // 0…1, drives width between 1.5 and 5.0 pt at Large
    var isInside: Bool      // inside the letterform when it was drawn
    var letterIndex: Int    // which glyph it was attributed to, -1 if none
}

/// A single pen-down to pen-up gesture.
struct TracingStroke: Equatable {
    /// Which layer of the page a stroke belongs to (DESIGN_DOCUMENT.md §4.4, v3.2).
    enum Layer: UInt8, Equatable {
        /// Handwriting over the guide — attributed to letters, scored, the record.
        case ink = 0
        /// A crayon doodle — drawn anywhere, never attributed, never scored, kept with
        /// the page and shown wherever the page is shown.
        case doodle = 1
    }

    var points: [StrokePoint] = []
    var layer: Layer = .ink
    /// Which crayon a doodle was drawn with (`Crayon.rawValue`). Ignored for ink.
    var crayon: UInt8 = 0

    var isEmpty: Bool { points.count < 2 }
    var isDoodle: Bool { layer == .doodle }

    mutating func append(_ point: StrokePoint) { points.append(point) }

    /// The same stroke with no points — how the eraser starts each surviving piece, so a
    /// split doodle stays a doodle in the same crayon.
    func emptied() -> TracingStroke {
        var copy = self
        copy.points = []
        return copy
    }

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
    /// The handwriting — what is attributed, scored and read as the record.
    var ink: [TracingStroke] { filter { !$0.isDoodle } }
    /// The crayon layer — kept with the page, never counted.
    var doodles: [TracingStroke] { filter(\.isDoodle) }
}

/// The three crayons (WIREFRAME_SPEC.md §5.6 — the decorative accents, put to work in
/// v3.2). Doodles are drawn in multiply at 85% so the letters stay readable through them,
/// and they are never a state, a button or a score.
enum Crayon: Int, CaseIterable, Identifiable {
    case yellow = 0
    case pink
    case lilac

    var id: Int { rawValue }

    var colour: Color {
        switch self {
        case .yellow: Tokens.Colour.pencilYellow
        case .pink:   Tokens.Colour.eraserPink
        case .lilac:  Tokens.Colour.lilacStar
        }
    }

    var name: String {
        switch self {
        case .yellow: String(localized: "Yellow crayon")
        case .pink:   String(localized: "Pink crayon")
        case .lilac:  String(localized: "Lilac crayon")
        }
    }

    static func uiColour(_ index: UInt8) -> UIColor {
        UIColor((Crayon(rawValue: Int(index)) ?? .yellow).colour)
    }

    /// Opacity of the crayon layer — the guide beneath stays legible.
    static let opacity: CGFloat = 0.85
    /// Crayon width at Large, in points; scaled by `size / 72` like the ink.
    static let widthRange: ClosedRange<CGFloat> = 4...9

    /// Draws doodles into a context already in canvas coordinates. `widthScale` is the
    /// glyph-size factor (`size / 72`); the caller scales the context for anything else.
    static func draw(_ doodles: [TracingStroke], in ctx: CGContext, widthScale: CGFloat) {
        guard !doodles.isEmpty else { return }
        ctx.saveGState()
        ctx.setBlendMode(.multiply)
        ctx.setAlpha(opacity)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let range = widthRange
        for stroke in doodles where stroke.points.count > 1 {
            ctx.setStrokeColor(uiColour(stroke.crayon).cgColor)
            for i in 1..<stroke.points.count {
                let a = stroke.points[i - 1], b = stroke.points[i]
                let force = (a.force + b.force) / 2
                ctx.setLineWidth((range.lowerBound + (range.upperBound - range.lowerBound) * force) * widthScale)
                ctx.move(to: a.location)
                ctx.addLine(to: b.location)
                ctx.strokePath()
            }
        }
        ctx.restoreGState()
    }
}
