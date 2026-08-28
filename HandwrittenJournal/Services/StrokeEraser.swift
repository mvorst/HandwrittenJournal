import CoreGraphics

/// DESIGN_DOCUMENT.md §4.4 — the eraser is *spatial*; undo is *chronological*.
///
/// They are not redundant. A child who overshoots the `a` in a ten-letter word wants to
/// fix the `a`, not unwind everything drawn after it.
enum StrokeEraser {

    /// Default rub-out radius in points — matches the 72 pt cursor in the wireframes.
    static let radius: CGFloat = 36

    /// Removes every point inside the circle. A stroke that loses its middle becomes two
    /// strokes; a stroke reduced to a single point disappears.
    static func erase(at centre: CGPoint,
                      radius: CGFloat = StrokeEraser.radius,
                      from strokes: [TracingStroke]) -> (strokes: [TracingStroke], touchedLetters: Set<Int>) {

        var out: [TracingStroke] = []
        var touched: Set<Int> = []
        let r2 = radius * radius

        for stroke in strokes {
            var current = TracingStroke()
            for point in stroke.points {
                let dx = point.location.x - centre.x
                let dy = point.location.y - centre.y
                if dx * dx + dy * dy <= r2 {
                    if point.letterIndex >= 0 { touched.insert(point.letterIndex) }
                    if !current.isEmpty { out.append(current) }
                    current = TracingStroke()
                } else {
                    current.append(point)
                }
            }
            if !current.isEmpty { out.append(current) }
        }
        return (out, touched)
    }

    /// Rebuilds the per-letter tally from what survives. Cheaper to recompute than to
    /// unpick, and it cannot drift from the strokes.
    static func retally(strokes: [TracingStroke], letterCount: Int) -> ScoringEngine.Tally {
        var tally = ScoringEngine.Tally(letterCount: letterCount)
        for stroke in strokes {
            for point in stroke.points where point.letterIndex >= 0 {
                tally.record(letter: point.letterIndex, isInside: point.isInside)
            }
        }
        return tally
    }
}
