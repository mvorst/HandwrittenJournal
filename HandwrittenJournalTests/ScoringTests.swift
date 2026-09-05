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

    // MARK: - §8.3 (v3.5) — points scale with the writing

    /// A perfectly inked tally for `wordOf`, every letter drawn the way it is taught.
    private func perfect(wordOf: [Int], alphanumeric: [Bool]? = nil, words: Int) -> ScoringEngine.Tally {
        var tally = ScoringEngine.Tally(wordOfLetter: wordOf, alphanumeric: alphanumeric, totalWords: words)
        for letter in wordOf.indices {
            for _ in 0..<10 { tally.record(letter: letter, isInside: true) }
        }
        return tally
    }

    @Test("A letter earns two points above 90%, one from 50%, nothing below")
    func letterPoints() {
        #expect(ScoringEngine.letterPoints(forAccuracy: 1.0) == 2)
        #expect(ScoringEngine.letterPoints(forAccuracy: 0.91) == 2)
        #expect(ScoringEngine.letterPoints(forAccuracy: 0.9) == 1, "exactly 90% is not above it")
        #expect(ScoringEngine.letterPoints(forAccuracy: 0.5) == 1)
        #expect(ScoringEngine.letterPoints(forAccuracy: 0.49) == 0)
        #expect(ScoringEngine.letterPoints(forAccuracy: 0) == 0)
    }

    @Test("The worked example: \"I saw a red bird\", perfectly, on a five-day streak, is 127")
    func workedExample() {
        // I · saw · a · red · bird — 12 letters in five words, three of them whole words.
        let wordOf = [0, 1, 1, 1, 2, 3, 3, 3, 4, 4, 4, 4]
        let result = ScoringEngine.score(tally: perfect(wordOf: wordOf, words: 5), streak: 5)
        #expect(result.lettersWritten == 12)
        #expect(result.letterPoints == 24)
        #expect(result.completedWords == 3)
        #expect(result.wordPoints == 9)
        #expect(result.orderedWords == 3)
        #expect(result.orderPoints == 9)
        #expect(result.stars == 3)
        #expect(result.starBonus == 30)
        #expect(result.streakBonus == 25)
        #expect(result.sessionBonus == 30)
        #expect(result.totalPoints == 127)
        #expect(result.breakdownAddsUp)
        #expect(ScoringEngine.breakdown(for: result)
                == "12 letters +24 · 3 whole words +9 · 3 in order +9 · ★★★ +30 · streak +25 · finished +30")
    }

    @Test("A page of writing is worth more than a single letter")
    func pointsScaleWithTheWriting() {
        var one = ScoringEngine.Tally(wordOfLetter: [0], totalWords: 1)
        for _ in 0..<10 { one.record(letter: 0, isInside: true) }
        let single = ScoringEngine.score(tally: one, streak: 0)
        #expect(single.totalPoints == 2 + 30 + 30, "one letter, three stars, the finish — no word bonus")

        let wordOf = (0..<120).map { $0 / 4 }     // thirty four-letter words
        let page = ScoringEngine.score(tally: perfect(wordOf: wordOf, words: 30), streak: 0)
        #expect(page.letterPoints == 240)
        #expect(page.wordPoints == 90)
        #expect(page.orderPoints == 90)
        #expect(page.totalPoints == 240 + 90 + 90 + 30 + 30)
    }

    @Test("The word bonus needs every letter inked and three letters or more")
    func wordBonusRules() {
        // "cat" with its last letter skipped is not a whole word.
        var skipped = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        for letter in 0..<2 {
            for _ in 0..<10 { skipped.record(letter: letter, isInside: true) }
        }
        let cut = ScoringEngine.score(tally: skipped, streak: 0)
        #expect(cut.completedWords == 0)
        #expect(cut.orderedWords == 0)
        #expect(cut.wordPoints == 0)

        // "an." — three glyphs, two of them letters. Punctuation is traced and scored like
        // any glyph; it just does not make a word.
        let dotted = ScoringEngine.score(tally: perfect(wordOf: [0, 0, 0], alphanumeric: [true, true, false], words: 1),
                                         streak: 0)
        #expect(dotted.lettersWritten == 3)
        #expect(dotted.letterPoints == 6)
        #expect(dotted.completedWords == 0)

        // "2026" — digits make a word.
        let year = ScoringEngine.score(tally: perfect(wordOf: [0, 0, 0, 0], words: 1), streak: 0)
        #expect(year.completedWords == 1)
        #expect(year.wordPoints == 3)
    }

    @Test("The order bonus is per whole word, and one letter out of order forfeits it")
    func orderBonus() {
        // Two whole words; one letter of the second was drawn the wrong way round.
        var tally = perfect(wordOf: [0, 0, 0, 1, 1, 1], words: 2)
        tally.markOrder(letter: 4, followed: false)
        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(result.completedWords == 2)
        #expect(result.orderedWords == 1)
        #expect(result.orderPoints == 3)
        #expect(result.outOfOrderLetters == 1)
        // The discount still flows into the letter's own points: 100% × 0.8 is one point, not two.
        #expect(result.letterPoints == 5 * 2 + 1)
        #expect(abs(result.accuracy - (5 + 0.8) / 6) < 0.0001)
    }

    @Test("\"I\" and \"a\" earn their letter's points and nothing more")
    func shortWordsEarnLettersOnly() {
        let result = ScoringEngine.score(tally: perfect(wordOf: [0, 1], words: 2), streak: 0)
        #expect(result.completedWords == 0)
        #expect(result.orderedWords == 0)
        #expect(result.letterPoints == 4)
    }

    @Test("Stars pay ten each and the finish thirty; a carried-over score has no breakdown")
    func flatBonuses() {
        let result = ScoringEngine.score(tally: perfect(wordOf: [0, 0, 0], words: 1), streak: 2)
        #expect(result.starBonus == 30)
        #expect(result.streakBonus == 10)
        #expect(result.sessionBonus == 30)
        #expect(result.totalPoints == 6 + 3 + 3 + 30 + 10 + 30)

        let kept = result.keeping(points: 224, stars: 2)
        #expect(kept.totalPoints == 224)
        #expect(kept.stars == 2)
        #expect(!kept.breakdownAddsUp)
        #expect(ScoringEngine.breakdown(for: kept) == nil)
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

    @Test("v2.5 — the committed score covers exactly the record")
    func committedScoreCoversTheRecord() {
        // Two words of three letters, then a third word the child never wrote. The first
        // two words' lines are committed; the third is spoken and outside the population.
        let wordOf = [0, 0, 0, 1, 1, 1, 2, 2, 2]
        var tally = ScoringEngine.Tally(wordOfLetter: wordOf, totalWords: 3)
        for letter in 0..<5 {                    // five of six committed letters inked
            for i in 0..<10 { tally.record(letter: letter, isInside: i < 8) }
        }
        let committed = [true, true, true, true, true, true, false, false, false]
        let result = ScoringEngine.score(tally: tally, committed: committed, totalWords: 3, streak: 0)

        #expect(result.wordsWritten == 2)
        #expect(result.totalWords == 3)
        #expect(result.wordsRemaining == 1)
        #expect(result.unfinishedLetters == 1, "the skipped letter on a committed line counts")
        // five letters at 80% plus one at zero, over six committed letters
        #expect(abs(result.accuracy - (5.0 * 0.8) / 6.0) < 0.0001)
        #expect(!result.finishedEverything)
    }

    @Test("v2.5 — an empty record scores nothing and earns nothing")
    func emptyRecordScoresNothing() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 1, 1], totalWords: 2)
        tally.record(letter: 0, isInside: true)   // ink in hand, but nothing committed
        let result = ScoringEngine.score(tally: tally,
                                         committed: [false, false, false, false],
                                         totalWords: 2, streak: 5)
        #expect(result.wordsWritten == 0)
        #expect(result.accuracy == 0)
        #expect(result.totalPoints == 0, "no record, no points — not even bonuses")
    }

    @Test("Finish message names incomplete letters, and celebrates a finished page")
    func finishMessage() {
        var whole = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        whole.record(letter: 0, isInside: true); whole.record(letter: 1, isInside: true)
        #expect(ScoringEngine.finishMessage(for: ScoringEngine.score(tally: whole, streak: 0))
                    .contains("everything you said"))

        var skipped = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        skipped.record(letter: 0, isInside: true)
        #expect(ScoringEngine.finishMessage(for: ScoringEngine.score(tally: skipped, streak: 0))
                    .contains("2 letters were incomplete"))
    }
}

