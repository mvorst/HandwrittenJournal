import Foundation
import CoreGraphics

struct ScoreResult {
    let accuracy: Double            // 0…1, mean over letters in words the child started
    let letterAccuracies: [Double]
    let unfinishedLetters: Int      // letters skipped *inside* words that were started
    let wordsWritten: Int
    let totalWords: Int
    let stars: Int
    let basePoints: Int
    let starBonus: Int
    let streakBonus: Int
    let sessionBonus: Int
    let totalPoints: Int

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }
    var everyLetterFinished: Bool { unfinishedLetters == 0 }
    var wordsRemaining: Int { max(0, totalWords - wordsWritten) }
    var finishedEverything: Bool { totalWords > 0 && wordsWritten >= totalWords }
}

/// DESIGN_DOCUMENT.md §8.1 — accuracy is graded per letter.
///
/// v2.5: **the scored population is the record** — every scorable letter on a line the
/// child finished. Words they never wrote are not in the record at all, so there is
/// nothing to score and nothing to excuse; stopping part-way stays ordinary by
/// construction. Inside a line they *did* finish, a skipped letter still scores zero —
/// finishing a line is a choice, not a certificate, and that anti-skip property is what
/// made per-letter grading worth doing in the first place.
///
/// The older started-words rule (`score(tally:streak:)`) survives for the live figure and
/// its tests; the app's final score goes through `score(tally:committed:...)`.
enum ScoringEngine {

    static let sessionBonus = 30
    static let starValue = 25
    static let streakStep = 5
    static let streakCap = 5

    // MARK: - Tally

    struct Tally {
        /// Word index for each glyph, parallel to `inside` / `total`.
        private(set) var wordOfLetter: [Int]
        /// Whether each glyph is a letter the child is expected to write. The arrays are
        /// indexed by glyph, and a glyph can be a space — which is never written and so
        /// must never be counted as one they skipped.
        private(set) var scorable: [Bool]
        private(set) var inside: [Int]
        private(set) var total: [Int]
        let totalWords: Int

        init(wordOfLetter: [Int], scorable: [Bool]? = nil, totalWords: Int) {
            self.wordOfLetter = wordOfLetter
            self.scorable = scorable ?? Array(repeating: true, count: wordOfLetter.count)
            self.totalWords = totalWords
            inside = Array(repeating: 0, count: wordOfLetter.count)
            total  = Array(repeating: 0, count: wordOfLetter.count)
        }

        init(letterCount: Int) {
            self.init(wordOfLetter: Array(0..<letterCount), totalWords: letterCount)
        }

        /// Whether this glyph has any ink on it — what decides when a line is finished.
        func hasInk(letter index: Int) -> Bool {
            index >= 0 && index < total.count && total[index] > 0
        }

        mutating func record(letter index: Int, isInside: Bool) {
            guard index >= 0, index < total.count else { return }
            total[index] += 1
            if isInside { inside[index] += 1 }
        }

        mutating func reset(letter index: Int) {
            guard index >= 0, index < total.count else { return }
            total[index] = 0
            inside[index] = 0
        }

        mutating func resetAll() {
            for i in total.indices { total[i] = 0; inside[i] = 0 }
        }

        /// Words with any ink at all.
        var startedWords: Set<Int> {
            var set: Set<Int> = []
            for (i, count) in total.enumerated() where count > 0 {
                if i < wordOfLetter.count { set.insert(wordOfLetter[i]) }
            }
            return set
        }

        var wordsWritten: Int { startedWords.count }

        /// Letters belonging to words the child has started — the scored population.
        /// Spaces are excluded: nobody writes a space, so counting one as unfinished
        /// would dock a perfectly written page a few percent for nothing.
        private var scoredIndices: [Int] {
            let started = startedWords
            return wordOfLetter.indices.filter { scorable[$0] && started.contains(wordOfLetter[$0]) }
        }

        var startedCount: Int { total.filter { $0 > 0 }.count }

        /// Letters skipped inside words that were started.
        var unfinishedCount: Int { scoredIndices.filter { total[$0] == 0 }.count }

