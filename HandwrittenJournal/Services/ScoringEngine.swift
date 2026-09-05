import Foundation
import CoreGraphics

struct ScoreResult {
    let accuracy: Double            // 0…1, mean over letters in words the child started
    let letterAccuracies: [Double]
    let unfinishedLetters: Int      // letters skipped or incomplete in the scored population
    let outOfOrderLetters: Int      // inked letters that took the order discount (§8.1a)
    let wordsWritten: Int
    let totalWords: Int
    private(set) var stars: Int

    // §8.3 (v3.5) — what the entry earned, piece by piece.
    let lettersWritten: Int         // inked letters in the record
    let letterPoints: Int           // 0, 1 or 2 per inked letter, by its accuracy
    let completedWords: Int         // words of three letters or more with every letter complete
    let wordPoints: Int
    let orderedWords: Int           // completed words whose every letter followed its formation
    let orderPoints: Int
    let starBonus: Int
    let streakBonus: Int
    let sessionBonus: Int
    private(set) var totalPoints: Int

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }
    var everyLetterFinished: Bool { unfinishedLetters == 0 }
    var wordsRemaining: Int { max(0, totalWords - wordsWritten) }
    var finishedEverything: Bool {
        totalWords > 0 && wordsWritten >= totalWords && everyLetterFinished
    }

    /// Whether the pieces add up to the total. They do not for a score carried over from
    /// an earlier sitting (§8.3), and the breakdown line then has nothing honest to say.
    var breakdownAddsUp: Bool {
        letterPoints + wordPoints + orderPoints + starBonus + streakBonus + sessionBonus == totalPoints
    }

    /// The same page scored again with nothing on it changed: the entry keeps the score
    /// it already has (§8.3, v3.5).
    func keeping(points: Int, stars: Int) -> ScoreResult {
        var kept = self
        kept.totalPoints = points
        kept.stars = stars
        return kept
    }
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
/// §8.3 (v3.5): **points scale with the writing.** Every inked letter earns up to two by
/// its accuracy, every whole word of three letters or more earns three, and three more
/// when each of its letters was drawn the way the practice sheet teaches — so a page of
/// writing is worth more than a single letter, which the old flat formula could not say.
/// The stars, the streak and finishing still pay a little on top.
///
/// The older started-words rule (`score(tally:streak:)`) survives for the live figure and
/// its tests; the app's final score goes through `score(tally:committed:...)`.
enum ScoringEngine {

    /// The most an inked letter earns: two at better than 90%, one from 50%, nothing
    /// below that.
    static let letterValue = 2
    static let fullLetterAbove = 0.9
    static let halfLetterFrom = 0.5
    /// A whole word — every letter complete — of at least this many letters (digits count,
    /// punctuation does not) earns `wordBonus`…
    static let wordBonus = 3
    static let wordMinimumLetters = 3
    /// …and `orderBonus` more when every letter in it followed its formation (§8.1a).
    static let orderBonus = 3
    static let starValue = 10
    static let streakStep = 5
    static let streakCap = 5
    static let sessionBonus = 30

    /// §8.1a — a letter clearly drawn against its taught formation (parts out of the
    /// demonstrated order, or a part drawn against its demonstrated direction) keeps
    /// only this fraction of its score: the 20% order discount. It flows through
    /// everything derived from a letter's accuracy, its points included — a letter drawn
    /// the wrong way round can earn one point, never two.
    static let orderDiscount = 0.8

    /// §8.3 — what one inked letter is worth, by its (discounted) accuracy.
    static func letterPoints(forAccuracy accuracy: Double) -> Int {
        if accuracy > fullLetterAbove { return letterValue }
        if accuracy >= halfLetterFrom { return 1 }
        return 0
    }

    // MARK: - Tally

