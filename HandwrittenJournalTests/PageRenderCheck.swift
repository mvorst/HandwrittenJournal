import Testing
import UIKit
@testable import HandwrittenJournal

/// Drives the v2.6 page through its real lifecycle — select a row, ink it, watch it
/// settle and the next come up, go back and fix one — and renders the tiers offscreen so
/// they can be looked at rather than only asserted. Writes PNGs when `HJ_RENDER_DIR` is
/// set.
@MainActor
struct PageRenderCheck {

    nonisolated static let record = "Today we went to the park and I saw a big dog."
    nonisolated static let spoken = "The dog wanted to play with me and we threw a ball for it until it got tired."
    nonisolated static var page: String { record + "\n" + spoken }

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

    private func rowInk(_ view: TracingCanvasView, _ row: Int) -> [TracingStroke] {
        ink(over: (view.layout.scorableByLine[row] ?? []).map { view.layout.glyphBoxes[$0] })
    }

    /// A page with the first `tracedRows` rows fully inked, restored the way a resumed
    /// entry restores its archive.
    private func makeCanvas(text: String = PageRenderCheck.page,
                            tracedRows: Int = 0) -> TracingCanvasView {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup.default
        let width: CGFloat = 834
        let height = MaskRenderer.contentHeight(text: text, setup: setup,
                                                width: width - Tokens.Layout.surfaceInset * 2)
        let view = TracingCanvasView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.text = text
        view.setup = setup
        view.layoutIfNeeded()
        if tracedRows > 0 {
            let boxes = view.layout.glyphBoxes.filter { $0.lineIndex < tracedRows }
            view.restore(ink(over: boxes))
        }
        return view
    }

    private func render(_ view: TracingCanvasView, _ name: String) {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
        guard let dir = ProcessInfo.processInfo.environment["HJ_RENDER_DIR"],
              let data = image.pngData() else { return }
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }

    // MARK: - Tiers and the record

    @Test("The record is the unbroken run of fully-traced rows, derived from the ink")
    func recordDerivesFromInk() {
        let view = makeCanvas(tracedRows: 2)
        render(view, "page-resumed.png")
        #expect(view.rowHasAnyInk(0) && view.rowHasAnyInk(1) && !view.rowHasAnyInk(2))
        let expected = view.layout.endCharIndex(ofLine: 1)
        #expect(view.recordEnd == expected, "the record ends where the traced run ends")
        #expect(view.selectedRow == nil, "nothing is selected until the child taps")
    }

    @Test("A traced row out of order does not extend the record past the gap")
    func outOfOrderLeavesTheRecordAtTheGap() {
        let view = makeCanvas(tracedRows: 1)
        let endOfRun = view.layout.endCharIndex(ofLine: 0)

        view.selectRow(3)
        view.addInk(rowInk(view, 3))
        // Row 3 is traced (and auto-advance moved on), but rows 1–2 are not: the record —
        // the story so far, in order — still ends at the end of row 0.
        #expect(view.rowFullyInked(3))
        #expect(view.recordEnd == endOfRun,
                "a hole in the run keeps the record at the last unbroken row")

