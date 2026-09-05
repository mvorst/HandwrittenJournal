import Testing
import UIKit
@testable import HandwrittenJournal

@MainActor
struct TraceGeometryScorerTests {
    @MainActor private struct Fixture {
        let renderer: MaskRenderer
        let scorer: TraceGeometryScorer
        let fitter: FormationFitter

        func paths(_ glyph: Int = 0) -> [FormationStroke] {
            fitter.placedStrokes(for: renderer.layout.glyphBoxes[glyph]) ?? []
        }
    }

    private func fixture(_ text: String, face: JournalFace = .default,
                         size: JournalSize = .default, scale: CGFloat = 2) -> Fixture {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup(face: face, size: size)
        let renderer = MaskRenderer()
        renderer.generate(text: text, setup: setup, canvasSize: CGSize(width: 834, height: 1000),
                          screenScale: scale, layoutOnly: true)
        return Fixture(renderer: renderer, scorer: TraceGeometryScorer(setup: setup, renderer: renderer),
                       fitter: FormationFitter(font: setup.uiFont()))
    }

    private func ink(_ points: [CGPoint], letter: Int = 0, force: CGFloat = 0.5) -> TracingStroke {
        TracingStroke(points: points.map {
            StrokePoint(location: $0, force: force, isInside: false, letterIndex: letter)
        })
    }

    private func ink(_ paths: [FormationStroke], letter: Int = 0) -> [TracingStroke] {
        paths.map { ink($0.points, letter: letter) }
    }

    private func densify(_ points: [CGPoint], subdivisions: Int) -> [CGPoint] {
        guard let last = points.last else { return [] }
        return zip(points, points.dropFirst()).flatMap { a, b in
            (0..<subdivisions).map { i in
                let t = CGFloat(i) / CGFloat(subdivisions)
                return CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
            }
        } + [last]
    }

