import Testing
import UIKit
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §14 — the test that catches a badly chosen font, and the one that
/// proves per-glyph masks line up with the guide the child actually sees.
struct MaskRendererFontTests {

    static let canvas = CGSize(width: 754, height: 530)
    static let sentence = "I saw a red bird"

    @Test("The bundled face registers and is offered in the picker")
    func bundledFaceRegisters() {
        FontRegistry.registerBundledFonts()
        #expect(FontRegistry.isAvailable("Jua-Regular"))
        #expect(JournalFace.available.contains { $0.id == "jua" })
    }

    @Test("Every offered face produces a usable mask at every size")
    func everyFaceAtEverySize() {
        FontRegistry.registerBundledFonts()
        for face in JournalFace.available {
            for size in JournalSize.all {
                let renderer = MaskRenderer()
                let layout = renderer.generate(text: Self.sentence,
                                               setup: WritingSetup(face: face, size: size, mode: .trace),
                                               canvasSize: Self.canvas,
                                               screenScale: 2)
                #expect(layout.scorableCount > 0, "no glyphs for \(face.label) at \(size.label)")
                #expect(layout.baselines.count >= 1)
                // Every scorable glyph must have real area, or it cannot be traced.
                for box in layout.glyphBoxes where box.isScorable {
                    #expect(box.rect.width > 0 && box.rect.height > 0)
                }
            }
        }
    }

    @Test("One box per non-space character, in reading order")
    func glyphBoxesMatchCharacters() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let layout = renderer.generate(text: Self.sentence, setup: .default,
                                       canvasSize: Self.canvas, screenScale: 2)
        let expected = Self.sentence.filter { !$0.isWhitespace }.count
        #expect(layout.scorableCount == expected)

        let indices = layout.glyphBoxes.map(\.charIndex)
        #expect(indices == indices.sorted())
    }

    @Test("The mask reports ink on a letter and nothing in the margin")
    func insideAndOutside() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let layout = renderer.generate(text: "III", setup: .default,
                                       canvasSize: Self.canvas, screenScale: 2)
        guard let first = layout.glyphBoxes.first(where: \.isScorable) else {
            Issue.record("no glyphs"); return
        }
        // Somewhere inside the box is ink. Testing the exact centre is wrong: a glyph
        // box spans the full advance, and for a narrow letter the centre of that advance
        // can sit in the side bearing rather than on the stem.
        var foundInk = false
        for column in stride(from: first.rect.minX, through: first.rect.maxX, by: 1) {
            if renderer.isInsideLetter(point: CGPoint(x: column, y: first.center.y), tolerance: 2) {
                foundInk = true; break
            }
        }
        #expect(foundInk, "no ink anywhere across the first glyph box")
        // Far below the text is not ink.
        #expect(!renderer.isInsideLetter(point: CGPoint(x: first.center.x, y: Self.canvas.height - 10), tolerance: 2))
    }

    @Test("A point is attributed to the letter it is nearest")
    func glyphAttribution() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let layout = renderer.generate(text: "abcdef", setup: .default,
                                       canvasSize: Self.canvas, screenScale: 2)
        for (expected, box) in layout.glyphBoxes.enumerated() where box.isScorable {
            let hit = renderer.glyphIndex(at: box.center, slack: 0)
            #expect(hit == expected, "point in box \(expected) attributed to \(String(describing: hit))")
        }
        // Far outside every letter, nothing is attributed.
        #expect(renderer.glyphIndex(at: CGPoint(x: 10, y: Self.canvas.height - 5), slack: 0) == nil)
    }

    @Test("A bigger size takes more lines for the same sentence")
    func sizeChangesLineCount() {
        FontRegistry.registerBundledFonts()
        let long = "It was brown and white and it had a little silver bell that jingled"
        func lines(_ id: String) -> Int {
            let renderer = MaskRenderer()
            return renderer.generate(text: long,
                                     setup: WritingSetup(faceID: "jua", sizeID: id, mode: .trace),
                                     canvasSize: Self.canvas, screenScale: 2).lineCount
        }
        #expect(lines("xl") > lines("xs"))
    }
}

struct StrokeEraserTests {

    private func stroke(from x: CGFloat, to end: CGFloat, y: CGFloat, letter: Int) -> TracingStroke {
        var s = TracingStroke()
        var cursor = x
        while cursor <= end {
            s.append(StrokePoint(location: CGPoint(x: cursor, y: y), force: 0.5, isInside: true, letterIndex: letter))
            cursor += 5
        }
        return s
    }

    @Test("Erasing the middle of a stroke splits it in two")
    func splitsStroke() {
        let original = [stroke(from: 0, to: 200, y: 50, letter: 0)]
        let result = StrokeEraser.erase(at: CGPoint(x: 100, y: 50), radius: 20, from: original)
        #expect(result.strokes.count == 2)
        #expect(result.touchedLetters == [0])
        #expect(result.strokes.allSatisfy { !$0.isEmpty })
    }

    @Test("Erasing away from the ink changes nothing")
    func missesCleanly() {
        let original = [stroke(from: 0, to: 100, y: 50, letter: 0)]
        let result = StrokeEraser.erase(at: CGPoint(x: 400, y: 400), radius: 36, from: original)
        #expect(result.strokes.count == 1)
        #expect(result.touchedLetters.isEmpty)
    }

    @Test("Re-tallying after an erase clears only the letters touched")
    func retallyIsolatesLetters() {
        let strokes = [stroke(from: 0, to: 60, y: 50, letter: 0),
                       stroke(from: 100, to: 160, y: 50, letter: 1)]
        var before = StrokeEraser.retally(strokes: strokes, letterCount: 2)
        #expect(before.letterAccuracies[0] == 1.0)
        #expect(before.letterAccuracies[1] == 1.0)

        let erased = StrokeEraser.erase(at: CGPoint(x: 30, y: 50), radius: 60, from: strokes)
        let after = StrokeEraser.retally(strokes: erased.strokes, letterCount: 2)
        #expect(after.letterAccuracies[0] == 0)      // wiped, back to unstarted
        #expect(after.letterAccuracies[1] == 1.0)    // untouched
        before.resetAll()
    }
}
