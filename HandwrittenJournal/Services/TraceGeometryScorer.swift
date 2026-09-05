import CoreGraphics
import Foundation

/// Geometry is deliberately independent of touch frequency, pressure and stroke order.
/// Containment measures travelled ink; coverage measures distinct parts of the guide.
struct LetterTraceMetrics: Equatable {
    let containment: Double
    let coverage: Double
    let isComplete: Bool
    let hasInk: Bool
    let partCoverages: [Double]

    /// The harmonic mean requires both staying inside and covering the letter. A
    /// missing essential part cannot receive the highest letter award, even when that
    /// part (for example an i's dot) contributes little to the total path length.
    var accuracy: Double {
        guard hasInk, containment + coverage > 0 else { return 0 }
        let combined = 2 * containment * coverage / (containment + coverage)
        return isComplete ? combined : min(0.89, combined)
    }

    init(containment: Double, coverage: Double, isComplete: Bool,
         hasInk: Bool = true, partCoverages: [Double] = []) {
        self.containment = min(1, max(0, containment))
        self.coverage = min(1, max(0, coverage))
        self.isComplete = isComplete
        self.hasInk = hasInk
        self.partCoverages = partCoverages
    }

    static let empty = LetterTraceMetrics(containment: 0, coverage: 0,
                                          isComplete: false, hasInk: false)
}

/// Shared by journal tracing, the alphabet sheet and one-letter practice. Recreate
/// after the renderer changes layout; static guide geometry is cached per glyph and
/// only the latest result per glyph is kept, so erasing always recomputes coverage.
@MainActor
final class TraceGeometryScorer {
    /// Initial teaching thresholds, kept together for calibration against real traces.
    /// Every part must be substantially covered; dots require a hit of their own.
    static let requiredContainment = 0.85
    static let requiredCoverage = 0.85
    static let requiredPartCoverage = 0.70

    private let renderer: MaskRenderer
    private let fitter: FormationFitter
    private let pointSize: CGFloat
    private let tolerance: CGFloat
    private let sampleStep: CGFloat
    private var geometry: [Int: GlyphGeometry] = [:]
    private var results: [Int: CachedResult] = [:]

    init(setup: WritingSetup, renderer: MaskRenderer) {
        self.renderer = renderer
        fitter = FormationFitter(font: setup.uiFont())
        pointSize = setup.size.size
        tolerance = max(1, 2 * setup.size.size / 72)
        sampleStep = max(0.35, min(0.75, setup.size.size / 100))
    }

    /// Uses this letter's own outline, never the union of all ink on the page.
    func isInside(point: CGPoint, glyph: Int) -> Bool {
        geometryFor(glyph)?.contains(point) ?? false
    }

    /// Distinct coverage samples grouped by essential part. These are test/debug
    /// targets, not an ordered drawing path (fallback skeletons may branch).
    func coverageTargets(forGlyph index: Int) -> [[CGPoint]] {
        geometryFor(index)?.parts.map { $0.map(\.point) } ?? []
    }

    /// The same ownership used for scoring, including an entirely unassigned stroke
    /// far outside the text. Undo and Clear can therefore remove every penalized mark.
    func row(for stroke: TracingStroke) -> Int? {
        let boxes = renderer.layout.glyphBoxes
        let candidates = boxes.indices.filter { boxes[$0].isScorable }
        guard !stroke.isDoodle, let glyph = initialGlyph(for: stroke, candidates: candidates) else { return nil }
        return boxes[glyph].lineIndex
    }

    /// Includes untouched letters as `.empty`, making replacement of a previous tally
    /// safe after deletion. Whitespace and the separate crayon layer are never scored.
    func evaluate(strokes: [TracingStroke]) -> [Int: LetterTraceMetrics] {
        let assigned = attributedSegments(strokes: strokes, target: nil)
        var metrics: [Int: LetterTraceMetrics] = [:]
        for (index, box) in renderer.layout.glyphBoxes.enumerated() where box.isScorable {
            metrics[index] = evaluate(segments: assigned[index] ?? [], glyph: index)
        }
        return metrics
    }

