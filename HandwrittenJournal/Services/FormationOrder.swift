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
///   only the *first* genuine visit to each part is judged.
/// - **Unjudgeable ink passes.** Ink that barely lies along the formation is not judged
///   at all — the inside/outside score already speaks for ink like that. The discount is
///   only for ink that clearly traced the letter the wrong way round.
enum FormationOrder {

    // MARK: - Placed geometry

    /// One formation stroke mapped into canvas space, with arclength precomputed so a
    /// sample can be located along it cheaply.
    struct PlacedStroke {
        let points: [CGPoint]
        let isDot: Bool
        /// Arclength from the stroke's start to each vertex.
        let arclength: [CGFloat]
        /// A loop (an o): direction wraps through the seam instead of ending at it.
        let isClosed: Bool

        var length: CGFloat { arclength.last ?? 0 }

        init(points: [CGPoint]) {
            self.points = points
            isDot = points.count == 1
            var running: [CGFloat] = [0]
            for i in 1..<max(1, points.count) {
                running.append(running[i - 1] + hypot(points[i].x - points[i - 1].x,
                                                      points[i].y - points[i - 1].y))
            }
            arclength = running
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
        /// Whether every stroke of the formation received a genuine visit — the whole
        /// letter was traced, not just begun. The remediation modal (§8.1b) requires
        /// this before it counts a trace as complete.
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

    /// The full reading: the order verdict plus whether the whole letter was covered.
    static func analyze(penPaths: [[CGPoint]], formation: [PlacedStroke],
                        tolerance: CGFloat) -> Analysis {
        guard !formation.isEmpty, tolerance > 0 else {
            return Analysis(followed: true, coveredAllStrokes: true)
        }

        // 1. Assign every sample to the formation stroke it is tracing. A little
        //    hysteresis keeps junctions — where two parts of a letter touch — from
        //    flickering between assignments sample by sample.
        struct Sample {
            let point: CGPoint
            let pen: Int
            let stroke: Int
            let t: CGFloat
            let distance: CGFloat
        }
        var samples: [Sample] = []
        var previous: Int?
        for (pen, path) in penPaths.enumerated() {
            for point in path {
                var best: (stroke: Int, distance: CGFloat, t: CGFloat)?
                for (i, stroke) in formation.enumerated() {
                    let (distance, t) = project(point, onto: stroke)
                    if best == nil || distance < best!.distance { best = (i, distance, t) }
                }
                guard var chosen = best, chosen.distance <= tolerance else {
                    previous = nil
                    continue
                }
                if let stay = previous, stay != chosen.stroke {
                    let (distance, t) = project(point, onto: formation[stay])
                    if distance <= tolerance, distance <= chosen.distance * 1.4 {
                        chosen = (stay, distance, t)
                    }
                }
                previous = chosen.stroke
                samples.append(Sample(point: point, pen: pen, stroke: chosen.stroke,
                                      t: chosen.t, distance: chosen.distance))
            }
        }

        // 2. Fold the samples into visits — maximal runs tracing one formation stroke.
        //    Ink that wanders off the letter and back does not end a visit; landing on a
        //    different part does. Direction steps are kept only while the pen is close
        //    to the path (0.6 × tolerance): a pen travelling *past* a part on its way
        //    somewhere else skims the edge of the band, and that transit must not read
        //    as tracing it backwards — a continuous circle-then-line `a` is legal.
        struct Visit {
            let stroke: Int
            let tFirst: CGFloat
            var travel: CGFloat = 0
            var steps: [(dt: CGFloat, travel: CGFloat)] = []
        }
        var visits: [Visit] = []
        var lastOn: Sample?
        let tight = tolerance * 0.6
        for sample in samples {
            if visits.last?.stroke != sample.stroke {
                visits.append(Visit(stroke: sample.stroke, tFirst: sample.t))
            }
            if let last = lastOn, last.stroke == sample.stroke, last.pen == sample.pen {
                let step = hypot(sample.point.x - last.point.x, sample.point.y - last.point.y)
                visits[visits.count - 1].travel += step
                if last.distance <= tight, sample.distance <= tight {
                    let stroke = formation[sample.stroke]
                    var dt = sample.t - last.t
                    if stroke.isClosed, stroke.length > 0 {
                        dt -= (dt / stroke.length).rounded() * stroke.length
                    }
                    visits[visits.count - 1].steps.append((dt: dt, travel: step))
                }
            }
            lastOn = sample
        }

        // 3. Only genuine visits count: enough pen travel to be a stroke of the letter,
        //    not a graze past a junction. Dots are a touch, not a travel.
        let kept = visits.filter { visit in
            let stroke = formation[visit.stroke]
            if stroke.isDot { return true }
            return visit.travel >= max(tolerance * 0.5, stroke.length * 0.2)
        }
        let coveredAll = Set(kept.map(\.stroke)).count == formation.count

        // Too little of the ink lies along the formation to judge fairly.
        let matched = kept.reduce(0) { $0 + $1.travel }
        let total = formation.reduce(0) { $0 + $1.length }
        guard matched >= total * 0.3 else {
            return Analysis(followed: true, coveredAllStrokes: coveredAll)
        }

        // 4. Order — the first time each part is genuinely traced must run in the
        //    taught sequence. Parts never traced are missing ink, not wrong order.
        var firstVisit: [Int: Int] = [:]
        for (i, visit) in kept.enumerated() where firstVisit[visit.stroke] == nil {
            firstVisit[visit.stroke] = i
        }
        let sequence = firstVisit.sorted { $0.value < $1.value }.map(\.key)
        guard sequence == sequence.sorted() else {
            return Analysis(followed: false, coveredAllStrokes: coveredAll)
        }

        // 5. Direction — judged on the opening travel of each part's first visit, which
        //    is where the pen declares which way it means to go. A retrace back over a
        //    correctly begun part is a go-over, not a fault.
        for (strokeIndex, keptIndex) in firstVisit {
            let stroke = formation[strokeIndex]
            guard !stroke.isDot, stroke.length > 0 else { continue }
            let visit = kept[keptIndex]
            let window = stroke.length * 0.6
            var travelled: CGFloat = 0
            var advance: CGFloat = 0
            for step in visit.steps {
                travelled += step.travel
                advance += step.dt
                if travelled >= window { break }
            }
            // Too little on-path movement to call a direction.
            guard travelled >= stroke.length * 0.2 else { continue }
            if advance <= -travelled * 0.25 {
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

    /// Nearest point on the stroke: perpendicular distance and arclength position.
    private static func project(_ point: CGPoint, onto stroke: PlacedStroke)
        -> (distance: CGFloat, t: CGFloat) {
        let points = stroke.points
        guard points.count > 1 else {
            guard let only = points.first else { return (.greatestFiniteMagnitude, 0) }
            return (hypot(point.x - only.x, point.y - only.y), 0)
        }
        var best: (distance: CGFloat, t: CGFloat) = (.greatestFiniteMagnitude, 0)
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let lengthSquared = ab.x * ab.x + ab.y * ab.y
            let u: CGFloat = lengthSquared > 0
                ? max(0, min(1, ((point.x - a.x) * ab.x + (point.y - a.y) * ab.y) / lengthSquared))
                : 0
            let nearest = CGPoint(x: a.x + ab.x * u, y: a.y + ab.y * u)
            let distance = hypot(point.x - nearest.x, point.y - nearest.y)
            if distance < best.distance {
                best = (distance, stroke.arclength[i - 1]
                        + (stroke.arclength[i] - stroke.arclength[i - 1]) * u)
            }
        }
        return best
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
        guard let formation = LetterFormations.formation(for: box.character) else { return nil }
        if let cached = verdicts[index], cached.signature == signature { return cached.analysis }

        let strokes: [FormationOrder.PlacedStroke]
        if let cached = placed[index], cached.character == box.character, cached.rect == box.rect {
            strokes = cached.strokes
        } else {
            strokes = FormationOrder.place(formation, in: fitter.formationRect(for: box))
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
        for stroke in strokes {
            var run = Int.min
            for point in stroke.points where point.letterIndex >= 0 {
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
