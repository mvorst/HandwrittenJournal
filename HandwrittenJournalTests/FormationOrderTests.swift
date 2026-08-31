import Testing
import CoreGraphics
import UIKit
@testable import HandwrittenJournal

/// §8.1a — the order discount. A letter clearly drawn against its taught formation
/// (parts out of sequence, or a part against its direction) keeps 80% of its score;
/// everything ambiguous passes, because the discount is a nudge, not a trap.
struct FormationOrderTests {

    private let rect = CGRect(x: 0, y: 0, width: 60, height: 60)
    private let tolerance: CGFloat = 12

    private func placed(_ character: Character) -> [FormationOrder.PlacedStroke] {
        FormationOrder.place(LetterFormations.formation(for: character)!, in: rect)
    }

    private func followed(_ character: Character, _ penPaths: [[CGPoint]]) -> Bool {
        FormationOrder.followed(penPaths: penPaths, formation: placed(character),
                                tolerance: tolerance)
    }

    // MARK: - The a of the spec: circle first, then the line, each from the top

    @Test("Circle then line, both in the taught direction, passes")
    func taughtOrderPasses() {
        let a = placed("a")
        #expect(followed("a", [a[0].points, a[1].points]))
    }

    @Test("Line before circle is the wrong order")
    func partsOutOfSequenceFail() {
        let a = placed("a")
        #expect(!followed("a", [a[1].points, a[0].points]))
    }

    @Test("The right sequence with the line drawn bottom-up is the wrong direction")
    func wrongDirectionFails() {
        let a = placed("a")
        #expect(!followed("a", [a[0].points, a[1].points.reversed()]))
    }

    @Test("One continuous motion that still goes circle-then-line passes — pen lifts don't matter")
    func continuousMotionPasses() {
        let a = placed("a")
        #expect(followed("a", [a[0].points + a[1].points]))
    }

    @Test("Going back over a finished part is a go-over, not a fault")
    func goOverPasses() {
        let a = placed("a")
        #expect(followed("a", [a[0].points, a[1].points, a[0].points]))
    }

    // MARK: - Loops

    @Test("An o drawn from the top, the taught way round, passes")
    func loopFromTheTopPasses() {
        let o = placed("o")
        #expect(followed("o", [o[0].points]))
    }

    @Test("An o drawn the wrong way round fails")
    func clockwiseLoopFails() {
        let o = placed("o")
        #expect(!followed("o", [o[0].points.reversed()]))
    }

    @Test("An o begun at the bottom fails even when it circles the right way")
    func loopFromTheBottomFails() {
        let o = placed("o")
        // Rotate the ring so the pen starts half way round, still travelling the
        // taught direction, and close it back to its new start.
        let ring = Array(o[0].points.dropLast())
        let half = ring.count / 2
        let rotated = Array(ring[half...] + ring[..<half]) + [ring[half]]
        #expect(!followed("o", [rotated]))
    }

    // MARK: - Dots

    @Test("An i is stem then dot; dotting first is the wrong order")
    func dotOrderJudged() {
        let i = placed("i")
        #expect(followed("i", [i[0].points, i[1].points]))
        #expect(!followed("i", [i[1].points, i[0].points]))
    }

    // MARK: - Benefit of the doubt

    @Test("Ink nowhere near the formation is not judged — the inside score already speaks for it")
    func unjudgeableInkPasses() {
        let far = (0..<20).map { CGPoint(x: 200 + CGFloat($0) * 3, y: 210 + CGFloat($0) * 2) }
        #expect(followed("a", [far]))
    }

    @Test("A character with no formation is never judged")
    func missingFormationNeverJudged() {
        #expect(LetterFormations.formation(for: "?") == nil)
    }

    // MARK: - The discount in the tally