    /// Practice has an explicitly selected target: all its ink, including excursions
    /// outside every advance box and taps on adjacent letters, belongs to that target.
    func evaluate(strokes: [TracingStroke], targetGlyph: Int) -> LetterTraceMetrics {
        evaluate(segments: attributedSegments(strokes: strokes, target: targetGlyph)[targetGlyph] ?? [],
                 glyph: targetGlyph)
    }

    private struct TargetSample {
        let point: CGPoint
        let weight: CGFloat
        let radius: CGFloat
        let tangent: CGPoint?
    }

    private struct GlyphGeometry {
        let path: CGPath
        let edgeTolerance: CGPath
        let bounds: CGRect
        let parts: [[TargetSample]]

        func contains(_ point: CGPoint) -> Bool {
            bounds.contains(point)
                && (path.contains(point) || edgeTolerance.contains(point))
        }
    }

    private struct InkSegment: Equatable {
        let a: CGPoint
        let b: CGPoint
        let weight: CGFloat
        /// Direction across a short neighborhood of the original pen path. Pixel-scale
        /// stair steps and touch jitter must not masquerade as a crossbar.
        var direction: CGPoint? = nil
        var midpoint: CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    }

    private struct CachedResult {
        let segments: [InkSegment]
        let metrics: LetterTraceMetrics
    }

    private func geometryFor(_ index: Int) -> GlyphGeometry? {
        if let cached = geometry[index] { return cached }
        let boxes = renderer.layout.glyphBoxes
        guard boxes.indices.contains(index), boxes[index].isScorable,
              let path = renderer.glyphPath(for: index), !path.isEmpty else { return nil }
        let widened = path.copy(strokingWithWidth: tolerance * 2, lineCap: .round,
                                lineJoin: .round, miterLimit: 2)
        func sample(_ point: CGPoint, weight: CGFloat, tangent: CGPoint? = nil) -> TargetSample {
            // Estimate local stroke half-width from the actual outline. The cap
            // prevents a thick junction or a narrow I's tap covering its length.
            let radius = min(max(tolerance, localHalfWidth(at: point, in: path) + tolerance),
                             max(tolerance, pointSize * 0.085))
            return TargetSample(point: point, weight: weight, radius: radius, tangent: tangent)
        }
        let parts: [[TargetSample]]
        if let strokes = fitter.placedStrokes(for: boxes[index]) {
            parts = strokes.compactMap { stroke -> [TargetSample]? in
                guard !stroke.points.isEmpty else { return nil }
                return sampledSegments(stroke.points).map { segment in
                    return sample(segment.midpoint,
                                  weight: stroke.isDot ? max(pointSize * 0.10, 1) : segment.weight,
                                  tangent: segment.direction)
                }
            }
        } else {
            parts = fallbackParts(path: path).map { component in
                component.map { sample($0, weight: sampleStep) }
            }
        }
        let value = GlyphGeometry(path: path, edgeTolerance: widened,
                                  bounds: path.boundingBoxOfPath.insetBy(dx: -tolerance, dy: -tolerance),
                                  parts: parts)
        geometry[index] = value
        return value
    }

    private func evaluate(segments: [InkSegment], glyph: Int) -> LetterTraceMetrics {
        guard !segments.isEmpty else {
            results[glyph] = nil
            return .empty
        }
        if let cached = results[glyph], cached.segments == segments { return cached.metrics }
        guard let guide = geometryFor(glyph), !guide.parts.isEmpty else {
            return LetterTraceMetrics(containment: 0, coverage: 0, isComplete: false)
        }
        var inside: CGFloat = 0, total: CGFloat = 0
        for segment in segments {
            total += segment.weight
            if guide.contains(segment.midpoint) { inside += segment.weight }
        }

        // A small spatial grid avoids scanning a long retraced scribble for every
        // guide sample. Each stored segment is at most sampleStep long.
        let cellSize = max(pointSize * 0.10, 2)
        var cells: [Cell: [InkSegment]] = [:]
        for segment in segments {
            cells[Cell(segment.midpoint, size: cellSize), default: []].append(segment)
        }
        var covered: CGFloat = 0, expected: CGFloat = 0
        let partCoverages = guide.parts.map { part -> Double in
            var hit: CGFloat = 0, length: CGFloat = 0
            for target in part {
                length += target.weight
                let reach = target.radius + sampleStep
                let lo = Cell(CGPoint(x: target.point.x - reach, y: target.point.y - reach), size: cellSize)
                let hi = Cell(CGPoint(x: target.point.x + reach, y: target.point.y + reach), size: cellSize)
                var found = false
                search: for x in lo.x...hi.x {
                    for y in lo.y...hi.y {
                        for segment in cells[Cell(x: x, y: y)] ?? [] {
                            if Self.covers(target, with: segment) {
                                found = true
                                break search
                            }
                        }
                    }
                }
                if found { hit += target.weight }
            }
            covered += hit
            expected += length
            return length > 0 ? Double(hit / length) : 0
        }
        let containment = total > 0 ? Double(inside / total) : 0
        let coverage = expected > 0 ? Double(covered / expected) : 0
        let complete = containment >= Self.requiredContainment
            && coverage >= Self.requiredCoverage
            && partCoverages.allSatisfy { $0 >= Self.requiredPartCoverage }
        let metrics = LetterTraceMetrics(containment: containment, coverage: coverage,
                                         isComplete: complete, partCoverages: partCoverages)
        results[glyph] = CachedResult(segments: segments, metrics: metrics)
        return metrics
    }