    struct Tally {
        /// Word index for each glyph, parallel to `inside` / `total`.
        private(set) var wordOfLetter: [Int]
        /// Whether each glyph is a letter the child is expected to write. The arrays are
        /// indexed by glyph, and a glyph can be a space — which is never written and so
        /// must never be counted as one they skipped.
        private(set) var scorable: [Bool]
        /// Whether each glyph is a letter or a digit — what counts towards a word's
        /// three letters (§8.3). Punctuation is traced and scored, but "an." is not a
        /// three-letter word.
        private(set) var alphanumeric: [Bool]
        private(set) var inside: [Int]
        private(set) var total: [Int]
        /// Spatial measurements replace sample-count accuracy when the canvas provides
        /// them. The count-only fallback remains for callers with no stroke geometry.
        private(set) var geometry: [LetterTraceMetrics?]
        /// Per glyph, false when the ink took the letter's parts out of the taught
        /// order or direction (§8.1a). True by default — only a clear violation docks.
        private(set) var followedOrder: [Bool]
        let totalWords: Int

        init(wordOfLetter: [Int], scorable: [Bool]? = nil, alphanumeric: [Bool]? = nil,
             totalWords: Int) {
            self.wordOfLetter = wordOfLetter
            self.scorable = scorable ?? Array(repeating: true, count: wordOfLetter.count)
            self.alphanumeric = alphanumeric ?? self.scorable
            self.totalWords = totalWords
            inside = Array(repeating: 0, count: wordOfLetter.count)
            total  = Array(repeating: 0, count: wordOfLetter.count)
            geometry = Array(repeating: nil, count: wordOfLetter.count)
            followedOrder = Array(repeating: true, count: wordOfLetter.count)
        }

        init(letterCount: Int) {
            self.init(wordOfLetter: Array(0..<letterCount), totalWords: letterCount)
        }

        /// Whether this glyph was attempted, including ink assigned by the spatial
        /// scorer that was too far from a glyph to receive a legacy touch-sample index.
        func hasInk(letter index: Int) -> Bool {
            guard index >= 0, index < total.count else { return false }
            return geometry[index]?.hasInk ?? (total[index] > 0)
        }

        /// Actual shape completion, independent of the formation-order discount.
        /// A count-only caller has no coverage evidence and retains the legacy rule.
        func isComplete(letter index: Int) -> Bool {
            guard hasInk(letter: index) else { return false }
            return geometry[index]?.isComplete ?? true
        }

        /// Legacy sample aggregation. Production canvases also provide spatial metrics
        /// using `recordGeometry`, so a tiny inside mark cannot earn full accuracy.
        mutating func record(letter index: Int, isInside: Bool) {
            guard index >= 0, index < total.count else { return }
            total[index] += 1
            if isInside { inside[index] += 1 }
        }

        mutating func recordGeometry(letter index: Int, metrics: LetterTraceMetrics) {
            guard index >= 0, index < geometry.count else { return }
            geometry[index] = metrics
        }

        /// §8.1a — the canvas judges each letter's ink against its formation and
        /// records the verdict here; `letterAccuracies` applies the discount.
        mutating func markOrder(letter index: Int, followed: Bool) {
            guard index >= 0, index < followedOrder.count else { return }
            followedOrder[index] = followed
        }

        mutating func reset(letter index: Int) {
            guard index >= 0, index < total.count else { return }
            total[index] = 0
            inside[index] = 0
            geometry[index] = nil
            followedOrder[index] = true
        }

        mutating func resetAll() {
            for i in total.indices {
                total[i] = 0
                inside[i] = 0
                geometry[i] = nil
                followedOrder[i] = true
            }
        }

        /// Words with any ink at all.
        var startedWords: Set<Int> {
            var set: Set<Int> = []
            for i in total.indices where hasInk(letter: i) {
                if i < wordOfLetter.count { set.insert(wordOfLetter[i]) }
            }
            return set
        }

        var wordsWritten: Int { startedWords.count }

