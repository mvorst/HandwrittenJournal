import Testing
import CoreGraphics
import UIKit
@testable import HandwrittenJournal

/// §8.1b — the remediation flow behind the modal. A word finished with wrong-order
/// letters asks for help exactly once, at pen-up, under the child's own pen; tracing
/// a lesson's letter correctly lifts that letter's discount and no other; and a page
/// restored from an archive never prompts — its words were finished in another sitting.
@MainActor
struct FormationHelpTests {

    private func makeCanvas(text: String) -> TracingCanvasView {
        FontRegistry.registerBundledFonts()
        let canvas = TracingCanvasView()
        canvas.setup = .default
        canvas.text = text
        let height = MaskRenderer.contentHeight(text: text, setup: .default, width: 754)
        canvas.frame = CGRect(x: 0, y: 0, width: 834, height: max(400, height))
        canvas.layoutIfNeeded()
        return canvas
    }

    /// The glyph's own formation as pen strokes — a perfect trace, reordered on demand.
    private func formationInk(for glyph: Int, in canvas: TracingCanvasView,
                              reorder: ((inout [[CGPoint]]) -> Void)? = nil) -> [TracingStroke] {
        var paths = TestTraceFixtures.paths(for: glyph, on: canvas)
        reorder?(&paths)
        return paths.map(TestTraceFixtures.stroke)
    }

    @Test("Finishing a word with a wrong-order letter asks for help — once, with the right letter")
    func finishedWordAsksForHelp() {
        let canvas = makeCanvas(text: "at")
        var requests: [FormationHelpRequest] = []
        canvas.onFormationHelpNeeded = { requests.append($0) }

        // The a drawn line-before-circle; the word is not finished, so no modal yet.
        canvas.addInk(formationInk(for: 0, in: canvas) { $0.reverse() })
        #expect(requests.isEmpty)

        // The t finishes the word — the request names the a and only the a.
        canvas.addInk(formationInk(for: 1, in: canvas))
        #expect(requests.count == 1)
        #expect(requests.first?.wordText == "at")
        #expect(requests.first?.letters.map(\.character) == ["a"])
        #expect(requests.first?.letters.map(\.offset) == [0])
        #expect(canvas.tally.followedOrder[0] == false)
        #expect(canvas.tally.followedOrder[1] == true)

        // Remediation lifts exactly that letter's discount: its accuracy rises by 1/0.8.
        let before = canvas.tally.letterAccuracies[0]
        guard let picked = requests.first?.letters.first else {
            Issue.record("no letter to remediate"); return
        }
        canvas.markRemediated(letter: picked.glyph)
        let after = canvas.tally.letterAccuracies[0]
        #expect(abs(after / before - 1.0 / ScoringEngine.orderDiscount) < 0.001)
        #expect(canvas.tally.followedOrder[0] == true)
        #expect(requests.count == 1, "remediation must not prompt again")
        #expect(picked.charIndex == canvas.charIndex(ofGlyph: picked.glyph))
    }

    @Test("A word is not interrupted while its last letter is still being written")
    func helpWaitsForTheLetterToBeFinished() {
        // "at": the a drawn line-before-circle, then the t. The stem of the t gives the
        // word ink on every letter — but the t has a crossbar still to come, and the
        // modal must not cover it.
        let canvas = makeCanvas(text: "at")
        var requests: [FormationHelpRequest] = []
        canvas.onFormationHelpNeeded = { requests.append($0) }

        canvas.addInk(formationInk(for: 0, in: canvas) { $0.reverse() })
        let t = formationInk(for: 1, in: canvas)
        #expect(t.count == 2, "a t is a stem and a crossbar")
        canvas.addInk([t[0]])
        #expect(requests.isEmpty, "the stem alone only attempts the last letter")
        #expect(!canvas.tally.isComplete(letter: 1))
        #expect(!canvas.rowFullyInked(0))

        canvas.addInk([t[1]])
        #expect(canvas.tally.isComplete(letter: 1))
        #expect(requests.count == 1, "the crossbar finishes the letter — now the word can ask")
        #expect(requests.first?.letters.map(\.character) == ["a"])
    }

    @Test("Moving on to another word is finishing with the last one")
    func helpFiresWhenThePenMovesOn() {
        let canvas = makeCanvas(text: "at it")
        var requests: [FormationHelpRequest] = []
        canvas.onFormationHelpNeeded = { requests.append($0) }

        canvas.addInk(formationInk(for: 0, in: canvas) { $0.reverse() })
        canvas.addInk([formationInk(for: 1, in: canvas)[0]])   // the t's stem only
        #expect(requests.isEmpty)

        // The child leaves the t uncrossed and starts the next word: that is them
        // saying they are done with "at".
        let i = canvas.layout.glyphBoxes.firstIndex { $0.character == "i" }!
        canvas.addInk([formationInk(for: i, in: canvas)[0]])
        #expect(requests.count == 1)
        #expect(requests.first?.wordText == "at")
    }