        view.selectRow(1)
        view.addInk(rowInk(view, 1))
        view.selectRow(2)
        view.addInk(rowInk(view, 2))
        let throughGap = view.layout.endCharIndex(ofLine: 3)
        #expect(view.recordEnd == throughGap, "filling the gap lets the record run through")
    }

    // MARK: - Selection

    @Test("Any row can be selected at any time, and leaving an inked row settles it")
    func freeSelection() {
        var selections: [Int] = []
        let view = makeCanvas(tracedRows: 2)
        view.onSelectRow = { selections.append($0) }

        view.selectRow(4)                       // way ahead
        #expect(view.selectedRow == 4)
        view.selectRow(0)                       // back to a traced row
        #expect(view.selectedRow == 0, "traced rows are selectable for fixing")
        view.selectRow(2)
        #expect(view.selectedRow == 2)
        #expect(selections == [4, 0, 2])
        render(view, "page-traced-row-reselected.png")
    }

    @Test("Finishing a row's last letter selects the next untraced row on its own")
    func autoAdvance() {
        let view = makeCanvas()
        view.selectRow(0)
        view.addInk(rowInk(view, 0))
        #expect(view.rowFullyInked(0))
        #expect(view.selectedRow == 1, "the next untraced row came up without a tap")
        render(view, "page-after-advance.png")

        // Fill every remaining row: selection ends empty rather than wrapping.
        for row in 1..<view.layout.lineCount where !(view.layout.scorableByLine[row] ?? []).isEmpty {
            view.selectRow(row)
            view.addInk(rowInk(view, row))
        }
        #expect(view.selectedRow == nil, "a finished page has nothing left to select")
        #expect(view.recordEnd == view.layout.endCharIndex(ofLine: view.layout.lineCount - 1))
    }

    @Test("Auto-advance skips rows that are already traced")
    func advanceSkipsTraced() {
        let view = makeCanvas()
        view.selectRow(1)
        view.addInk(rowInk(view, 1))            // row 1 traced out of order → advance to 2
        #expect(view.selectedRow == 2)
        view.selectRow(0)
        view.addInk(rowInk(view, 0))            // finishing row 0 must skip traced row 1
        #expect(view.selectedRow == 2, "the next untraced row is 2, not 1")
    }

    // MARK: - Tools

    @Test("Undo, clear and the eraser reach only the selected row's ink")
    func toolsAreScopedToTheSelectedRow() {
        let view = makeCanvas(tracedRows: 2)
        let total = view.strokes.count

        view.selectRow(2)
        view.undo()
        view.clearSelected()
        #expect(view.strokes.count == total, "row 2 has no ink; other rows' ink untouched")

        view.addInk(rowInk(view, 2))
        let withRow2 = view.strokes.count
        #expect(withRow2 > total)
        // addInk on a full row auto-advances; come back to row 2 to use the tools on it.
        view.selectRow(2)
        view.undo()
        #expect(view.strokes.count == withRow2 - 1, "undo removed row 2's last stroke")
        view.clearSelected()
        #expect(view.strokes.count == total, "clear wiped exactly row 2's ink")
        #expect(view.rowHasAnyInk(0) && view.rowHasAnyInk(1))
    }

    @Test("Clearing a record row shrinks the record — the record follows the ink")
    func recordShrinksWithTheInk() {
        var reported: [Int] = []
        let view = makeCanvas(tracedRows: 2)
        view.onRecordChange = { reported.append($0) }

        view.selectRow(1)
        view.clearSelected()
        #expect(view.recordEnd == view.layout.endCharIndex(ofLine: 0),
                "wiping row 1's ink pulls the record back to row 0")
        #expect(reported.last == view.recordEnd)
    }

    // MARK: - Scoring

    @Test("The entry score covers every row with ink — untouched letters there at zero")
    func scoreCoversInkedRows() {
        let view = makeCanvas(tracedRows: 1)
        // Half-trace row 1, then finish: its skipped letters cost; rows 2+ do not.
        view.selectRow(1)
        let indices = view.layout.scorableByLine[1] ?? []
        let half = indices.prefix(indices.count / 2).map { view.layout.glyphBoxes[$0] }
        view.addInk(ink(over: half))

        let result = view.finishEntry(streak: 0)
        #expect(view.selectedRow == nil, "finishing settles the page")
        #expect(result.unfinishedLetters >= indices.count - half.count - 1)
        #expect(result.accuracy < 1.0, "skipped letters on an inked row cost something")
        #expect(result.wordsRemaining > 0, "untraced rows stay spoken")
        #expect(!result.finishedEverything)
    }

    // MARK: - Dictation and the spoken tier

    @Test("Saying more appends a paragraph and never moves inked rows")
    func appendIsAParagraph() {
        let view = makeCanvas(text: Self.record, tracedRows: 3)
        let before = view.layout.glyphBoxes
        let strokes = view.strokes.count
        let recordBefore = view.recordEnd

        view.text = Self.record + "\n" + "We saw a squirrel too and it ran up a tree."
        view.frame = CGRect(x: 0, y: 0, width: 834,
                            height: MaskRenderer.contentHeight(text: view.text, setup: view.setup,
                                                               width: 834 - Tokens.Layout.surfaceInset * 2))
        view.layoutIfNeeded()

        #expect(view.strokes.count == strokes, "the traced ink survived the append")
        #expect(view.recordEnd == recordBefore, "the record did not move")
        for (i, box) in before.enumerated() {
            let after = view.layout.glyphBoxes[i]
            #expect(after.lineIndex == box.lineIndex && abs(after.rect.minX - box.rect.minX) < 0.01,
                    "traced glyph \(i) moved")
        }
        render(view, "page-said-more.png")
    }

    @Test("Fixing a spoken word reflows only untraced rows")
    func spokenEditIsSafe() {
        let view = makeCanvas(tracedRows: 2)
        let traced = view.layout.glyphBoxes.filter { $0.lineIndex < 2 }
        let strokes = view.strokes.count

        // "ball" -> "balloon": a different length, in the untraced tier.
        let edited = Self.page.replacingOccurrences(of: "ball ", with: "balloon ")
        view.text = edited
        view.layoutIfNeeded()

        #expect(view.strokes.count == strokes, "traced ink survived the edit")
        for (i, box) in traced.enumerated() {
            let after = view.layout.glyphBoxes[i]
            #expect(abs(after.rect.minX - box.rect.minX) < 0.01 && after.lineIndex == box.lineIndex,
                    "traced glyph \(i) moved when a spoken word changed")
        }
    }

    @Test("A word can be found under a tap for fixing")
    func wordUnderTap() {
        let view = makeCanvas(tracedRows: 2)
        guard let spokenBox = view.layout.glyphBoxes.first(where: { box in
            box.isScorable && !view.rowHasAnyInk(box.lineIndex)
        }) else { Issue.record("no spoken glyph"); return }
        guard let word = view.layout.word(at: spokenBox.center) else {
            Issue.record("no word under the tap"); return
        }
        let characters = Array(view.text)
        let text = String(characters[word.range.lowerBound...word.range.upperBound])
        #expect(!text.isEmpty && !text.contains(" "))
    }
}