    private func prefix(_ points: [CGPoint], fraction: CGFloat) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let length = zip(points, points.dropFirst()).reduce(CGFloat.zero) {
            $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y)
        }
        var remaining = length * fraction
        var kept = [first]
        for (a, b) in zip(points, points.dropFirst()) {
            let segment = hypot(b.x - a.x, b.y - a.y)
            if remaining <= segment, segment > 0 {
                kept.append(CGPoint(x: a.x + (b.x - a.x) * remaining / segment,
                                    y: a.y + (b.y - a.y) * remaining / segment))
                break
            }
            kept.append(b)
            remaining -= segment
        }
        return kept
    }

    @Test("Complete centerline traces pass in every font with reviewed guides without filling the glyph")
    func completeAlphabet() {
        FontRegistry.registerBundledFonts()
        for face in JournalFace.all {
            for character in PracticeSheet.characters {
                let f = fixture(String(character), face: face)
                let paths = f.paths()
                #expect(!paths.isEmpty, "Missing paths: \(face.id) \(character)")
                let result = f.scorer.evaluate(strokes: ink(paths), targetGlyph: 0)
                #expect(result.coverage > 0.99, "Coverage: \(face.id) \(character): \(result)")
                #expect(result.containment > 0.95, "Containment: \(face.id) \(character): \(result)")
                #expect(result.isComplete, "Incomplete: \(face.id) \(character): \(result)")
            }
        }
    }

    @Test("A tiny mark or repeatedly retraced small patch cannot complete a narrow letter")
    func tinyAndRepeatedMarks() {
        for face in JournalFace.all {
            for character in ["I", "l", "o"] {
                let f = fixture(character, face: face)
                let points = prefix(f.paths().max(by: { $0.points.count < $1.points.count })!.points,
                                    fraction: 0.04)
                let small = ink(points)
                let once = f.scorer.evaluate(strokes: [small], targetGlyph: 0)
                let repeated = f.scorer.evaluate(strokes: Array(repeating: small, count: 80), targetGlyph: 0)
                #expect(once.coverage < 0.60, "Tiny mark: \(face.id) \(character): \(once)")
                #expect(!repeated.isComplete)
                #expect(abs(once.coverage - repeated.coverage) < 0.0001)
                #expect(abs(once.accuracy - repeated.accuracy) < 0.0001)
            }
        }
    }

    @Test("A partially traced stem remains incomplete even when every pen sample is inside")
    func incompleteStem() {
        let f = fixture("l")
        let partial = ink(prefix(f.paths()[0].points, fraction: 0.35))
        let result = f.scorer.evaluate(strokes: [partial], targetGlyph: 0)
        #expect(result.containment > 0.95)
        #expect(result.coverage < 0.65)
        #expect(!result.isComplete)
        #expect(result.accuracy < 0.8)
    }

    @Test("Missing dots and crossbars cannot earn completion or the highest letter score")
    func missingEssentialParts() {
        for face in JournalFace.all {
            for character in ["i", "j", "t", "T"] {
                let f = fixture(character, face: face)
                let paths = f.paths()
                #expect(paths.count >= 2, "Essential parts: \(face.id) \(character)")
                guard paths.count >= 2 else { continue }
                // Each formation part is essential, including short bars and dots.
                for omitted in paths.indices {
                    let remaining = paths.enumerated().filter { $0.offset != omitted }.map(\.element)
                    let result = f.scorer.evaluate(strokes: ink(remaining), targetGlyph: 0)
                    #expect(!result.isComplete, "Missing part \(omitted): \(face.id) \(character): \(result)")
                    #expect(result.accuracy <= 0.89)
                }
            }
        }
    }

    @Test("Offset and wobbly stems and bars pass without requiring exact formation samples")
    func independentlyDrawnWobblyLetter() throws {
        let f = fixture("T")
        let path = try #require(f.renderer.glyphPath(for: 0))
        let bounds = path.boundingBoxOfPath
        func horizontalInk(at y: CGFloat) -> [CGFloat] {
            stride(from: bounds.minX, through: bounds.maxX, by: 0.25).filter {
                path.contains(CGPoint(x: $0, y: y))
            }
        }
        let barRows = stride(from: bounds.minY, through: bounds.midY, by: 0.25).filter { y in
            let xs = horizontalInk(at: y)
            return (xs.last ?? 0) - (xs.first ?? 0) > bounds.width * 0.85
        }
        let barTop = try #require(barRows.first), barBottom = try #require(barRows.last)
        let barY = (barTop + barBottom) / 2
        let stemXs = horizontalInk(at: bounds.minY + bounds.height * 0.70)
        let stemLeft = try #require(stemXs.first), stemRight = try #require(stemXs.last)
        let stemX = (stemLeft + stemRight) / 2
        func wobbly(_ a: CGPoint, _ b: CGPoint, normal: CGPoint) -> [CGPoint] {
            let length = hypot(b.x - a.x, b.y - a.y)
            return stride(from: CGFloat.zero, through: length, by: 0.5).map { distance in
                let t = distance / length
                let offset = 1.0 + 1.4 * sin(distance / 3.5)
                return CGPoint(x: a.x + (b.x - a.x) * t + normal.x * offset,
                               y: a.y + (b.y - a.y) * t + normal.y * offset)
            }
        }
        // Construct from the visible T's outline measurements, without reading its
        // formation paths. Both parts are offset and vary their direction along the way.
        let stem = ink(wobbly(CGPoint(x: stemX, y: barY),
                              CGPoint(x: stemX, y: bounds.maxY - (stemRight - stemLeft) / 2),
                              normal: CGPoint(x: 1, y: 0)))
        let bar = ink(wobbly(CGPoint(x: bounds.minX + (barBottom - barTop) / 2, y: barY),
                             CGPoint(x: bounds.maxX - (barBottom - barTop) / 2, y: barY),
                             normal: CGPoint(x: 0, y: 1)))
        let result = f.scorer.evaluate(strokes: [stem, bar], targetGlyph: 0)
        #expect(result.isComplete, "\(result)")
        #expect(result.containment >= 0.85)
    }

    @Test("Scattered stationary dots cannot substitute for tracing a stem")
    func stationaryDotsDoNotCoverAStroke() {
        let f = fixture("l")
        let taps = f.scorer.coverageTargets(forGlyph: 0).flatMap { $0.map { ink([$0]) } }
        let result = f.scorer.evaluate(strokes: taps, targetGlyph: 0)
        #expect(result.coverage == 0)
        #expect(!result.isComplete)
    }

    @Test("Touch density, repeated stationary events and pressure cannot change a trace's score")
    func speedAndPressureInvariant() {
        let f = fixture("l")
        let path = f.paths()[0].points
        let middle = path[path.count / 2]
        let outside = CGPoint(x: middle.x + 70, y: middle.y)
        let geometry = path + [outside, middle]
        let sparse = f.scorer.evaluate(strokes: [ink(geometry)], targetGlyph: 0)
        var dense = densify(geometry, subdivisions: 20)
        dense.insert(contentsOf: Array(repeating: dense[0], count: 400), at: 0)
        let slow = f.scorer.evaluate(strokes: [ink(dense, force: 1)], targetGlyph: 0)
        #expect(abs(sparse.containment - slow.containment) < 0.015)
        #expect(abs(sparse.coverage - slow.coverage) < 0.015)
        #expect(abs(sparse.accuracy - slow.accuracy) < 0.015)
        #expect(sparse.containment < 0.50)
    }

    @Test("Sparse touches that skip a glyph and dense touches on the same path receive the same attribution")
    func attributionIsIndependentOfTouchDensity() {
        let f = fixture("ll")
        let start = f.paths()[0].points[0]
        let end = CGPoint(x: f.renderer.layout.glyphBoxes[1].rect.maxX + 40, y: start.y)
        func attributed(_ points: [CGPoint]) -> TracingStroke {
            TracingStroke(points: points.map {
                StrokePoint(location: $0, force: 0.5, isInside: false,
                            letterIndex: f.renderer.glyphIndex(at: $0) ?? -1)
            })
        }
        let sparse = f.scorer.evaluate(strokes: [attributed([start, end])])
        let dense = f.scorer.evaluate(strokes: [attributed(densify([start, end], subdivisions: 120))])
        for index in 0...1 {
            #expect(sparse[index]!.hasInk == dense[index]!.hasInk)
            #expect(abs(sparse[index]!.containment - dense[index]!.containment) < 0.025)
            #expect(abs(sparse[index]!.coverage - dense[index]!.coverage) < 0.025)
        }
    }

    @Test("Off-letter excursions and entirely unassigned ink count against their owning letter")
    func excursionsCount() {
        let f = fixture("l")
        let good = ink(f.paths())
        let end = good[0].points.last!.location
        let outside = CGPoint(x: end.x + 160, y: end.y + 120)
        var excursion = good[0]
        excursion.points.append(StrokePoint(location: outside, force: 0.5, isInside: false, letterIndex: -1))
        let result = f.scorer.evaluate(strokes: [excursion])[0]!
        #expect(result.containment < 0.40)
        #expect(!result.isComplete)
        let unassigned = ink([outside, CGPoint(x: outside.x + 30, y: outside.y)], letter: -1)
        #expect(f.scorer.row(for: unassigned) == 0)
        let margin = f.scorer.evaluate(strokes: good + [unassigned])[0]!
        #expect(margin.containment < 0.85)
        #expect(!margin.isComplete)
    }

    @Test("A neighboring letter's ink never passes the target letter's containment mask")
    func neighboringGlyphIsolation() {
        let f = fixture("ll")
        let neighbor = ink(f.paths(1), letter: 0)
        let fixedTarget = f.scorer.evaluate(strokes: neighbor, targetGlyph: 0)
        #expect(fixedTarget.containment < 0.05)
        #expect(neighbor.flatMap(\.points).allSatisfy { !f.scorer.isInside(point: $0.location, glyph: 0) })
        #expect(!fixedTarget.isComplete)
    }

    @Test("Pen lifts and crayon doodles add no imaginary connecting segments")
    func penLiftsAndDoodles() {
        let f = fixture("i")
        let strokes = ink(f.paths())
        let complete = f.scorer.evaluate(strokes: strokes, targetGlyph: 0)
        var doodle = ink([CGPoint(x: 0, y: 0), CGPoint(x: 800, y: 900)])
        doodle.layer = .doodle
        #expect(f.scorer.evaluate(strokes: strokes + [doodle], targetGlyph: 0) == complete)
        #expect(complete.containment > 0.95)
        #expect(f.scorer.evaluate(strokes: [doodle], targetGlyph: 0) == .empty)
    }

    @Test("Erasing previously covered ink removes coverage and invalidates the cached completion")
    func erasingRecomputesCoverage() {
        let f = fixture("l")
        let full = ink(f.paths().map { FormationStroke(points: densify($0.points, subdivisions: 80), curved: false) })
        #expect(f.scorer.evaluate(strokes: full, targetGlyph: 0).isComplete)
        let points = full[0].points.map(\.location)
        let middle = points[points.count / 2]
        let erased = StrokeEraser.erase(at: middle, radius: 12, from: full).strokes
        let result = f.scorer.evaluate(strokes: erased, targetGlyph: 0)
        #expect(result.coverage < 0.85)
        #expect(!result.isComplete)
        #expect(f.scorer.evaluate(strokes: [], targetGlyph: 0) == .empty)
    }

    @Test("Font size and screen raster scale do not change exact path completion")
    func sizesAndScales() {
        for size in JournalSize.all {
            for scale: CGFloat in [1, 3] {
                let f = fixture("Abij", size: size, scale: scale)
                let strokes = f.renderer.layout.glyphBoxes.indices.flatMap { ink(f.paths($0), letter: $0) }
                let results = f.scorer.evaluate(strokes: strokes)
                #expect(results.values.allSatisfy { $0.isComplete }, "\(size.id) @\(scale): \(results)")
            }
        }
    }

    @Test("Punctuation uses separate outline components and still requires its dot")
    func punctuationFallback() {
        let f = fixture("!")
        let parts = f.scorer.coverageTargets(forGlyph: 0)
        #expect(parts.count >= 2)
        let full = parts.flatMap { $0.map { ink([$0]) } }
        let complete = f.scorer.evaluate(strokes: full, targetGlyph: 0)
        #expect(complete.isComplete)
        let mainPart = parts.max(by: { $0.count < $1.count }) ?? []
        #expect(!f.scorer.evaluate(strokes: mainPart.map { ink([$0]) }, targetGlyph: 0).isComplete)
    }

    @Test("Every glyph on a wrapped two-paragraph page keeps its own outline and coverage targets")
    func multilineOutlinesAndPunctuation() {
        FontRegistry.registerBundledFonts()
        let text = "Today we went to the park and I saw a big dog.\nThe dog wanted to play with me and we threw a ball for it until it got tired."
        let renderer = MaskRenderer()
        renderer.generate(text: text, setup: .default, canvasSize: CGSize(width: 834, height: 848),
                          screenScale: 2, layoutOnly: true)
        let scorer = TraceGeometryScorer(setup: .default, renderer: renderer)
        for (index, box) in renderer.layout.glyphBoxes.enumerated() where box.isScorable {
            let path = renderer.glyphPath(for: index)
            #expect(path != nil, "Missing outline: \(index) \(box.character)")
            let targets = scorer.coverageTargets(forGlyph: index)
            #expect(!targets.isEmpty, "Missing targets: \(index) \(box.character), path=\(String(describing: path?.boundingBoxOfPath))")
            #expect(targets.flatMap { $0 }.allSatisfy { box.rect.insetBy(dx: -2, dy: -2).contains($0) },
                    "Targets shifted to another glyph: \(index) \(box.character)")
            #expect(targets.flatMap { $0 }.allSatisfy { scorer.isInside(point: $0, glyph: index) })
        }
    }

    @Test("Report incremental scoring cost on a 240-letter page")
    func incrementalPageTiming() {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default
        let renderer = MaskRenderer()
        let text = Array(repeating: "Trace", count: 48).joined(separator: " ")
        renderer.generate(text: text, setup: setup, canvasSize: CGSize(width: 834, height: 6000),
                          screenScale: 1, layoutOnly: true)
        let fitter = FormationFitter(font: setup.uiFont())
        let scorer = TraceGeometryScorer(setup: setup, renderer: renderer)
        var strokes = renderer.layout.glyphBoxes.enumerated().flatMap { index, box in
            ink(fitter.placedStrokes(for: box) ?? [], letter: index)
        }
        _ = scorer.evaluate(strokes: strokes)
        let last = strokes.count - 1
        strokes[last].points[strokes[last].points.count - 1].location.x += 0.3
        let start = Date.timeIntervalSinceReferenceDate
        let results = scorer.evaluate(strokes: strokes)
        let milliseconds = (Date.timeIntervalSinceReferenceDate - start) * 1000
        print("TRACE_GEOMETRY_WARM_240_LETTERS_MS=\(milliseconds)")
        #expect(results.count == 240)
        #expect(results.values.allSatisfy { $0.hasInk })
    }
}
