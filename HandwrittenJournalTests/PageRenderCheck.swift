import Testing
import UIKit
@testable import HandwrittenJournal

/// Renders the writing page offscreen so the three line states can be looked at rather
/// than only asserted. Writes PNGs when `HJ_RENDER_DIR` is set; otherwise it just checks
/// that the page draws.
@MainActor
struct PageRenderCheck {

    static let transcript = "Today we went to the park and I saw a big dog. The dog wanted to "
        + "play with me and we threw a ball for it until it got tired. Then we had ice cream "
        + "on the way home and Dad let me have chocolate sauce on mine."

    /// Ink that follows the letterforms closely enough to score well, with a little drift.
    private func ink(over boxes: [MaskRenderer.GlyphBox]) -> [TracingStroke] {
        var seed: UInt64 = 42
        func jitter(_ scale: CGFloat) -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return (CGFloat((seed >> 33) % 1000) / 1000 - 0.5) * scale
        }
        return boxes.filter(\.isScorable).map { box in
            var stroke = TracingStroke()
            for step in 0...10 {
                let t = CGFloat(step) / 10
                let point = CGPoint(x: box.rect.minX + box.rect.width * t + jitter(box.rect.width * 0.3),
                                    y: box.rect.midY + jitter(box.rect.height * 0.55))
                stroke.append(StrokePoint(location: point, force: 0.6, isInside: true, letterIndex: -1))
            }
            return stroke
        }
    }

    private func page(writtenLines: Int, select: Int? = nil) -> (TracingCanvasView, UIImage) {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default
        let width: CGFloat = 834
        let height = MaskRenderer.contentHeight(text: Self.transcript, setup: setup,
                                                width: width - Tokens.Layout.surfaceInset * 2)
        let view = TracingCanvasView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.text = Self.transcript
        view.setup = setup
        view.layoutIfNeeded()

        let written = view.layout.glyphBoxes.filter { $0.lineIndex < writtenLines }
        view.restore(ink(over: written))
        if let select { view.selectLine(select) }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
        return (view, image)
    }

    private func write(_ image: UIImage, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["HJ_RENDER_DIR"],
              let data = image.pngData() else { return }
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }

    @Test("The page draws with three lines graded and the rest still guide text")
    func threeStates() {
        let (view, image) = page(writtenLines: 3)
        write(image, "page-part-written.png")
        #expect(view.gradedLines == [0, 1, 2])
        #expect(image.size.height > 800)
    }

    @Test("A graded line can be selected and written again")
    func retrace() {
        let (view, image) = page(writtenLines: 4, select: 1)
        write(image, "page-retrace.png")
        #expect(view.selectedLine == 1)

        view.writeLineAgain(1)
        #expect(view.selectedLine == nil)
        #expect(!view.gradedLines.contains(1), "the line should be back in hand")
        #expect(view.gradedLines.contains(0) && view.gradedLines.contains(2),
                "re-tracing one line must not disturb the lines around it")
    }

    @Test("Saying more grows the page without disturbing what is already written")
    func appendKeepsTheWriting() {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default
        let width: CGFloat = 834
        let opening = "Today we went to the park and I saw a big dog."
        let rest = " The dog wanted to play with me and we threw a ball for it until it "
            + "got tired. Then we had ice cream on the way home."

        func height(_ text: String) -> CGFloat {
            MaskRenderer.contentHeight(text: text, setup: setup,
                                       width: width - Tokens.Layout.surfaceInset * 2)
        }
        let view = TracingCanvasView(frame: CGRect(x: 0, y: 0, width: width, height: height(opening)))
        view.text = opening
        view.setup = setup
        view.layoutIfNeeded()
        view.restore(ink(over: view.layout.glyphBoxes))
        let writtenBefore = view.gradedLines
        #expect(!writtenBefore.isEmpty)
        #expect(view.tally.wordsWritten == WritingSession.wordCount(opening))

        // What the scroll view does when the transcript grows: new text first, then the
        // taller frame. The mask has to be rebuilt for the new height or the added lines
        // are laid out somewhere the child can never reach.
        let whole = opening + rest
        view.text = whole
        view.frame = CGRect(x: 0, y: 0, width: width, height: height(whole))
        view.layoutIfNeeded()

        #expect(view.layout.wordCount == WritingSession.wordCount(whole),
                "\(view.layout.wordCount) of \(WritingSession.wordCount(whole)) words survived the append")
        // Every finished line stays finished except the last, which legitimately re-opens:
        // the new words join it, so it is no longer a line the child has written in full.
        let lastBefore = writtenBefore.max() ?? 0
        #expect(view.gradedLines.isSuperset(of: writtenBefore.filter { $0 < lastBefore }),
                "a line that was finished stopped being finished")
        #expect(!view.gradedLines.contains(lastBefore),
                "the line the new words landed on should be back in hand")
        #expect(view.tally.wordsWritten == WritingSession.wordCount(opening),
                "the words already written should still count, and no more")
        #expect(view.rect(forWord: WritingSession.wordCount(opening)) != nil,
                "the first new word must be somewhere the page can scroll to")
    }

    @Test("An untraced page has no graded lines at all")
    func untouched() {
        let (view, image) = page(writtenLines: 0)
        write(image, "page-untouched.png")
        #expect(view.gradedLines.isEmpty)
    }
}