    private struct Cell: Hashable {
        let x: Int
        let y: Int
        init(x: Int, y: Int) { self.x = x; self.y = y }
        init(_ point: CGPoint, size: CGFloat) {
            x = Int(floor(point.x / size)); y = Int(floor(point.y / size))
        }
    }

    private static func distance(_ point: CGPoint, to segment: InkSegment) -> CGFloat {
        let dx = segment.b.x - segment.a.x, dy = segment.b.y - segment.a.y
        let squared = dx * dx + dy * dy
        let t = squared > 0
            ? min(1, max(0, ((point.x - segment.a.x) * dx + (point.y - segment.a.y) * dy) / squared)) : 0
        return hypot(point.x - segment.a.x - t * dx, point.y - segment.a.y - t * dy)
    }

    private static func covers(_ target: TargetSample, with segment: InkSegment) -> Bool {
        guard distance(target.point, to: segment) <= target.radius else { return false }
        guard let tangent = target.tangent else { return true } // A dot accepts a tap.
        guard let direction = segment.direction else { return false }
        // A thick stem can be close to nearly all of a short crossbar. Require ink
        // broadly along the part (within 60 degrees, either direction), so proximity
        // at an intersection is insufficient. This is not an order/direction judge;
        // normal wobble and an offset parallel stroke retain the full width allowance.
        return abs(direction.x * tangent.x + direction.y * tangent.y) >= 0.5
    }

    /// Midpoint integration with arc-length weights: inserting more touch events on
    /// the same segments changes neither travelled distance nor the coverage union.
    /// A stationary gesture contributes one small tap, however many events it sent.
    private func sampledSegments(_ points: [CGPoint]) -> [InkSegment] {
        let points = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard let first = points.first else { return [] }
        var segments: [InkSegment] = []
        for (a, b) in zip(points, points.dropFirst()) {
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0.0001 else { continue }
            let count = max(1, Int(ceil(length / sampleStep)))
            for i in 0..<count {
                let t0 = CGFloat(i) / CGFloat(count), t1 = CGFloat(i + 1) / CGFloat(count)
                segments.append(InkSegment(a: CGPoint(x: a.x + (b.x - a.x) * t0, y: a.y + (b.y - a.y) * t0),
                                           b: CGPoint(x: a.x + (b.x - a.x) * t1, y: a.y + (b.y - a.y) * t1),
                                           weight: length / CGFloat(count)))
            }
        }
        guard !segments.isEmpty else { return [InkSegment(a: first, b: first, weight: sampleStep)] }

        // Estimate the tangent over a real amount of travel, not a touch event or a
        // skeleton pixel. The same centered window is used for ink and guide paths,
        // and interpolation by arc length makes it independent of event density.
        var lengths: [CGFloat] = [0]
        for segment in segments { lengths.append(lengths.last! + segment.weight) }
        let total = lengths.last!
        let halfWindow = max(0.75, pointSize * 0.04)
        var before = 0, after = 0
        func point(at distance: CGFloat, index: Int) -> CGPoint {
            let segment = segments[index]
            let t = min(1, max(0, (distance - lengths[index]) / segment.weight))
            return CGPoint(x: segment.a.x + (segment.b.x - segment.a.x) * t,
                           y: segment.a.y + (segment.b.y - segment.a.y) * t)
        }
        for i in segments.indices {
            let center = lengths[i] + segments[i].weight / 2
            let lo = max(0, center - halfWindow), hi = min(total, center + halfWindow)
            while before + 1 < segments.count && lengths[before + 1] < lo { before += 1 }
            while after + 1 < segments.count && lengths[after + 1] < hi { after += 1 }
            let a = point(at: lo, index: before), b = point(at: hi, index: after)
            let dx = b.x - a.x, dy = b.y - a.y, length = hypot(b.x - a.x, b.y - a.y)
            if length > 0.0001 { segments[i].direction = CGPoint(x: dx / length, y: dy / length) }
        }
        return segments
    }

