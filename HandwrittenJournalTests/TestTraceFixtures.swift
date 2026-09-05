import Testing
import UIKit
@testable import HandwrittenJournal

/// Complete pen paths for integration tests that exercise real spatial scoring.
/// Each font supplies its own centerlines; punctuation uses its outline-derived targets.
@MainActor
enum TestTraceFixtures {
    static func paths(for index: Int, on canvas: TracingCanvasView) -> [[CGPoint]] {
        let box = canvas.layout.glyphBoxes[index]
        let fitter = FormationFitter(font: canvas.setup.uiFont())
        if let strokes = fitter.placedStrokes(for: box), !strokes.isEmpty {
            return strokes.map(\.points)
        }

        let renderer = MaskRenderer()
        renderer.generate(text: canvas.text, setup: canvas.setup,
                          canvasSize: canvas.bounds.size, screenScale: 1, layoutOnly: true)
        let scorer = TraceGeometryScorer(setup: canvas.setup, renderer: renderer)
        let targets = scorer.coverageTargets(forGlyph: index)
        if targets.isEmpty { Issue.record("No coverage targets for \(box.character)") }
        // Fallback skeleton components can branch. Separate taps cover the targets
        // without inventing straight connectors through the white spaces between them.
        return targets.flatMap { $0.map { [$0] } }
    }

    static func stroke(_ path: [CGPoint]) -> TracingStroke {
        var points = path
        if let dot = points.first, points.count == 1 {
            // The programmatic canvas helper accepts strokes with at least two samples.
            points.append(CGPoint(x: dot.x + 0.5, y: dot.y))
        }
        var result = TracingStroke()
        for point in points {
            result.append(StrokePoint(location: point, force: 0.6, isInside: true, letterIndex: -1))
        }
        return result
    }

    static func ink(for index: Int, on canvas: TracingCanvasView) -> [TracingStroke] {
        paths(for: index, on: canvas).map(stroke)
    }

    static func ink(row: Int, on canvas: TracingCanvasView) -> [TracingStroke] {
        (canvas.layout.scorableByLine[row] ?? []).flatMap { ink(for: $0, on: canvas) }
    }
}
