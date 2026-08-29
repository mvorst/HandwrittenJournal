import Testing
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §4.4 — one take is one telling, however often the child stops for
/// breath.
///
/// `SFSpeechRecognizer` hands back one utterance at a time and numbers each from zero, so
/// its latest hypothesis is only ever the *tail* of what has been said. Taking that as the
/// transcript threw away everything before the first pause, which is the whole point of
/// these tests: a five-year-old telling a story pauses constantly, and the words already
/// on the page must not move when they do.
struct SpokenTakeTests {

    @Test("Partial results within one utterance replace, because they are cumulative")
    func partialsReplace() {
        var take = SpokenTake()
        take.hear("Today")
        take.hear("Today we")
        take.hear("Today we went to the park")
        #expect(take.text == "Today we went to the park")
    }

    @Test("A pause keeps what was said before it")
    func pauseKeepsEarlierWords() {
        var take = SpokenTake()
        take.hear("Today we went to the park.")
        take.endUtterance()

        // The next utterance starts from nothing — this is what used to overwrite the take.
        take.hear("I")
        #expect(take.text == "Today we went to the park. I")
        take.hear("I saw a big dog.")
        #expect(take.text == "Today we went to the park. I saw a big dog.")
    }

    @Test("Many pauses accumulate in the order they were said")
    func manyPauses() {
        var take = SpokenTake()
        for utterance in ["Today we went to the park.", "I saw a big dog.", "It was brown."] {
            take.hear(utterance)
            take.endUtterance()
        }
        #expect(take.text == "Today we went to the park. I saw a big dog. It was brown.")
    }

    @Test("Ending an utterance twice adds nothing — a late final result is harmless")
    func endingTwiceIsIdempotent() {
        var take = SpokenTake()
        take.hear("I saw a red bird.")
        take.endUtterance()
        let once = take
        take.endUtterance()
        #expect(take == once)
        #expect(take.text == "I saw a red bird.")
    }

    @Test("A silent utterance costs nothing and leaves no gap")
    func silenceAddsNothing() {
        var take = SpokenTake()
        take.hear("We made pancakes.")
        take.endUtterance()
        take.hear("")           // a long think, then the recogniser gives up on it
        take.endUtterance()
        take.hear("Mine was the biggest.")
        #expect(take.text == "We made pancakes. Mine was the biggest.")
    }

    @Test("A take that never hears anything is empty, not a space")
    func emptyTake() {
        var take = SpokenTake()
        #expect(take.text.isEmpty)
        take.endUtterance()
        #expect(take.text.isEmpty)
    }

    @Test("The words the page shows are the words the entry keeps")
    @MainActor func tidyingLeavesTheTakeIntact() {
        // What the view model does with the take at "I'm done talking" (§5.2).
        var take = SpokenTake()
        take.hear("today we went to the park.")
        take.endUtterance()
        take.hear("i saw a big dog.")
        take.endUtterance()
        #expect(WriteSessionViewModel.tidy(take.text)
                == "Today we went to the park. i saw a big dog.")
        #expect(WritingSession.wordCount(take.text) == 11)
    }
}
