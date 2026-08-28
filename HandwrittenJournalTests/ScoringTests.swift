import Testing
import CoreGraphics
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §14 — "the important one". An untraced letter must score zero, or
/// "trace four letters and tap Done" scores ~95% and the number is a lie.
struct PerLetterScoringTests {

    @Test("An untouched letter in a word you started scores zero")
    func untouchedLetterScoresZero() {
        // One four-letter word. The child inks only the first letter.
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 0, 0], totalWords: 1)
        for _ in 0..<10 { tally.record(letter: 0, isInside: true) }
        #expect(tally.letterAccuracies == [1, 0, 0, 0])
        #expect(tally.unfinishedCount == 3)
        #expect(abs(tally.finalAccuracy - 0.25) < 0.0001)
    }

    @Test("Skipping letters inside a word you started still scores zero for them")
    func skippedLettersInsideAWordCount() {
        // One word, "sunshine" — eight letters, the child traces only the first three.
        var tally = ScoringEngine.Tally(wordOfLetter: Array(repeating: 0, count: 8), totalWords: 1)
        for letter in 0..<3 {
            for _ in 0..<10 { tally.record(letter: letter, isInside: true) }
        }
        #expect(tally.wordsWritten == 1)
        #expect(tally.unfinishedCount == 5)
        #expect(abs(tally.finalAccuracy - 3.0 / 8.0) < 0.0001)
        // The live figure reflects only what was attempted.
        #expect(tally.liveAccuracy == 1.0)
    }

    @Test("Words never reached are not scored — stopping part-way is not failing")
    func unreachedWordsAreNotPenalised() {
        // Ten words of three letters each; the child writes the first two words perfectly.
        let wordOf = (0..<30).map { $0 / 3 }
        var tally = ScoringEngine.Tally(wordOfLetter: wordOf, totalWords: 10)
        for letter in 0..<6 {
            for _ in 0..<10 { tally.record(letter: letter, isInside: true) }
        }
        #expect(tally.wordsWritten == 2)
        #expect(tally.unfinishedCount == 0)
        // 100%, not 20% — the other eight words are unwritten, not wrong.
        #expect(tally.finalAccuracy == 1.0)

        let result = ScoringEngine.score(tally: tally, streak: 3)
        #expect(result.wordsWritten == 2)
        #expect(result.totalWords == 10)
        #expect(!result.finishedEverything)
        #expect(result.wordsRemaining == 8)
    }

    @Test("Live accuracy ignores skipped letters; final accuracy does not")
    func liveAndFinalDiffer() {
        // A single ten-letter word, five of them inked at 80% each.
        var tally = ScoringEngine.Tally(wordOfLetter: Array(repeating: 0, count: 10), totalWords: 1)
        for letter in 0..<5 {
            for i in 0..<10 { tally.record(letter: letter, isInside: i < 8) }
        }
        #expect(abs(tally.liveAccuracy - 0.8) < 0.0001)
        #expect(abs(tally.finalAccuracy - 0.4) < 0.0001)   // the five skipped letters count zero
        #expect(tally.startedCount == 5)
        #expect(tally.unfinishedCount == 5)
    }

    @Test("Stars match the fixture accuracies in WIREFRAME_SPEC §14")
    func starThresholds() {
        #expect(ScoringEngine.stars(forAccuracy: 0.94) == 3)
        #expect(ScoringEngine.stars(forAccuracy: 0.91) == 3)
        #expect(ScoringEngine.stars(forAccuracy: 0.90) == 3)
        #expect(ScoringEngine.stars(forAccuracy: 0.88) == 2)
        #expect(ScoringEngine.stars(forAccuracy: 0.81) == 2)
        #expect(ScoringEngine.stars(forAccuracy: 0.78) == 2)
        #expect(ScoringEngine.stars(forAccuracy: 0.66) == 1)
        #expect(ScoringEngine.stars(forAccuracy: 0.61) == 1)
        #expect(ScoringEngine.stars(forAccuracy: 0.40) == 0)
    }

    @Test("Points reproduce the canonical figures: 183 and 224")
    func canonicalPoints() {
        var low = ScoringEngine.Tally(letterCount: 100)
        for letter in 0..<100 {
            for i in 0..<100 { low.record(letter: letter, isInside: i < 78) }
        }
        let a = ScoringEngine.score(tally: low, streak: 5)
        #expect(a.stars == 2)
        #expect(a.totalPoints == 183)     // 78 + 50 + 25 + 30

        var high = ScoringEngine.Tally(letterCount: 100)
        for letter in 0..<100 {
            for i in 0..<100 { high.record(letter: letter, isInside: i < 94) }
        }
        let b = ScoringEngine.score(tally: high, streak: 5)
        #expect(b.stars == 3)
        #expect(b.totalPoints == 224)     // 94 + 75 + 25 + 30
    }

    @Test("The streak bonus is capped at five days")
    func streakCap() {
        var tally = ScoringEngine.Tally(letterCount: 1)
        tally.record(letter: 0, isInside: true)
        let long = ScoringEngine.score(tally: tally, streak: 40)
        let five = ScoringEngine.score(tally: tally, streak: 5)
        #expect(long.streakBonus == five.streakBonus)
        #expect(long.streakBonus == 25)
    }

    @Test("Erasing a letter clears its tally so it can be re-traced")
    func eraseResetsLetter() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        for i in 0..<10 { tally.record(letter: 1, isInside: i < 2) }   // a bad letter
        #expect(tally.letterAccuracies[1] < 0.3)
        tally.reset(letter: 1)
        #expect(tally.letterAccuracies[1] == 0)
        for _ in 0..<10 { tally.record(letter: 1, isInside: true) }    // traced again, well
        #expect(tally.letterAccuracies[1] == 1.0)
    }

    @Test("Finish message names skipped letters, and celebrates a finished page")
    func finishMessage() {
        var whole = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        whole.record(letter: 0, isInside: true); whole.record(letter: 1, isInside: true)
        #expect(ScoringEngine.finishMessage(for: ScoringEngine.score(tally: whole, streak: 0))
                    .contains("whole thing"))

        var skipped = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        skipped.record(letter: 0, isInside: true)
        #expect(ScoringEngine.finishMessage(for: ScoringEngine.score(tally: skipped, streak: 0))
                    .contains("2 letters were skipped"))
    }
}
