import Testing
import UIKit
@testable import HandwrittenJournal

/// WIREFRAME_SPEC.md §11.11 — every line of the page is graded, in hand, or untraced.
///
/// The rendering and the tap target both hang off line identity, and appending new
/// dictation to a page that is already part-written hangs off word wrap being
/// prefix-stable. Both are asserted here because both are silent when they break: the
/// page would simply render the wrong lines as handwriting, or move a child's ink off
/// the letters they drew it on.
struct LineStateTests {

    static let surfaceWidth: CGFloat = 754
    static let canvasWidth: CGFloat = 834
    static let transcript = "Today we went to the park and I saw a big dog. The dog wanted to "
        + "play with me and we threw a ball for it until it got tired."

    private func layout(_ text: String,
                        setup: WritingSetup = .default) -> MaskRenderer.Layout {
        FontRegistry.registerBundledFonts()
        let height = MaskRenderer.contentHeight(text: text, setup: setup, width: Self.surfaceWidth)
        return MaskRenderer().generate(text: text, setup: setup,
                                       canvasSize: CGSize(width: Self.canvasWidth, height: height),
                                       screenScale: 2)
    }

    // MARK: - Line identity

    @Test("Every letter belongs to exactly one line, and the lines run top to bottom")
    func lettersBelongToOneLine() {
        let page = layout(Self.transcript)
        #expect(page.lineCount > 1)

        let listed = page.scorableByLine.values.flatMap { $0 }
        #expect(Set(listed).count == listed.count, "a letter was listed on two lines")
        #expect(listed.count == page.scorableCount, "not every letter reached a line")

        for (line, indices) in page.scorableByLine {
            for index in indices {
                #expect(page.glyphBoxes[index].lineIndex == line)
            }
        }
        // Reading order: a later line sits lower on the page.
        for line in 1..<page.lineCount {
            #expect(page.baselines[line] > page.baselines[line - 1])
        }
    }

    @Test("A point on a line resolves to that line, and the margin below the page does not")
    func tapResolvesToALine() {
        let page = layout(Self.transcript)
        for line in 0..<page.lineCount {
            guard let band = page.rect(forLine: line) else { Issue.record("no band for \(line)"); continue }
            #expect(page.lineIndex(at: CGPoint(x: band.midX, y: band.midY)) == line)
        }
        // Well past the last line there is nothing to select.
        let far = (page.baselines.last ?? 0) + page.lineSpacing * 3
        #expect(page.lineIndex(at: CGPoint(x: 100, y: far)) == nil)
    }

    @Test("A line is graded only once every letter on it has ink")
    func gradedNeedsEveryLetter() {
        let page = layout(Self.transcript)
        var tally = ScoringEngine.Tally(wordOfLetter: page.glyphBoxes.map(\.wordIndex),
                                        scorable: page.glyphBoxes.map(\.isScorable),
                                        totalWords: page.wordCount)
        func graded() -> Set<Int> {
            Set(page.scorableByLine.filter { _, indices in
                !indices.isEmpty && indices.allSatisfy { tally.hasInk(letter: $0) }
            }.keys)
        }
        #expect(graded().isEmpty)

        guard let first = page.scorableByLine[0], first.count > 2 else {
            Issue.record("the first line has no letters"); return
        }
        for index in first.dropLast() { tally.record(letter: index, isInside: true) }
        #expect(graded().isEmpty, "a line with one letter left is still in hand")

        tally.record(letter: first[first.count - 1], isInside: true)
        #expect(graded() == [0], "finishing the last letter should settle the line")
    }

    // MARK: - Appending

    @Test("Appending words never moves a word already on the page")
    func wrapIsPrefixStable() {
        // The whole append design rests on this: the child's ink stays where they drew it
        // because greedy word wrap cannot reflow a prefix.
        let before = layout(Self.transcript)
        let after = layout(Self.transcript + " Then we had ice cream on the way home and Dad "
                           + "let me have chocolate sauce on mine.")

        #expect(after.glyphBoxes.count > before.glyphBoxes.count)
        for (index, box) in before.glyphBoxes.enumerated() {
            let moved = after.glyphBoxes[index]
            #expect(moved.charIndex == box.charIndex)
            #expect(moved.lineIndex == box.lineIndex, "letter \(index) changed line")
            #expect(abs(moved.rect.minX - box.rect.minX) < 0.01, "letter \(index) moved sideways")
            #expect(abs(moved.rect.minY - box.rect.minY) < 0.01, "letter \(index) moved down")
        }
    }