    @Test("Every wrong letter becomes a lesson — one per distinct character, in reading order")
    func lessonsCoverEveryWrongLetter() {
        func letter(_ character: Character, glyph: Int, offset: Int) -> FormationHelpRequest.Letter {
            FormationHelpRequest.Letter(glyph: glyph, charIndex: glyph, offset: offset, character: character)
        }
        // "hello" with h, both l's and o wrong: the l's fold into one lesson that
        // carries — and so lifts — both occurrences.
        let lessons = WriteSessionViewModel.FormationHelp.lessons(for: [
            letter("h", glyph: 0, offset: 0),
            letter("l", glyph: 2, offset: 2),
            letter("l", glyph: 3, offset: 3),
            letter("o", glyph: 4, offset: 4),
        ])
        #expect(lessons.map(\.character) == ["h", "l", "o"])
        #expect(lessons.map(\.letters.count) == [1, 2, 1])
        #expect(lessons[1].offsets == [2, 3])
        #expect(lessons[1].letters.map(\.glyph) == [2, 3])
    }

    // MARK: - The modal's own canvas (§8.1b)

    /// The remediation surface as the modal builds it: one letter, full formation
    /// required, letter selected on arrival.
    private func makeModalCanvas(_ character: Character) -> PracticeCanvasView {
        FontRegistry.registerBundledFonts()
        let canvas = PracticeCanvasView()
        canvas.setup = .default
        canvas.autoSelectSoleGlyph = true
        canvas.requireFullFormation = true
        canvas.text = String(character)
        canvas.frame = CGRect(x: 0, y: 0, width: 612, height: 480)
        canvas.layoutIfNeeded()
        return canvas
    }

    private func stroke(_ path: [CGPoint]) -> TracingStroke {
        TestTraceFixtures.stroke(path)
    }

    @Test("A wrong attempt in the modal resets itself at pen-up — the doomed ink never lingers")
    func wrongModalAttemptResetsImmediately() {
        let canvas = makeModalCanvas("a")
        let paths = canvas.formationPaths(forGlyph: 0)
        #expect(paths.count == 2)

        // Line first: not wrong yet (nothing says the circle isn't coming... it is the
        // order of first visits that condemns it), so the ink stays.
        canvas.addInk([stroke(paths[1])])
        #expect(canvas.attemptFailures == 0)
        #expect(canvas.hasInk)

        // The circle lands second — the order is now wrong for good. No further ink
        // can mend a first-visit sequence, so the attempt must clear right now.
        canvas.addInk([stroke(paths[0])])
        #expect(canvas.attemptFailures == 1)
        #expect(!canvas.hasInk, "a condemned attempt must not wait around to be traced onto")
        #expect(canvas.followedOrder)
    }

    @Test("Getting it right on the second attempt completes the modal — the reported bug")
    func secondAttemptCompletes() {
        let canvas = makeModalCanvas("a")
        let paths = canvas.formationPaths(forGlyph: 0)

        // First attempt wrong: line before circle.
        canvas.addInk([stroke(paths[1])])
        canvas.addInk([stroke(paths[0])])
        #expect(canvas.attemptFailures == 1)

        // The child immediately traces it correctly — circle, then line. If the wrong
        // ink were still on the sheet this retrace would merge with it, stay condemned,
        // and the letter could never complete.
        canvas.addInk([stroke(paths[0])])
        canvas.addInk([stroke(paths[1])])
        #expect(canvas.phase == .traced("a"))
    }

    @Test("A correct first attempt still completes the modal")
    func firstAttemptStillCompletes() {
        let canvas = makeModalCanvas("a")
        let paths = canvas.formationPaths(forGlyph: 0)
        canvas.addInk([stroke(paths[0])])
        canvas.addInk([stroke(paths[1])])
        #expect(canvas.attemptFailures == 0)
        #expect(canvas.phase == .traced("a"))
    }

    @Test("A restored page never prompts, but its wrong-order ink still takes the discount")
    func restoredPagesNeverPrompt() {
        let first = makeCanvas(text: "at")
        first.addInk(formationInk(for: 0, in: first) { $0.reverse() })
        first.addInk(formationInk(for: 1, in: first))
        let archived = first.strokes

        let second = TracingCanvasView()
        var prompts = 0
        second.onFormationHelpNeeded = { _ in prompts += 1 }
        second.setup = .default
        second.restore(archived, capturedWidth: first.bounds.width)
        second.text = "at"
        second.frame = first.frame
        second.layoutIfNeeded()

        #expect(prompts == 0, "words finished in another sitting are not re-prompted")
        #expect(second.tally.followedOrder[0] == false, "the discount itself still applies")

        // A remediation recorded on the session comes back by character position.
        second.restoreRemediated(charIndices: [0])
        #expect(second.tally.followedOrder[0] == true)
        #expect(prompts == 0)
    }
}