        var letterAccuracies: [Double] {
            zip(inside, total).map { i, t in t > 0 ? Double(i) / Double(t) : 0 }
        }

        /// The number shown at Done.
        var finalAccuracy: Double {
            let scored = scoredIndices
            guard !scored.isEmpty else { return 0 }
            let accuracies = letterAccuracies
            return scored.reduce(0.0) { $0 + accuracies[$1] } / Double(scored.count)
        }

        /// The number shown *while writing*: only letters actually attempted.
        ///
        /// If the live figure applied the skip-penalty it would lurch downward every time
        /// the child moved to a new letter, which reads as being punished for progress.
        var liveAccuracy: Double {
            let started = zip(inside, total).filter { $0.1 > 0 }
            guard !started.isEmpty else { return 0 }
            return started.reduce(0.0) { $0 + Double($1.0) / Double($1.1) } / Double(started.count)
        }
    }

    // MARK: - Stars and points

    static func stars(forAccuracy accuracy: Double) -> Int {
        let percent = accuracy * 100
        if percent >= 90 { return 3 }
        if percent >= 75 { return 2 }
        if percent >= 60 { return 1 }
        return 0
    }

    /// v2.5 — score the record. `committed` is per glyph, true when the glyph sits on a
    /// line the child finished. Untouched committed letters score zero; uncommitted
    /// glyphs are simply not in the population.
    static func score(tally: Tally, committed: [Bool], totalWords: Int, streak: Int) -> ScoreResult {
        let accuracies = tally.letterAccuracies
        var sum = 0.0, count = 0, unfinished = 0
        var writtenWords: Set<Int> = []
        for i in tally.wordOfLetter.indices where i < committed.count && committed[i] && tally.scorable[i] {
            sum += accuracies[i]
            count += 1
            if !tally.hasInk(letter: i) { unfinished += 1 }
            writtenWords.insert(tally.wordOfLetter[i])
        }
        let accuracy = count > 0 ? sum / Double(count) : 0
        let stars = stars(forAccuracy: accuracy)
        let base = Int((accuracy * 100).rounded())
        let starBonus = count > 0 ? stars * starValue : 0
        let streakBonus = count > 0 ? min(streak, streakCap) * streakStep : 0
        return ScoreResult(
            accuracy: accuracy,
            letterAccuracies: accuracies,
            unfinishedLetters: unfinished,
            wordsWritten: writtenWords.count,
            totalWords: totalWords,
            stars: stars,
            basePoints: base,
            starBonus: starBonus,
            streakBonus: streakBonus,
            sessionBonus: count > 0 ? sessionBonus : 0,
            totalPoints: count > 0 ? base + starBonus + streakBonus + sessionBonus : 0
        )
    }

    /// §8.3. Worked from §14: 78 + 50 + 25 + 30 = 183; 94 + 75 + 25 + 30 = 224.
    static func score(tally: Tally, streak: Int) -> ScoreResult {
        let accuracy = tally.finalAccuracy
        let stars = stars(forAccuracy: accuracy)
        let base = Int((accuracy * 100).rounded())
        let starBonus = stars * starValue
        let streakBonus = min(streak, streakCap) * streakStep
        return ScoreResult(
            accuracy: accuracy,
            letterAccuracies: tally.letterAccuracies,
            unfinishedLetters: tally.unfinishedCount,
            wordsWritten: tally.wordsWritten,
            totalWords: tally.totalWords,
            stars: stars,
            basePoints: base,
            starBonus: starBonus,
            streakBonus: streakBonus,
            sessionBonus: sessionBonus,
            totalPoints: base + starBonus + streakBonus + sessionBonus
        )
    }

    /// Copy shown on Reveal.
    static func finishMessage(for result: ScoreResult) -> String {
        if result.unfinishedLetters > 0 {
            return result.unfinishedLetters == 1
                ? "1 letter was skipped."
                : "\(result.unfinishedLetters) letters were skipped."
        }
        if result.finishedEverything { return "You wrote everything you said — nice work." }
        return "Every letter you wrote was finished."
    }
}