    private func attributedSegments(strokes: [TracingStroke], target: Int?) -> [Int: [InkSegment]] {
        let boxes = renderer.layout.glyphBoxes
        let scorable = boxes.indices.filter { boxes[$0].isScorable }
        guard !scorable.isEmpty else { return [:] }
        var assigned: [Int: [InkSegment]] = [:]
        for stroke in strokes where !stroke.isDoodle && !stroke.points.isEmpty {
            let segments = sampledSegments(stroke.points.map(\.location))
            guard !segments.isEmpty else { continue }
            if let target {
                if scorable.contains(target) { assigned[target, default: []].append(contentsOf: segments) }
                continue
            }
            // A row selected when writing remains the owner of off-row excursions.
            // Fully unassigned ink belongs to the nearest row and letter, so drawing
            // in the margin cannot silently disappear from the denominator.
            // Only the landing's assignment is used. Looking at how many glyphs were
            // named by the original touch events would make fast, sparse traces skip
            // letters that an identical densely sampled path visits.
            guard let initial = initialGlyph(for: stroke, candidates: scorable) else { continue }
            let candidates = scorable.filter { boxes[$0].lineIndex == boxes[initial].lineIndex }
            var owner = initial
            for segment in segments {
                let point = segment.midpoint
                if !boxes[owner].rect.contains(point),
                   let entered = candidates.filter({ boxes[$0].rect.contains(point) }).min(by: {
                       hypot(boxes[$0].center.x - point.x, boxes[$0].center.y - point.y)
                           < hypot(boxes[$1].center.x - point.x, boxes[$1].center.y - point.y)
                   }) {
                    owner = entered
                }
                // When outside every box, retain the in-progress letter until the
                // pen actually enters another. Pen lifts never create connecting ink.
                assigned[owner, default: []].append(segment)
            }
        }
        return assigned
    }

    private func initialGlyph(for stroke: TracingStroke, candidates: [Int]) -> Int? {
        guard !candidates.isEmpty,
              let landing = stroke.points.first(where: { $0.location.x.isFinite && $0.location.y.isFinite }) else { return nil }
        let boxes = renderer.layout.glyphBoxes
        if boxes.indices.contains(landing.letterIndex), boxes[landing.letterIndex].isScorable {
            return landing.letterIndex
        }
        return nearestGlyph(to: landing.location, candidates: candidates)
    }

    private func nearestGlyph(to point: CGPoint, candidates: [Int]) -> Int {
        let boxes = renderer.layout.glyphBoxes
        return candidates.min { a, b in
            func distance(_ rect: CGRect) -> CGFloat {
                let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
                let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
                return hypot(dx, dy)
            }
            let da = distance(boxes[a].rect), db = distance(boxes[b].rect)
            if abs(da - db) < 0.001 {
                return hypot(point.x - boxes[a].center.x, point.y - boxes[a].center.y)
                    < hypot(point.x - boxes[b].center.x, point.y - boxes[b].center.y)
            }
            return da < db
        } ?? candidates[0]
    }

    private func localHalfWidth(at point: CGPoint, in path: CGPath) -> CGFloat {
        guard path.contains(point) else { return 0 }
        let limit = pointSize * 0.085
        var nearest = limit
        for direction in 0..<12 {
            let angle = CGFloat(direction) * .pi / 6
            var distance: CGFloat = 0.5
            while distance < nearest {
                if !path.contains(CGPoint(x: point.x + cos(angle) * distance,
                                          y: point.y + sin(angle) * distance)) {
                    nearest = distance
                    break
                }
                distance += 0.5
            }
        }
        return nearest
    }