        /// Letters belonging to words the child has started — the scored population.
        /// Spaces are excluded: nobody writes a space, so counting one as unfinished
        /// would dock a perfectly written page a few percent for nothing.
        var scoredIndices: [Int] {
            let started = startedWords
            return wordOfLetter.indices.filter { scorable[$0] && started.contains(wordOfLetter[$0]) }
        }

        var startedCount: Int { total.indices.filter { hasInk(letter: $0) }.count }

        /// Letters skipped or incomplete inside words that were started.
        var unfinishedCount: Int { scoredIndices.filter { !isComplete(letter: $0) }.count }

        /// Inked letters in the scored population that took the order discount.
        var outOfOrderCount: Int {
            scoredIndices.filter { hasInk(letter: $0) && !followedOrder[$0] }.count
        }

        /// Containment and coverage are kept separate so live feedback can report how
        /// well the pen stays in the letter while the child is still tracing it.
        var letterContainments: [Double] {
            total.indices.map { i in
                guard hasInk(letter: i) else { return 0 }
                return geometry[i]?.containment ?? Double(inside[i]) / Double(total[i])
            }
        }

        var letterCoverages: [Double] {
            total.indices.map { i in
                guard hasInk(letter: i) else { return 0 }
                return geometry[i]?.coverage ?? 1
            }
        }

        /// Final per-letter shape accuracy, with the formation-order discount applied.
        var letterAccuracies: [Double] {
            total.indices.map { i in
                guard hasInk(letter: i) else { return 0 }
                let raw = geometry[i]?.accuracy ?? Double(inside[i]) / Double(total[i])
                return followedOrder[i] ? raw : raw * ScoringEngine.orderDiscount
            }
        }

        /// The number shown at Done.
        var finalAccuracy: Double {
            let scored = scoredIndices
            guard !scored.isEmpty else { return 0 }
            let accuracies = letterAccuracies
            return scored.reduce(0.0) { $0 + accuracies[$1] } / Double(scored.count)
        }

        /// The number shown *while writing*: containment of letters actually attempted.
        ///
        /// If the live figure applied the skip-penalty it would lurch downward every time
        /// the child moved to a new letter, which reads as being punished for progress.
        /// Coverage is also left out until final scoring, while the trace is in progress.
        var liveAccuracy: Double {
            let attempted = total.indices.filter { hasInk(letter: $0) }
            guard !attempted.isEmpty else { return 0 }
            let containments = letterContainments
            return attempted.reduce(0.0) { sum, index in
                sum + containments[index] * (followedOrder[index] ? 1 : ScoringEngine.orderDiscount)
            } / Double(attempted.count)
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
        let population = tally.wordOfLetter.indices.filter {
            $0 < committed.count && committed[$0] && tally.scorable[$0]
        }
        return score(tally: tally, population: population, totalWords: totalWords, streak: streak)
    }

    /// The started-words rule: every scorable letter of every word with any ink.
    static func score(tally: Tally, streak: Int) -> ScoreResult {
        score(tally: tally, population: tally.scoredIndices, totalWords: tally.totalWords, streak: streak)
    }

