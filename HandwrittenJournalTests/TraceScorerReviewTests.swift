import Testing
import UIKit
@testable import HandwrittenJournal

@MainActor
struct TraceScorerReviewTests {
    private func stroke(_ points: [CGPoint]) -> TracingStroke {
        TracingStroke(points: points.map {
            StrokePoint(location: $0, force: 0.5, isInside: false, letterIndex: -1)
        })
    }

    @Test("A manually drawn straight stem covers Jua I without filling its thick outline")
    func straightStemIndependentOfFormationTargets() throws {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        renderer.generate(text: "I", setup: .default,
                          canvasSize: CGSize(width: 400, height: 300), screenScale: 1)
        let outline = try #require(renderer.glyphPath(for: 0)).boundingBoxOfPath
        let capInset = outline.width / 2
        let top = CGPoint(x: outline.midX, y: outline.minY + capInset)
        let bottom = CGPoint(x: outline.midX, y: outline.maxY - capInset)
        let middle = CGPoint(x: outline.midX, y: (top.y + bottom.y) / 2)
        let scorer = TraceGeometryScorer(setup: .default, renderer: renderer)

        // These points come from the visible outline, without reading its formation
        // or the scorer's coverage targets. A child traces the stem, not its area.
        let whole = scorer.evaluate(strokes: [stroke([top, bottom])], targetGlyph: 0)
        let half = scorer.evaluate(strokes: [stroke([top, middle])], targetGlyph: 0)
        #expect(whole.containment >= 0.99)
        #expect(whole.isComplete)
        #expect(!half.isComplete)
        #expect(half.coverage < 0.8)
        #expect(whole.coverage > half.coverage)
    }

    private func canvasWithErasedOutsideTail() throws -> TracingCanvasView {
        FontRegistry.registerBundledFonts()
        let canvas = TracingCanvasView(frame: CGRect(x: 0, y: 0, width: 400, height: 700))
        canvas.text = "I"
        canvas.layoutIfNeeded()
        let box = try #require(canvas.layout.glyphBoxes.first)
        let start = box.center
        let tailY = start.y + canvas.layout.lineSpacing * 2
        var original = stroke([start,
                               CGPoint(x: start.x, y: tailY),
                               CGPoint(x: start.x, y: tailY + 10)])
        original.points[0].letterIndex = 0

        // The in-letter head was erased, leaving a valid pen fragment far below the
        // text. Its points have no old glyph indices, but it still affects scoring.
        let remainder = StrokeEraser.erase(at: start, radius: 5, from: [original]).strokes
        #expect(remainder.count == 1)
        canvas.restore(remainder, capturedWidth: 400, attributed: true)
        canvas.selectRow(0)
        #expect(canvas.tally.hasInk(letter: 0))
        #expect(canvas.tally.letterContainments[0] == 0)
        return canvas
    }

    @Test("Undo reaches an unassigned outside fragment that still contributes to the row score")
    func outsideTailCanBeUndone() throws {
        let canvas = try canvasWithErasedOutsideTail()
        canvas.undo()
        #expect(canvas.strokes.isEmpty)
        #expect(!canvas.tally.hasInk(letter: 0))
    }

    @Test("Clear reaches an unassigned outside fragment that still contributes to the row score")
    func outsideTailCanBeCleared() throws {
        let canvas = try canvasWithErasedOutsideTail()
        canvas.clearSelected()
        #expect(canvas.strokes.isEmpty)
        #expect(!canvas.tally.hasInk(letter: 0))
    }
}
