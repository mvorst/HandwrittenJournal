import Testing
import UIKit
@testable import HandwrittenJournal

/// The page is one continuous scrolling document now, so what used to be the splitter's
/// job is measurement: how tall does this text need to be, at this face and size?
struct PageLayoutTests {

    static let surfaceWidth: CGFloat = 754

    @Test("A longer entry needs a taller page")
    func heightGrowsWithText() {
        FontRegistry.registerBundledFonts()
        let short = MaskRenderer.contentHeight(text: "I saw a red bird",
                                               setup: .default, width: Self.surfaceWidth)
        let long = MaskRenderer.contentHeight(
            text: String(repeating: "I saw a red bird in the yard. ", count: 12),
            setup: .default, width: Self.surfaceWidth)
        #expect(long > short * 3)
    }

    @Test("A bigger size needs a taller page for the same words")
    func heightGrowsWithSize() {
        FontRegistry.registerBundledFonts()
        let text = "Today we went to the park and I saw a big dog"
        func height(_ id: String) -> CGFloat {
            MaskRenderer.contentHeight(text: text,
                                       setup: WritingSetup(faceID: "jua", sizeID: id, mode: .trace),
                                       width: Self.surfaceWidth)
        }
        #expect(height("xl") > height("l"))
        #expect(height("l") > height("xs"))
    }

    @Test("Every bundled face lays the same text out without losing any of it")
    func everyFaceLaysOut() {
        FontRegistry.registerBundledFonts()
        let text = "The dog wanted to play with me"
        for face in JournalFace.available {
            let renderer = MaskRenderer()
            let setup = WritingSetup(face: face, size: .default, mode: .trace)
            let height = MaskRenderer.contentHeight(text: text, setup: setup, width: Self.surfaceWidth)
            let layout = renderer.generate(text: text, setup: setup,
                                           canvasSize: CGSize(width: 834, height: height), screenScale: 2)
            #expect(layout.scorableCount == text.filter { !$0.isWhitespace }.count,
                    "\(face.label) dropped glyphs")
            #expect(layout.wordCount == 7, "\(face.label) counted \(layout.wordCount) words")
        }
    }

    @Test("Word indices march forward and match the transcript")
    func wordIndices() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let text = "one two three"
        let layout = renderer.generate(text: text, setup: .default,
                                       canvasSize: CGSize(width: 834, height: 400), screenScale: 2)
        let words = layout.glyphBoxes.filter(\.isScorable).map(\.wordIndex)
        #expect(words == words.sorted())
        #expect(Set(words) == [0, 1, 2])
        #expect(layout.wordCount == WritingSession.wordCount(text))
    }

    @Test("A word can be located on the page so a resumed entry scrolls to it")
    func wordRects() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let text = String(repeating: "word ", count: 40)
        let height = MaskRenderer.contentHeight(text: text, setup: .default, width: Self.surfaceWidth)
        let layout = renderer.generate(text: text, setup: .default,
                                       canvasSize: CGSize(width: 834, height: height), screenScale: 1)
        guard let first = layout.rect(forWord: 0), let last = layout.rect(forWord: 30) else {
            Issue.record("missing word rects"); return
        }
        #expect(last.minY > first.minY, "word 30 should be further down the page than word 0")
    }
}
