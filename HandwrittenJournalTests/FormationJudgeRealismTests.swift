import Testing
import CoreGraphics
import UIKit
@testable import HandwrittenJournal

/// §8.1a on a real pen, not a perfect one.
///
/// `FormationOrderTests` feeds the judge the formation's own polyline, which no child
/// ever produces. A pen lands a few points off the taught start, wobbles along the
/// path, and samples densely — and the judge must still say "followed" for a letter
/// traced the taught way. These tests synthesise that pen over every Jua letter on a
/// real laid-out page, many times, and require the false-dock rate to be negligible;
/// they also require a letter traced *against* its taught direction to still be caught,
/// so the leniency added for the pen does not blind the judge.
@MainActor
struct FormationJudgeRealismTests {

    /// A deterministic little PRNG so a failing seed can be replayed.
    private struct Rand {
        var state: UInt64
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 100_000) / 100_000
        }
        mutating func signed(_ scale: CGFloat) -> CGFloat { (next() * 2 - 1) * scale }
    }

    private struct Glyph {
        let box: MaskRenderer.GlyphBox
        let formation: [FormationOrder.PlacedStroke]
    }

    /// One letter laid out alone on the page, at Jua Large — the app's default.
    private func glyph(_ character: Character) -> Glyph? {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default
        let text = String(character)
        let renderer = MaskRenderer()
        let height = MaskRenderer.contentHeight(text: text, setup: setup, width: 754)
        let page = renderer.generate(text: text, setup: setup,
                                     canvasSize: CGSize(width: 834, height: height),
                                     screenScale: 2, layoutOnly: true)
        guard let box = page.glyphBoxes.first(where: \.isScorable),
              let formation = LetterFormations.formation(for: character) else { return nil }
        let fitter = FormationFitter(font: setup.uiFont())
        return Glyph(box: box, formation: FormationOrder.place(formation, in: fitter.formationRect(for: box)))
    }

    private var tolerance: CGFloat { max(12, WritingSetup.default.size.size * 0.22) }

    /// Resamples a polyline at `spacing` and lays a slow wobble plus fine noise across
    /// it, the way a pen does. `landing` is where the pen actually came down, a little
    /// off the taught start; the first few samples travel from there onto the path.
    private func penPath(along points: [CGPoint], landing: CGPoint, rand: inout Rand,
                         wobble: CGFloat = 1.6, noise: CGFloat = 0.5,
                         spacing: CGFloat = 0.75) -> [CGPoint] {
        guard let first = points.first else { return [] }
        if points.count == 1 {
            // A dot: a tap with a hair of movement.
            return [landing, CGPoint(x: landing.x + 0.4, y: landing.y + 0.3)]
        }
        var out: [CGPoint] = []
        // Land, then close onto the taught start.
        let approach = max(1, Int(hypot(first.x - landing.x, first.y - landing.y) / spacing))
        for i in 0..<approach {
            let t = CGFloat(i) / CGFloat(approach)
            out.append(CGPoint(x: landing.x + (first.x - landing.x) * t,
                               y: landing.y + (first.y - landing.y) * t))
        }
        let wavelength = 14 + rand.next() * 10
        let phase = rand.next() * 2 * .pi
        var travelled: CGFloat = 0
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            let normal = CGPoint(x: -(b.y - a.y) / length, y: (b.x - a.x) / length)
            var s: CGFloat = 0
            while s < length {
                let u = s / length
                let base = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
                let off = wobble * sin(2 * .pi * (travelled + s) / wavelength + phase) + rand.signed(noise)
                out.append(CGPoint(x: base.x + normal.x * off, y: base.y + normal.y * off))
                s += spacing
            }
            travelled += length
        }
        out.append(points[points.count - 1])
        return out
    }

    /// The taught trace, as a child produces it: every formation stroke in order, each
    /// in its direction, each landing a few points off its start.
    /// How far off a stroke's start the pen may land: up to six points, but never
    /// most of the stroke — nobody misses an eight-point crossbar by eight points.
    private func miss(_ stroke: FormationOrder.PlacedStroke) -> CGFloat {
        stroke.isDot ? 6 : min(6, max(2, stroke.length * 0.4))
    }

    /// The taught trace, as a child produces it: every formation stroke in order, each
    /// in its direction, each landing a few points off its start. `shaky` is a worse
    /// hand — a wider wobble and a jumpier line.
    private func taughtTrace(_ glyph: Glyph, seed: UInt64, shaky: Bool = false) -> [[CGPoint]] {
        var rand = Rand(state: seed)
        return glyph.formation.map { stroke in
            let start = stroke.points[0]
            let miss = miss(stroke)
            let landing = CGPoint(x: start.x + rand.signed(miss), y: start.y + rand.signed(miss))
            return penPath(along: stroke.points, landing: landing, rand: &rand,
                           wobble: shaky ? 2.8 : 1.6, noise: shaky ? 0.9 : 0.5)
        }
    }

    /// The same letter with every stroke drawn against its taught direction.
    private func reversedTrace(_ glyph: Glyph, seed: UInt64) -> [[CGPoint]] {
        var rand = Rand(state: seed)
        return glyph.formation.map { stroke in
            let points = Array(stroke.points.reversed())
            let start = points[0]
            let miss = miss(stroke)
            let landing = CGPoint(x: start.x + rand.signed(miss), y: start.y + rand.signed(miss))
            return penPath(along: points, landing: landing, rand: &rand)
        }
    }

    private func analyze(_ glyph: Glyph, _ paths: [[CGPoint]]) -> FormationOrder.Analysis {
        FormationOrder.analyze(penPaths: paths, formation: glyph.formation, tolerance: tolerance)
    }

    private var everyCharacter: [Character] { PracticeSheet.characters }

    // MARK: - The bar

    static let seeds: UInt64 = 40

    @Test("A letter traced the taught way — by a real pen — is never docked")
    func taughtTracesPass() {
        var report: [String] = []
        for character in everyCharacter {
            guard let glyph = glyph(character) else { Issue.record("no glyph for \(character)"); continue }
            var docked = 0
            var uncovered = 0
            for seed in 1...Self.seeds {
                let analysis = analyze(glyph, taughtTrace(glyph, seed: seed))
                if !analysis.followed { docked += 1 }
                if !analysis.coveredAllStrokes { uncovered += 1 }
            }
            if docked > 0 || uncovered > 0 {
                report.append("'\(character)': docked \(docked)/\(Self.seeds), uncovered \(uncovered)/\(Self.seeds)")
            }
            #expect(docked == 0, "'\(character)' traced the taught way was docked \(docked) times in \(Self.seeds)")
            #expect(uncovered == 0, "'\(character)' traced the taught way read as incomplete \(uncovered) times in \(Self.seeds)")
        }
        if !report.isEmpty { print("REALISM REPORT (taught):\n" + report.joined(separator: "\n")) }
    }

    @Test("A shaky hand tracing the taught way is docked only rarely")
    func shakyTaughtTracesMostlyPass() {
        var report: [String] = []
        var dockedTotal = 0
        for character in everyCharacter {
            guard let glyph = glyph(character) else { Issue.record("no glyph for \(character)"); continue }
            var docked = 0
            for seed in 1...Self.seeds where !analyze(glyph, taughtTrace(glyph, seed: seed, shaky: true)).followed {
                docked += 1
            }
            dockedTotal += docked
            if docked > 0 { report.append("'\(character)': docked \(docked)/\(Self.seeds)") }
            #expect(docked <= 2, "'\(character)' traced the taught way by a shaky hand was docked \(docked) times in \(Self.seeds)")
        }
        if !report.isEmpty { print("REALISM REPORT (shaky):\n" + report.joined(separator: "\n")) }
        // Across the whole alphabet, well under one letter in fifty.
        #expect(Double(dockedTotal) / Double(everyCharacter.count * Int(Self.seeds)) < 0.02)
    }

    /// Letters where reversing every stroke is unambiguously the wrong motion — a
    /// stem drawn bottom-up, a loop the wrong way round. (Symmetric strokes such as the
    /// crossbar of an H are excluded because the judge is right to forgive them.)
    private var directionalCharacters: [Character] {
        ["l", "i", "t", "b", "d", "h", "k", "o", "a", "c", "e", "n", "m", "r", "u",
         "L", "I", "T", "O", "C", "E", "F", "B", "D", "P", "R", "S", "s", "1", "6", "9"]
    }

    @Test("A letter traced against its taught direction is still caught")
    func reversedTracesAreCaught() {
        var report: [String] = []
        for character in directionalCharacters {
            guard let glyph = glyph(character) else { Issue.record("no glyph for \(character)"); continue }
            var passed = 0
            for seed in 1...Self.seeds where analyze(glyph, reversedTrace(glyph, seed: seed)).followed {
                passed += 1
            }
            if passed > 0 { report.append("'\(character)': reversed passed \(passed)/\(Self.seeds)") }
            #expect(passed == 0, "'\(character)' traced backwards passed \(passed) times in \(Self.seeds)")
        }
        if !report.isEmpty { print("REALISM REPORT (reversed):\n" + report.joined(separator: "\n")) }
    }

    @Test("Parts drawn in the wrong order are still caught on a real pen")
    func wrongOrderIsCaught() {
        // Line-before-circle for a, d, g, q; crossbar-before-stem for t and f.
        for character in ["a", "d", "g", "q", "t", "f", "i", "b", "p", "k"] as [Character] {
            guard let glyph = glyph(character), glyph.formation.count >= 2 else { continue }
            var passed = 0
            for seed in 1...Self.seeds {
                var paths = taughtTrace(glyph, seed: seed)
                paths.swapAt(0, 1)
                if analyze(glyph, paths).followed { passed += 1 }
            }
            #expect(passed == 0, "'\(character)' drawn out of order passed \(passed) times in \(Self.seeds)")
        }
    }
}
