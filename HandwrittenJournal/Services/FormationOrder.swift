import CoreGraphics
import Foundation
import UIKit

/// Judges whether a letter's ink followed its taught formation — the stroke order and
/// per-stroke direction the practice sheet demonstrates (§8.1a). A letter that clearly
/// took the wrong path keeps only `ScoringEngine.orderDiscount` of its score.
///
/// The judgment is deliberately lenient, because the discount is a teaching nudge and a
/// five-year-old's pen is noisy:
///
/// - **Pen lifts are ignored.** An `a` drawn in one motion that still goes
///   circle-then-line, each part in its taught direction, passes.
/// - **Go-overs are ignored.** Returning to darken a part already drawn is not a fault;
///   only the *first* genuine visit to each part is judged, and that visit is judged on
///   its net motion — a pen that runs up a stem to start it from the top has not drawn
///   the stem upwards.
/// - **Unjudgeable ink passes.** Ink that barely lies along the formation is not judged
///   at all — the inside/outside score already speaks for ink like that. The discount is
///   only for ink that clearly traced the letter the wrong way round.
///
/// **The judge tracks the pen along the path rather than snapping each sample to the
/// nearest point of it.** Letterforms pass close to themselves — the bar of an `e` starts
/// two points from the arc that comes back round to it, the tail of a `y` runs up the
/// same line its second stroke runs down, every stem meets its bowl — and a nearest-point
/// reading flickers between those parts sample by sample, producing "backwards" verdicts
/// for letters drawn exactly as taught. So the pen's position along a part is carried
/// forward and only moves as far as the pen moves, a part is only surrendered once the
/// pen is clearly off it, and where a fresh pen lands between two parts, the part it
/// then *moves along* is the one it meant.
enum FormationOrder {

    // MARK: - Placed geometry

    /// One formation stroke mapped into canvas space, with arclength precomputed so a
    /// sample can be located along it cheaply.
    struct PlacedStroke {
        let points: [CGPoint]
        let isDot: Bool
        /// Arclength from the stroke's start to each vertex.
        let arclength: [CGFloat]
        /// Unit direction of each segment, `points[i]` → `points[i + 1]`.
        let tangents: [CGPoint]
        /// A loop (an o): direction wraps through the seam instead of ending at it.
        let isClosed: Bool

        var length: CGFloat { arclength.last ?? 0 }

        init(points: [CGPoint]) {
            self.points = points
            isDot = points.count == 1
            var running: [CGFloat] = [0]
            var tangents: [CGPoint] = []
            for i in 1..<max(1, points.count) {
                let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
                let length = hypot(dx, dy)
                running.append(running[i - 1] + length)
                tangents.append(length > 0 ? CGPoint(x: dx / length, y: dy / length) : .zero)
            }
            arclength = running
            self.tangents = tangents
            let length = running.last ?? 0
            isClosed = points.count > 2 && length > 0
                && hypot(points[0].x - points[points.count - 1].x,
                         points[0].y - points[points.count - 1].y) < length * 0.1
        }
    }

    /// The formation placed into a glyph's formation rect, unsmoothed — the judge
    /// measures order and direction, not corner roundness, and the raw polyline is
    /// cheaper to project against.
    static func place(_ formation: LetterFormation, in rect: CGRect) -> [PlacedStroke] {
        formation.strokes.map { stroke in
            PlacedStroke(points: stroke.points.map {
                CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
            })
        }
    }

    // MARK: - The verdict

    /// What one look at a letter's ink concluded.
    struct Analysis: Equatable {
        /// False when the ink clearly took the parts out of the taught order or drew a
        /// part against its taught direction (§8.1a).
        let followed: Bool
        /// Whether every stroke received a substantial visit during order analysis.
        /// This legacy heuristic can include retracing; geometric completion must use
        /// TraceGeometryScorer's distinct coverage instead.
        let coveredAllStrokes: Bool
    }