    @Test("An out-of-order letter keeps 80% of its score, live and final")
    func discountTrimsTheLetter() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        for _ in 0..<10 {
            tally.record(letter: 0, isInside: true)
            tally.record(letter: 1, isInside: true)
        }
        tally.markOrder(letter: 1, followed: false)
        #expect(tally.letterAccuracies[0] == 1.0)
        #expect(abs(tally.letterAccuracies[1] - 0.8) < 0.0001)
        #expect(abs(tally.finalAccuracy - 0.9) < 0.0001)
        #expect(abs(tally.liveAccuracy - 0.9) < 0.0001)
        #expect(tally.outOfOrderCount == 1)
    }

    @Test("The discount flows into the committed score and its letter count")
    func discountFlowsIntoCommittedScore() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        for _ in 0..<10 {
            tally.record(letter: 0, isInside: true)
            tally.record(letter: 1, isInside: true)
        }
        tally.markOrder(letter: 1, followed: false)
        let result = ScoringEngine.score(tally: tally, committed: [true, true],
                                         totalWords: 1, streak: 0)
        #expect(result.outOfOrderLetters == 1)
        #expect(abs(result.accuracy - 0.9) < 0.0001)
    }

    @Test("Erasing a letter clears its order verdict along with its ink")
    func resetClearsTheVerdict() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0], totalWords: 1)
        tally.record(letter: 0, isInside: true)
        tally.markOrder(letter: 0, followed: false)
        #expect(abs(tally.letterAccuracies[0] - 0.8) < 0.0001)
        tally.reset(letter: 0)
        tally.record(letter: 0, isInside: true)
        #expect(tally.letterAccuracies[0] == 1.0)
    }

    // MARK: - End to end, on real glyph geometry

    @Test("The judge grades a real laid-out Jua glyph, and never judges punctuation")
    @MainActor
    func judgeOnRealGeometry() {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default   // Jua — the face the formations are fitted to
        let text = "a!"
        let height = MaskRenderer.contentHeight(text: text, setup: setup, width: 754)
        let page = MaskRenderer().generate(text: text, setup: setup,
                                           canvasSize: CGSize(width: 834, height: height),
                                           screenScale: 2)
        guard page.glyphBoxes.count >= 2 else { Issue.record("no glyphs laid out"); return }
        let a = page.glyphBoxes[0], bang = page.glyphBoxes[1]

        guard let judge = FormationOrderJudge(setup: setup) else {
            Issue.record("no judge for Jua"); return
        }
        let fitter = FormationFitter(font: setup.uiFont())
        let placed = FormationOrder.place(LetterFormations.formation(for: "a")!,
                                          in: fitter.formationRect(for: a))
        let circle = placed[0].points, line = placed[1].points

        #expect(judge.followedFormation(penPaths: [circle, line], glyph: 0,
                                        box: a, signature: 1) == true)
        #expect(judge.followedFormation(penPaths: [line, circle], glyph: 0,
                                        box: a, signature: 2) == false)
        #expect(judge.followedFormation(penPaths: [line], glyph: 1,
                                        box: bang, signature: 3) == nil,
                "punctuation has no formation and is never judged")
    }

    @Test("A non-Jua face gets no judge, so no discount can apply")
    @MainActor
    func otherFacesAreNotJudged() {
        let andika = WritingSetup(faceID: "andika", sizeID: "l", mode: .trace)
        #expect(FormationOrderJudge(setup: andika) == nil)
    }

    @Test("The analysis reports coverage: a letter begun is not a letter traced")
    func coverageIsReported() {
        let a = placed("a")
        let begun = FormationOrder.analyze(penPaths: [a[0].points], formation: a,
                                           tolerance: tolerance)
        #expect(begun.followed)
        #expect(!begun.coveredAllStrokes)
        let whole = FormationOrder.analyze(penPaths: [a[0].points, a[1].points], formation: a,
                                           tolerance: tolerance)
        #expect(whole.followed)
        #expect(whole.coveredAllStrokes)
    }

    @Test("The finish message names letters drawn in a different order")
    func finishMessageMentionsOrder() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        tally.record(letter: 0, isInside: true)
        tally.record(letter: 1, isInside: true)
        tally.markOrder(letter: 0, followed: false)
        tally.markOrder(letter: 1, followed: false)
        let message = ScoringEngine.finishMessage(for: ScoringEngine.score(tally: tally, streak: 0))
        #expect(message.contains("2 letters were drawn in a different order"))
    }
}