/// Spatial accuracy measures the drawn path and the distinct letter parts reached.
/// The older tests above intentionally exercise count-only aggregation without geometry.
struct SpatialTallyScoringTests {

    @Test("Tiny inside marks attempt a word without completing it or earning letter points")
    func tinyMarksCannotCompleteWord() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        let tiny = LetterTraceMetrics(containment: 1, coverage: 0.01, isComplete: false)
        for index in 0..<3 {
            tally.record(letter: index, isInside: true)
            tally.recordGeometry(letter: index, metrics: tiny)
        }

        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(tally.startedCount == 3)
        #expect(tally.unfinishedCount == 3)
        #expect(tally.hasInk(letter: 0))
        #expect(!tally.isComplete(letter: 0))
        #expect(tally.liveAccuracy == 1)
        #expect(abs(result.accuracy - tiny.accuracy) < 0.0001)
        #expect(result.lettersWritten == 3)
        #expect(result.unfinishedLetters == 3)
        #expect(!result.finishedEverything)
        #expect(result.letterPoints == 0)
        #expect(result.completedWords == 0)
        #expect(result.wordPoints == 0)
        #expect(result.orderPoints == 0)
        #expect(result.stars == 0)
        #expect(result.sessionBonus == ScoringEngine.sessionBonus,
                "Shape completion must not change the existing reward for ending a session")
        #expect(ScoringEngine.finishMessage(for: result).contains("3 letters were incomplete"))
    }

    @Test("Live feedback uses containment while final accuracy also measures coverage")
    func liveFeedbackDoesNotPenalizeWorkInProgress() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        let partial = LetterTraceMetrics(containment: 0.8, coverage: 0.4, isComplete: false)
        tally.recordGeometry(letter: 0, metrics: partial)

        #expect(tally.letterContainments == [0.8, 0])
        #expect(tally.letterCoverages == [0.4, 0])
        #expect(tally.liveAccuracy == 0.8)
        #expect(abs(tally.finalAccuracy - partial.accuracy / 2) < 0.0001)
        #expect(tally.unfinishedCount == 2)

        tally.markOrder(letter: 0, followed: false)
        #expect(abs(tally.liveAccuracy - 0.8 * ScoringEngine.orderDiscount) < 0.0001)
        #expect(abs(tally.letterAccuracies[0] - partial.accuracy * ScoringEngine.orderDiscount) < 0.0001)
    }

    @Test("Geometry can assign outside ink without inventing legacy sample counts")
    func geometryOnlyAttemptsAndEmptyResults() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 1], totalWords: 2)
        tally.recordGeometry(letter: 0,
                             metrics: LetterTraceMetrics(containment: 0, coverage: 0, isComplete: false))
        tally.recordGeometry(letter: 1, metrics: .empty)
        tally.recordGeometry(letter: 2, metrics: .empty)

        #expect(tally.total == [0, 0, 0])
        #expect(tally.inside == [0, 0, 0])
        #expect(tally.hasInk(letter: 0))
        #expect(!tally.hasInk(letter: 1))
        #expect(tally.startedCount == 1)
        #expect(tally.startedWords == Set([0]))
        #expect(tally.scoredIndices == [0, 1])
        #expect(tally.unfinishedCount == 2)
        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(result.lettersWritten == 1)
        #expect(result.wordsWritten == 1)
        #expect(result.accuracy == 0)
    }

    @Test("A complete letter keeps its completion even when its formation order is wrong")
    func shapeCompletionAndOrderAreIndependent() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        for index in 0..<3 {
            tally.recordGeometry(letter: index,
                                 metrics: LetterTraceMetrics(containment: 1, coverage: 1, isComplete: true))
        }
        tally.markOrder(letter: 1, followed: false)

        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(tally.isComplete(letter: 1))
        #expect(result.unfinishedLetters == 0)
        #expect(result.finishedEverything)
        #expect(result.letterAccuracies == [1, ScoringEngine.orderDiscount, 1])
        #expect(result.letterPoints == 5)
        #expect(result.completedWords == 1)
        #expect(result.wordPoints == ScoringEngine.wordBonus)
        #expect(result.orderedWords == 0)
        #expect(result.orderPoints == 0)
        #expect(result.outOfOrderLetters == 1)
    }

    @Test("Missing a required part cannot earn full letter points or a word bonus")
    func incompleteEssentialPartBlocksFullCredit() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 0], totalWords: 1)
        for index in 0..<3 {
            tally.recordGeometry(letter: index,
                                 metrics: LetterTraceMetrics(containment: 1, coverage: 1, isComplete: true))
        }
        tally.recordGeometry(letter: 1,
                             metrics: LetterTraceMetrics(containment: 1, coverage: 0.99, isComplete: false))
        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(result.letterAccuracies[1] < ScoringEngine.fullLetterAbove)
        #expect(result.letterPoints == 5)
        #expect(result.unfinishedLetters == 1)
        #expect(result.completedWords == 0)
        #expect(!result.finishedEverything)
    }

    @Test("Erasing resets geometry, attempts and formation-order verdicts")
    func resetsClearSpatialMetrics() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0], totalWords: 1)
        for index in 0..<2 {
            tally.record(letter: index, isInside: true)
            tally.recordGeometry(letter: index,
                                 metrics: LetterTraceMetrics(containment: 0.8, coverage: 0.4, isComplete: false))
            tally.markOrder(letter: index, followed: false)
        }
        tally.reset(letter: 0)
        #expect(tally.geometry[0] == nil)
        #expect(!tally.hasInk(letter: 0))
        #expect(!tally.isComplete(letter: 0))
        #expect(tally.followedOrder[0])
        #expect(tally.letterAccuracies[0] == 0)
        #expect(tally.hasInk(letter: 1))

        tally.resetAll()
        #expect(tally.geometry.allSatisfy { $0 == nil })
        #expect(tally.total == [0, 0])
        #expect(tally.inside == [0, 0])
        #expect(tally.followedOrder == [true, true])
        #expect(tally.startedWords.isEmpty)
        #expect(tally.liveAccuracy == 0)
        #expect(tally.finalAccuracy == 0)

        // Callers without spatial inputs still receive the documented legacy fallback.
        tally.record(letter: 0, isInside: true)
        #expect(tally.isComplete(letter: 0))
        #expect(tally.letterAccuracies[0] == 1)
    }

    @Test("Spatial metrics preserve the committed record as the scored population")
    func geometryDoesNotChangeCommittedPopulation() {
        var tally = ScoringEngine.Tally(wordOfLetter: [0, 0, 1], totalWords: 2)
        tally.recordGeometry(letter: 0,
                             metrics: LetterTraceMetrics(containment: 1, coverage: 1, isComplete: true))
        let partial = LetterTraceMetrics(containment: 1, coverage: 0.25, isComplete: false)
        tally.recordGeometry(letter: 1, metrics: partial)
        tally.recordGeometry(letter: 2,
                             metrics: LetterTraceMetrics(containment: 0, coverage: 0, isComplete: false))

        let result = ScoringEngine.score(tally: tally, committed: [true, true, false], totalWords: 2, streak: 0)
        #expect(result.wordsWritten == 1)
        #expect(result.wordsRemaining == 1)
        #expect(result.lettersWritten == 2)
        #expect(result.unfinishedLetters == 1)
        #expect(abs(result.accuracy - (1 + partial.accuracy) / 2) < 0.0001)
    }
}