    /// Whether the pen followed the formation. `penPaths` is the glyph's ink — one array
    /// per uninterrupted run of the pen on this letter, in the order they were drawn.
    /// `tolerance` is how far ink may sit from the taught path and still be judged
    /// against it: roughly the letterform's stroke width.
    static func followed(penPaths: [[CGPoint]], formation: [PlacedStroke],
                         tolerance: CGFloat) -> Bool {
        analyze(penPaths: penPaths, formation: formation, tolerance: tolerance).followed
    }

    /// Where a sample sits relative to one stroke: how far off it, how far along it,
    /// and which way the stroke runs there.
    private struct Projection {
        let distance: CGFloat
        let t: CGFloat
        let tangent: CGPoint
    }

    private struct Sample {
        let point: CGPoint
        let pen: Int
        let stroke: Int
        let projection: Projection
    }

    /// The full reading: the order verdict plus whether the whole letter was covered.
    static func analyze(penPaths: [[CGPoint]], formation: [PlacedStroke],
                        tolerance: CGFloat) -> Analysis {
        guard !formation.isEmpty, tolerance > 0 else {
            return Analysis(followed: true, coveredAllStrokes: true)
        }

        // Direction and progress are only read while the pen is close to the path
        // (0.6 × tolerance): a pen travelling *past* a part on its way somewhere else
        // skims the edge of the band, and that transit must not read as tracing it.
        let tight = tolerance * 0.6
        // A part in hand is kept while the pen is this close to it, whatever else is
        // near: letterforms cross and touch — the crossbar of a t, the bowl of a b
        // meeting its stem — and a nearest-part reading would hand the pen back and
        // forth at every such junction. Further off than this, and nearer to another
        // part, the pen's motion decides which part it is on.
        let hold = tolerance * 0.2
        // How far ahead to look when the pen lands between parts, or is contested by
        // one. Long enough that the stroke itself outweighs the pen's landing wobble.
        let lookahead = max(tolerance * 2, 12)

        let samples = assign(penPaths: penPaths, formation: formation,
                             tolerance: tolerance, hold: hold, lookahead: lookahead)

        // Fold the samples into visits — maximal runs tracing one formation stroke.
        // Ink that wanders off the letter and back does not end a visit; landing on a
        // different part does.
        struct Visit {
            let stroke: Int
            let tFirst: CGFloat
            /// Pen distance covered while on this part, any distance from the path.
            var travel: CGFloat = 0
            /// Movement *along* the part, either way, read only while close to it —
            /// a pen milling about at a junction has travel but no progress.
            var progress: CGFloat = 0
            /// Net movement in the part's taught direction, read only while close.
            var advance: CGFloat = 0
            /// Pen distance behind `advance`, so the two can be compared.
            var judged: CGFloat = 0
        }
        var visits: [Visit] = []
        var lastOn: Sample?
        for sample in samples {
            if visits.last?.stroke != sample.stroke {
                visits.append(Visit(stroke: sample.stroke, tFirst: sample.projection.t))
            }
            if let last = lastOn, last.stroke == sample.stroke, last.pen == sample.pen {
                let dx = sample.point.x - last.point.x, dy = sample.point.y - last.point.y
                let step = hypot(dx, dy)
                visits[visits.count - 1].travel += step
                if last.projection.distance <= tight, sample.projection.distance <= tight {
                    let stroke = formation[sample.stroke]
                    var dt = sample.projection.t - last.projection.t
                    if stroke.isClosed, stroke.length > 0 {
                        dt -= (dt / stroke.length).rounded() * stroke.length
                    }
                    let tangent = sample.projection.tangent
                    visits[visits.count - 1].progress += abs(dt)
                    visits[visits.count - 1].advance += dx * tangent.x + dy * tangent.y
                    visits[visits.count - 1].judged += step
                }
            }
            lastOn = sample
        }

        // Only genuine visits count: enough pen travel to be a stroke of the letter,
        // and a substantial share of it *along* the part — a pen landing beside a
        // junction and dragging to the corner has travel on the wrong part but little
        // progress. Dots are a touch, not a travel.
        let kept = visits.filter { visit in
            let stroke = formation[visit.stroke]
            if stroke.isDot { return true }
            return visit.travel >= max(tolerance * 0.5, stroke.length * 0.2)
                && visit.progress >= stroke.length * 0.5
        }
        let coveredAll = Set(kept.map(\.stroke)).count == formation.count

        // Too little of the ink lies along the formation to judge fairly.
        let matched = kept.reduce(0) { $0 + $1.travel }
        let total = formation.reduce(0) { $0 + $1.length }
        guard matched >= total * 0.3 else {
            return Analysis(followed: true, coveredAllStrokes: coveredAll)
        }

        // Order — the first time each part is genuinely traced must run in the taught
        // sequence. Parts never traced are missing ink, not wrong order.
        var firstVisit: [Int: Int] = [:]
        for (i, visit) in kept.enumerated() where firstVisit[visit.stroke] == nil {
            firstVisit[visit.stroke] = i
        }
        let sequence = firstVisit.sorted { $0.value < $1.value }.map(\.key)
        guard sequence == sequence.sorted() else {
            return Analysis(followed: false, coveredAllStrokes: coveredAll)
        }

        // Direction — the net motion of each part's first visit, against the part's
        // own direction. Net, not opening: a pen that runs up a stem to begin it from
        // the top and then draws it down has drawn it down. Only a visit that on
        // balance ran the wrong way is a fault.
        for (strokeIndex, keptIndex) in firstVisit {
            let stroke = formation[strokeIndex]
            guard !stroke.isDot, stroke.length > 0 else { continue }
            let visit = kept[keptIndex]
            // Too little on-path movement to call a direction.
            guard visit.judged >= stroke.length * 0.2 else { continue }
            if visit.advance <= -visit.judged * 0.25 {
                return Analysis(followed: false, coveredAllStrokes: coveredAll)
            }
            // A loop must also begin near its taught start — an o begun at the bottom
            // is the wrong motion even when it circles the right way.
            if stroke.isClosed {
                let fromStart = min(visit.tFirst, stroke.length - visit.tFirst)
                if fromStart > stroke.length * 0.3 {
                    return Analysis(followed: false, coveredAllStrokes: coveredAll)
                }
            }
        }
        return Analysis(followed: true, coveredAllStrokes: coveredAll)
    }