    /// Punctuation and characters outside the bundled teaching alphabet still need a
    /// coverage target. Thin their own outline, preserving disconnected components
    /// such as a question mark's dot. This fallback is for geometry only: it invents
    /// no teaching order. Bundled letters use the reviewed font-specific formations.
    private func fallbackParts(path: CGPath) -> [[CGPoint]] {
        let bounds = path.boundingBoxOfPath
        guard !bounds.isEmpty else { return [] }
        let step = max(0.5, max(bounds.width, bounds.height) / 150)
        let width = Int(ceil(bounds.width / step)) + 4
        let height = Int(ceil(bounds.height / step)) + 4
        func point(_ x: Int, _ y: Int) -> CGPoint {
            CGPoint(x: bounds.minX + (CGFloat(x) - 1.5) * step,
                    y: bounds.minY + (CGFloat(y) - 1.5) * step)
        }
        var pixels = [Bool](repeating: false, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) { pixels[y * width + x] = path.contains(point(x, y)) }
        }
        func components(in input: [Bool]) -> [[Int]] {
            var remaining = input
            var result: [[Int]] = []
            for seed in remaining.indices where remaining[seed] {
                var queue = [seed], cursor = 0
                remaining[seed] = false
                while cursor < queue.count {
                    let index = queue[cursor]; cursor += 1
                    let x = index % width, y = index / width
                    for dy in -1...1 {
                        for dx in -1...1 where dx != 0 || dy != 0 {
                            let nx = x + dx, ny = y + dy
                            guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                            let next = ny * width + nx
                            if remaining[next] { remaining[next] = false; queue.append(next) }
                        }
                    }
                }
                result.append(queue)
            }
            return result
        }
        let originalComponents = components(in: pixels)
        // Zhang–Suen topology-preserving thinning. Deletions in each pass are
        // simultaneous; a one-pixel dot or connection is never removed.
        var changed = true
        while changed {
            changed = false
            for pass in 0...1 {
                var remove: [Int] = []
                for y in 1..<(height - 1) {
                    for x in 1..<(width - 1) where pixels[y * width + x] {
                        let n = [pixels[(y - 1) * width + x], pixels[(y - 1) * width + x + 1],
                                 pixels[y * width + x + 1], pixels[(y + 1) * width + x + 1],
                                 pixels[(y + 1) * width + x], pixels[(y + 1) * width + x - 1],
                                 pixels[y * width + x - 1], pixels[(y - 1) * width + x - 1]]
                        let count = n.filter { $0 }.count
                        guard (2...6).contains(count),
                              (0..<8).filter({ !n[$0] && n[($0 + 1) % 8] }).count == 1 else { continue }
                        let first = pass == 0 ? (n[0] && n[2] && n[4]) : (n[0] && n[2] && n[6])
                        let second = pass == 0 ? (n[2] && n[4] && n[6]) : (n[0] && n[4] && n[6])
                        if !first && !second { remove.append(y * width + x) }
                    }
                }
                for index in remove { pixels[index] = false }
                changed = changed || !remove.isEmpty
            }
        }
        // Simultaneous thinning can consume every pixel of a final 2×2 block. Keep
        // one central ink pixel when that happens, or a period (or another glyph's
        // disconnected dot) would have no coverage target and could never complete.
        for component in originalComponents where !component.contains(where: { pixels[$0] }) {
            let cx = component.reduce(CGFloat.zero) { $0 + CGFloat($1 % width) } / CGFloat(component.count)
            let cy = component.reduce(CGFloat.zero) { $0 + CGFloat($1 / width) } / CGFloat(component.count)
            if let center = component.min(by: {
                hypot(CGFloat($0 % width) - cx, CGFloat($0 / width) - cy)
                    < hypot(CGFloat($1 % width) - cx, CGFloat($1 / width) - cy)
            }) { pixels[center] = true }
        }
        // Coverage uses point clouds grouped by component, never lines joining the
        // breadth-first traversal of a branching skeleton.
        return components(in: pixels).map { $0.map { point($0 % width, $0 / width) } }
    }
}