    /// §8.3. Worked example: *"I saw a red bird"* traced perfectly, every letter the way
    /// it is taught, on a five-day streak — 12 letters × 2 + 3 whole words × 3 + 3 in
    /// order × 3 + 3 stars × 10 + 25 + 30 = **127**.
    private static func score(tally: Tally, population: [Int], totalWords: Int, streak: Int) -> ScoreResult {
        let accuracies = tally.letterAccuracies
        var sum = 0.0, unfinished = 0, outOfOrder = 0, written = 0, letterPoints = 0
        var glyphsOfWord: [Int: [Int]] = [:]
        for i in population {
            sum += accuracies[i]
            glyphsOfWord[tally.wordOfLetter[i], default: []].append(i)
            if tally.hasInk(letter: i) {
                written += 1
                letterPoints += self.letterPoints(forAccuracy: accuracies[i])
                if !tally.followedOrder[i] { outOfOrder += 1 }
            }
            if !tally.isComplete(letter: i) { unfinished += 1 }
        }
        // A whole word: every letter complete, three or more of them letters or digits. The
        // order bonus is only ever paid on top of the word bonus — "I" and "a" earn their
        // letter's points and nothing more.
        var completed = 0, ordered = 0
        for glyphs in glyphsOfWord.values {
            guard glyphs.allSatisfy({ tally.isComplete(letter: $0) }),
                  glyphs.filter({ tally.alphanumeric[$0] }).count >= wordMinimumLetters else { continue }
            completed += 1
            if glyphs.allSatisfy({ tally.followedOrder[$0] }) { ordered += 1 }
        }
        let count = population.count
        let accuracy = count > 0 ? sum / Double(count) : 0
        let stars = stars(forAccuracy: accuracy)
        let wordPoints = completed * wordBonus
        let orderPoints = ordered * orderBonus
        let starBonus = count > 0 ? stars * starValue : 0
        let streakBonus = count > 0 ? min(streak, streakCap) * streakStep : 0
        let session = count > 0 ? sessionBonus : 0
        return ScoreResult(
            accuracy: accuracy,
            letterAccuracies: accuracies,
            unfinishedLetters: unfinished,
            outOfOrderLetters: outOfOrder,
            wordsWritten: glyphsOfWord.count,
            totalWords: totalWords,
            stars: stars,
            lettersWritten: written,
            letterPoints: letterPoints,
            completedWords: completed,
            wordPoints: wordPoints,
            orderedWords: ordered,
            orderPoints: orderPoints,
            starBonus: starBonus,
            streakBonus: streakBonus,
            sessionBonus: session,
            totalPoints: letterPoints + wordPoints + orderPoints + starBonus + streakBonus + session
        )
    }

    /// Copy shown on Reveal.
    static func finishMessage(for result: ScoreResult) -> String {
        // The singular forms ("1 letter was incomplete.") are the catalog's plural variants.
        if result.unfinishedLetters > 0 {
            return String(localized: "\(result.unfinishedLetters) letters were incomplete.")
        }
        if result.outOfOrderLetters > 0 {
            return String(localized: "\(result.outOfOrderLetters) letters were drawn in a different order — the practice page shows the way.")
        }
        if result.finishedEverything { return String(localized: "You wrote everything you said — nice work.") }
        return String(localized: "Every letter you wrote was finished.")
    }

    /// The line under the points on Reveal (v3.5): what the score is made of, so the
    /// total is checkable — *12 letters +24 · 3 whole words +9 · 3 in order +9 · ★★★ +30 ·
    /// streak +25 · finished +30*. Nil when the pieces do not add up to the total, which
    /// is a score carried over unchanged from an earlier sitting.
    static func breakdown(for result: ScoreResult) -> String? {
        guard result.breakdownAddsUp, result.lettersWritten > 0 else { return nil }
        var parts = [result.lettersWritten == 1
            ? String(localized: "1 letter +\(result.letterPoints)")
            : String(localized: "\(result.lettersWritten) letters +\(result.letterPoints)")]
        if result.completedWords > 0 {
            parts.append(result.completedWords == 1
                ? String(localized: "1 whole word +\(result.wordPoints)")
                : String(localized: "\(result.completedWords) whole words +\(result.wordPoints)"))
        }
        if result.orderedWords > 0 {
            parts.append(String(localized: "\(result.orderedWords) in order +\(result.orderPoints)"))
        }
        if result.stars > 0 {
            parts.append(String(localized: "\(String(repeating: "★", count: result.stars)) +\(result.starBonus)"))
        }
        if result.streakBonus > 0 { parts.append(String(localized: "streak +\(result.streakBonus)")) }
        if result.sessionBonus > 0 { parts.append(String(localized: "finished +\(result.sessionBonus)")) }
        return parts.joined(separator: " · ")
    }
}