    // MARK: - Assigning ink to parts

    /// Decides which formation stroke each pen sample is tracing.
    private static func assign(penPaths: [[CGPoint]], formation: [PlacedStroke],
                               tolerance: CGFloat, hold: CGFloat, lookahead: CGFloat) -> [Sample] {
        var samples: [Sample] = []
        let dots = formation.indices.filter { formation[$0].isDot }

        for (pen, path) in penPaths.enumerated() where !path.isEmpty {
            // A tap is the dot of an i or a j when one is near enough to be meant — a
            // dot placed a little low must not be read as a touch on the stem.
            let travel = zip(path, path.dropFirst()).reduce(CGFloat(0)) {
                $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y)
            }
            if travel < tolerance,
               let dot = dots.min(by: { distance(path[0], formation[$0].points[0])
                                        < distance(path[0], formation[$1].points[0]) }),
               distance(path[0], formation[dot].points[0]) <= tolerance * 1.5 {
                for point in path {
                    samples.append(Sample(point: point, pen: pen, stroke: dot,
                                          projection: project(point, onto: formation[dot])))
                }
                continue
            }

            var current: (stroke: Int, t: CGFloat)?
            for (index, point) in path.enumerated() {
                var chosen: (stroke: Int, projection: Projection)?

                if let held = current {
                    // Carry the pen along the part it is on: look for it near where it
                    // was, so a part that passes close to itself cannot pull the reading
                    // across to its other side.
                    let stroke = formation[held.stroke]
                    let local = project(point, onto: stroke, near: held.t,
                                        window: max(tolerance * 2, stroke.length * 0.25))
                    if local.distance <= tolerance {
                        let nearest = nearestStroke(to: point, in: formation)
                        if local.distance <= hold || nearest == nil || nearest!.stroke == held.stroke
                            || local.distance <= nearest!.projection.distance * 1.4 {
                            chosen = (held.stroke, local)
                        } else {
                            // Contested: another part is clearly nearer. The part the
                            // pen goes on to move along keeps it — a crossbar crossing
                            // its stem is still the crossbar.
                            var candidates = candidates(for: point, in: formation, tolerance: tolerance)
                            if let i = candidates.firstIndex(where: { $0.stroke == held.stroke }) {
                                candidates[i] = (held.stroke, local)
                            } else {
                                candidates.append((held.stroke, local))
                            }
                            chosen = choose(among: candidates, path: path, from: index,
                                            formation: formation, tolerance: tolerance,
                                    hold: hold, lookahead: lookahead)
                        }
                    }
                }

                if chosen == nil {
                    // A fresh pen, or one that has left its part: every part within
                    // reach is a candidate, and the one the pen goes on to move along
                    // is the one it meant.
                    let candidates = candidates(for: point, in: formation, tolerance: tolerance)
                    guard !candidates.isEmpty else { current = nil; continue }
                    chosen = choose(among: candidates, path: path, from: index,
                                    formation: formation, tolerance: tolerance,
                                    hold: hold, lookahead: lookahead)
                }

                guard let pick = chosen else { current = nil; continue }
                samples.append(Sample(point: point, pen: pen, stroke: pick.stroke, projection: pick.projection))
                current = (pick.stroke, pick.projection.t)
            }
        }
        return samples
    }

    /// Which of several parts a landing pen meant: the one it then moves along.
    ///
    /// Only parts the pen *stays with* over the lookahead can compete — a stem drawn
    /// bottom-up runs through the point where its hump begins and for a moment moves
    /// the way the hump opens, but it does not stay with the hump, and a stem drawn
    /// upwards must be judged as one. Among the parts it stays with, the one it moves
    /// along wins; a dot has no direction and can only win by being nearest when
    /// nothing else is being traced.
    private static func choose(among candidates: [(stroke: Int, projection: Projection)],
                               path: [CGPoint], from index: Int, formation: [PlacedStroke],
                               tolerance: CGFloat, hold: CGFloat, lookahead: CGFloat)
        -> (stroke: Int, projection: Projection) {
        guard candidates.count > 1 else { return candidates[0] }

        // Credit each part with the pen's motion along it, weighted by how close the
        // pen is to it; note how much of the way the pen stayed near it, and how far
        // from it the pen ran on average.
        let near = tolerance * 0.5
        var alignment = [CGFloat](repeating: 0, count: candidates.count)
        var stayed = [CGFloat](repeating: 0, count: candidates.count)
        var offset = candidates.map(\.projection.distance)
        var along = candidates.map(\.projection.t)
        var travelled: CGFloat = 0
        var steps: CGFloat = 1
        var i = index + 1
        while i < path.count, travelled < lookahead {
            let a = path[i - 1], b = path[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let step = hypot(dx, dy)
            travelled += step
            steps += 1
            for (c, candidate) in candidates.enumerated() {
                let stroke = formation[candidate.stroke]
                let projection = stroke.isDot
                    ? project(b, onto: stroke)
                    : project(b, onto: stroke, near: along[c],
                              window: max(tolerance * 2, stroke.length * 0.25))
                offset[c] += min(projection.distance, tolerance)
                guard projection.distance <= tolerance else { continue }
                if projection.distance <= near { stayed[c] += step }
                guard !stroke.isDot else { continue }
                let weight = 1 - projection.distance / tolerance
                alignment[c] += (dx * projection.tangent.x + dy * projection.tangent.y) * weight
                along[c] = projection.t
            }
            i += 1
        }

        let eligible = candidates.indices.filter { stayed[$0] >= travelled * 0.5 }
        let pool = eligible.isEmpty ? Array(candidates.indices) : eligible

        // A pen plainly *on* one part — half as far from it as from any other, the
        // whole way — is tracing that part, whichever way it is going. Direction only
        // decides between parts the pen is equally close to.
        let byOffset = pool.sorted { offset[$0] < offset[$1] }
        if byOffset.count > 1, offset[byOffset[0]] < offset[byOffset[1]] * 0.5 {
            return candidates[byOffset[0]]
        }
        let best = pool.map { alignment[$0] }.max() ?? 0
        if best > 0 {
            // The part the pen runs along; between parts it runs along equally, the
            // nearer one.
            let leading = pool.filter { alignment[$0] >= best * 0.9 }
            let pick = leading.min { candidates[$0].projection.distance < candidates[$1].projection.distance }!
            return candidates[pick]
        }
        let pick = pool.min { candidates[$0].projection.distance < candidates[$1].projection.distance }!
        return candidates[pick]
    }

    /// Every part within reach of a point.
    private static func candidates(for point: CGPoint, in formation: [PlacedStroke],
                                   tolerance: CGFloat) -> [(stroke: Int, projection: Projection)] {
        formation.indices.compactMap { i in
            let projection = project(point, onto: formation[i])
            return projection.distance <= tolerance ? (i, projection) : nil
        }
    }

    private static func nearestStroke(to point: CGPoint, in formation: [PlacedStroke])
        -> (stroke: Int, projection: Projection)? {
        var best: (stroke: Int, projection: Projection)?
        for (i, stroke) in formation.enumerated() {
            let projection = project(point, onto: stroke)
            if best == nil || projection.distance < best!.projection.distance {
                best = (i, projection)
            }
        }
        return best
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Nearest point on the stroke: perpendicular distance, arclength position and the
    /// stroke's direction there. With `near`, only the stretch of the stroke within
    /// `window` of that arclength is searched — following the pen rather than snapping
    /// it — wrapping through the seam of a loop.
    private static func project(_ point: CGPoint, onto stroke: PlacedStroke,
                                near: CGFloat? = nil, window: CGFloat = 0) -> Projection {
        let points = stroke.points
        guard points.count > 1 else {
            guard let only = points.first else {
                return Projection(distance: .greatestFiniteMagnitude, t: 0, tangent: .zero)
            }
            return Projection(distance: distance(point, only), t: 0, tangent: .zero)
        }
        var best = Projection(distance: .greatestFiniteMagnitude, t: 0, tangent: .zero)
        for i in 1..<points.count {
            if let near, !within(window, of: near, segmentFrom: stroke.arclength[i - 1],
                                  to: stroke.arclength[i], stroke: stroke) {
                continue
            }
            let a = points[i - 1], b = points[i]
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let lengthSquared = ab.x * ab.x + ab.y * ab.y
            let u: CGFloat = lengthSquared > 0
                ? max(0, min(1, ((point.x - a.x) * ab.x + (point.y - a.y) * ab.y) / lengthSquared))
                : 0
            let nearest = CGPoint(x: a.x + ab.x * u, y: a.y + ab.y * u)
            let distance = hypot(point.x - nearest.x, point.y - nearest.y)
            if distance < best.distance {
                best = Projection(distance: distance,
                                  t: stroke.arclength[i - 1] + (stroke.arclength[i] - stroke.arclength[i - 1]) * u,
                                  tangent: stroke.tangents[i - 1])
            }
        }
        return best
    }

    /// Whether a segment's arclength span lies within `window` of `centre`, allowing
    /// for the seam of a closed stroke.
    private static func within(_ window: CGFloat, of centre: CGFloat,
                               segmentFrom start: CGFloat, to end: CGFloat,
                               stroke: PlacedStroke) -> Bool {
        let low = centre - window, high = centre + window
        if end >= low && start <= high { return true }
        guard stroke.isClosed, stroke.length > 0 else { return false }
        let length = stroke.length
        return (end + length >= low && start + length <= high)
            || (end - length >= low && start - length <= high)
    }
}

// MARK: - The judge for a laid-out page

/// Applies `FormationOrder` to one page: gates to the face the formations are honest
/// for, places each glyph's formation once, and caches verdicts so a full-page retally
/// only re-judges letters whose ink changed.
@MainActor
final class FormationOrderJudge {

    /// The one face the stroke-order data is hand-fitted to (§4.11). Every other face
    /// scores exactly as before — the app only grades an order it has demonstrated.
    static let honestFaceID = "jua"

    private let fitter: FormationFitter
    private let tolerance: CGFloat
    private var placed: [Int: (character: Character, rect: CGRect,
                               strokes: [FormationOrder.PlacedStroke])] = [:]
    private var verdicts: [Int: (signature: Int, analysis: FormationOrder.Analysis)] = [:]

    /// nil for any face the formations are not fitted to — no judge, no discount.
    init?(setup: WritingSetup) {
        guard setup.face.id == Self.honestFaceID else { return nil }
        fitter = FormationFitter(font: setup.uiFont())
        tolerance = max(12, setup.size.size * 0.22)
    }

    /// Whether this glyph's ink followed its formation, or nil when the character has no
    /// formation (punctuation) — never judged, never docked.
    func followedFormation(penPaths: [[CGPoint]], glyph index: Int,
                           box: MaskRenderer.GlyphBox, signature: Int) -> Bool? {
        analysis(penPaths: penPaths, glyph: index, box: box, signature: signature)?.followed
    }

    /// The full reading — order verdict plus coverage — or nil when the character has
    /// no formation. `signature` fingerprints the ink (and the box) so an unchanged
    /// letter returns its cached analysis.
    func analysis(penPaths: [[CGPoint]], glyph index: Int,
                  box: MaskRenderer.GlyphBox, signature: Int) -> FormationOrder.Analysis? {
        if let cached = verdicts[index], cached.signature == signature { return cached.analysis }

        let strokes: [FormationOrder.PlacedStroke]
        if let cached = placed[index], cached.character == box.character, cached.rect == box.rect {
            strokes = cached.strokes
        } else {
            guard let fitted = fitter.placedStrokes(for: box) else { return nil }
            strokes = fitted.map { FormationOrder.PlacedStroke(points: $0.points) }
            placed[index] = (box.character, box.rect, strokes)
        }
        let analysis = FormationOrder.analyze(penPaths: penPaths, formation: strokes,
                                              tolerance: tolerance)
        verdicts[index] = (signature, analysis)
        return analysis
    }

    /// The ink of one glyph as `FormationOrder` wants it: each stroke's points split
    /// into the runs attributed to that glyph, in drawing order. Points the pen spent on
    /// a neighbouring letter break a run — their travel is the neighbour's story.
    nonisolated static func penPathsByLetter(in strokes: [TracingStroke]) -> [Int: [[CGPoint]]] {
        var paths: [Int: [[CGPoint]]] = [:]
        for stroke in strokes where !stroke.isDoodle {
            var run = Int.min
            for point in stroke.points {
                guard point.letterIndex >= 0 else { run = Int.min; continue }
                let letter = point.letterIndex
                if letter != run {
                    paths[letter, default: []].append([])
                    run = letter
                }
                paths[letter]![paths[letter]!.count - 1].append(point.location)
            }
        }
        return paths
    }

    /// A cheap fingerprint of one glyph's ink and box for the verdict cache. Any edit
    /// that changes the ink — a new stroke, an undo, an erase — moves it.
    nonisolated static func signature(of penPaths: [[CGPoint]], box: MaskRenderer.GlyphBox) -> Int {
        var hasher = Hasher()
        hasher.combine(box.character)
        hasher.combine(box.rect.origin.x.bitPattern)
        hasher.combine(box.rect.origin.y.bitPattern)
        hasher.combine(penPaths.count)
        for run in penPaths {
            hasher.combine(run.count)
            if let first = run.first {
                hasher.combine(first.x.bitPattern)
                hasher.combine(first.y.bitPattern)
            }
            if let last = run.last {
                hasher.combine(last.x.bitPattern)
                hasher.combine(last.y.bitPattern)
            }
        }
        return hasher.finalize()
    }
}