    @Test("Appending raises the word total and leaves the words already written alone")
    func appendingGrowsTheWordCount() {
        let before = layout(Self.transcript)
        let addition = "Then we had ice cream on the way home."
        let after = layout(Self.transcript + " " + addition)

        #expect(after.wordCount == before.wordCount + WritingSession.wordCount(addition))
        // The first new word is exactly where the page should scroll to.
        #expect(WritingSession.wordCount(Self.transcript) == before.wordCount)
        #expect(after.rect(forWord: before.wordCount) != nil)
    }

    @Test("Ink keeps its letter when the page grows underneath it")
    func inkSurvivesAnAppend() {
        // Re-attribution runs every point past the new mask; the same point must land on
        // the same letter, or a child's finished line would stop counting as finished.
        let setup = WritingSetup.default
        FontRegistry.registerBundledFonts()
        let taller = MaskRenderer.contentHeight(text: Self.transcript + " and more words after it",
                                                setup: setup, width: Self.surfaceWidth)
        let size = CGSize(width: Self.canvasWidth, height: taller)

        let before = MaskRenderer()
        before.generate(text: Self.transcript, setup: setup, canvasSize: size, screenScale: 2)
        let after = MaskRenderer()
        after.generate(text: Self.transcript + " and more words after it",
                       setup: setup, canvasSize: size, screenScale: 2)

        var checked = 0
        for box in before.layout.glyphBoxes where box.isScorable {
            let centre = box.center
            #expect(before.glyphIndex(at: centre) == after.glyphIndex(at: centre),
                    "'\(box.character)' at \(centre) was re-attributed elsewhere")
            checked += 1
        }
        #expect(checked > 40)
    }

    // MARK: - Line advance

    @Test("Every bundled face lays out every word it is given, at every size")
    func nothingFallsOffThePage() {
        // The page is sized from `lineAdvance`, and the frame drops any line that does not
        // fit inside it. Under-measure by a few points and the last line of the entry is
        // simply not there — no error, no warning, and the child cannot write it.
        FontRegistry.registerBundledFonts()
        let words = WritingSession.wordCount(Self.transcript)
        #expect(JournalFace.available.count == JournalFace.all.count, "a bundled face did not register")

        for face in JournalFace.available {
            for size in JournalSize.all {
                let setup = WritingSetup(face: face, size: size, mode: .trace)
                let expected = MaskRenderer.lineCount(text: Self.transcript, setup: setup,
                                                      width: Self.surfaceWidth)
                let page = layout(Self.transcript, setup: setup)
                #expect(page.lineCount == expected,
                        "\(face.label) at \(size.label): laid out \(page.lineCount) of \(expected) lines")
                #expect(page.wordCount == words,
                        "\(face.label) at \(size.label): \(page.wordCount) of \(words) words reachable")
            }
        }
    }

    @Test("Lines advance by exactly the distance the page was measured with")
    func advanceMatchesTheMeasurement() {
        FontRegistry.registerBundledFonts()
        for face in JournalFace.available {
            for size in JournalSize.all {
                let setup = WritingSetup(face: face, size: size, mode: .trace)
                let page = layout(Self.transcript, setup: setup)
                let advance = MaskRenderer.lineAdvance(for: setup)
                #expect(abs(page.lineSpacing - advance) < 0.01)
                for line in 1..<page.lineCount {
                    let gap = page.baselines[line] - page.baselines[line - 1]
                    #expect(abs(gap - advance) < 0.6,
                            "\(face.label) at \(size.label): line \(line) sits \(gap) from the last, not \(advance)")
                }
                // A face may need more room than §7.3 asks for, but never less: the ruled
                // lines are drawn at this spacing and the letters have to sit on them.
                #expect(advance >= size.lineSpacing - 0.01)
            }
        }
    }

    // MARK: - Scoring

    @Test("Spaces are never counted as letters the child skipped")
    func spacesAreNotScored() {
        let page = layout("Today we went")
        var tally = ScoringEngine.Tally(wordOfLetter: page.glyphBoxes.map(\.wordIndex),
                                        scorable: page.glyphBoxes.map(\.isScorable),
                                        totalWords: page.wordCount)
        for (index, box) in page.glyphBoxes.enumerated() where box.isScorable {
            for _ in 0..<8 { tally.record(letter: index, isInside: true) }
        }
        // Two spaces sit between three written words; neither may cost anything.
        #expect(page.glyphBoxes.contains { !$0.isScorable })
        #expect(tally.unfinishedCount == 0)
        #expect(tally.finalAccuracy == 1.0)
        #expect(tally.wordsWritten == 3)

        let result = ScoringEngine.score(tally: tally, streak: 0)
        #expect(result.finishedEverything)
        #expect(ScoringEngine.finishMessage(for: result).contains("whole thing"))
    }
}
