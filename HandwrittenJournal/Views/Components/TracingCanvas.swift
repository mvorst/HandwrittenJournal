import SwiftUI
import UIKit

/// §8.1b — a word was finished with letters drawn in the wrong order, and the child
/// should be shown how those letters are written before carrying on.
struct FormationHelpRequest: Hashable {
    struct Letter: Hashable {
        /// Index into the layout's glyph boxes — what `markRemediated` takes.
        let glyph: Int
        /// Index into the page text — what survives an entry being closed and reopened.
        let charIndex: Int
        /// Position within `wordText`, for the red highlight.
        let offset: Int
        let character: Character
    }

    let word: Int
    /// The word as the page shows it, punctuation included.
    let wordText: String
    /// Every letter of the word that took the order discount, in reading order.
    let letters: [Letter]

    var wrongOffsets: Set<Int> { Set(letters.map(\.offset)) }
}

/// The writing surface — one continuous scrolling page, and the whole write flow.
/// WIREFRAME_SPEC.md §11 (v2.6).
///
/// Every row of the page is in exactly one of three states:
///
/// | State | Letters | Ink |
/// |---|---|---|
/// | **Traced** — has ink, not selected | faint grey | natural graphite |
/// | **Selected** — the row being written | black | accuracy colours |
/// | **Untraced** — waiting, not selected | light grey (`spoken-text`) | none |
///
/// **Any row can be selected by tapping it, at any time.** Selecting a traced row brings
/// its ink back into accuracy colours for fixing; deselecting a row settles it — guide
/// fades to faint, ink turns graphite, in place. When the selected row's last letter gets
/// ink, the next untraced row is selected automatically so the flow never needs a tap
/// per line — the taps are for going back, skipping, or fixing.
///
/// **The record** — what the journal, exports and counts read — is the unbroken run of
/// fully-traced rows from the top of the page. It is derived from the ink, never set:
/// text becomes real by being written, and only by being written.
final class TracingCanvasView: UIView {

    // MARK: - Configuration

    /// The whole page: record + spoken buffer (+ the live partial while dictating),
    /// paragraphs separated by newlines.
    var text: String = "" { didSet { if text != oldValue { rebuild() } } }
    var setup: WritingSetup = .default { didSet { if setup != oldValue { rebuild(force: true) } } }
    var showGuideLines = true { didSet { setNeedsDisplay() } }
    var showGuideText = true { didSet { setNeedsDisplay() } }
    var colourBlind = false { didSet { redrawCommitted() } }
    var allowFinger = true
    var isEraserActive = false {
        didSet {
            eraserCentre = nil
            setNeedsDisplay()
        }
    }
    /// The crayon (v3.2): drawing touches doodle anywhere on the page. A doodle selects
    /// nothing, is attributed to nothing and is scored against nothing; it is kept with
    /// the page in its own layer. With the eraser on as well, the eraser rubs out doodles.
    var isDoodleActive = false { didSet { setNeedsDisplay() } }
    /// Which crayon the next doodle is drawn with (`Crayon.rawValue`).
    var crayon: Int = 0
    /// The ABC tool (v3.2): a touch picks a spoken word to fix, a drag picks a run, and a
    /// tap past the last word asks to add more. It replaces tap- and hold-to-edit, so a
    /// hand set down on the page can never raise the keyboard.
    var isTextEditActive = false {
        didSet {
            dragAnchor = nil
            dragRange = nil
            pendingAppendTap = nil
            setNeedsDisplay()
        }
    }
    /// Row handles sit in the margin gutter the writing hand is not resting on.
    var handlesOnRight = false { didSet { setNeedsDisplay() } }
    /// While dictating the mask is skipped (nobody can trace yet — selecting a row stops
    /// the mic) and a caret marks where the next word will land.
    var isDictating = false {
        didSet {
            guard isDictating != oldValue else { return }
            if !isDictating { rebuild(revalidate: true) }   // bring the mask back
            setNeedsDisplay()
        }
    }
    /// The character range of the spoken words being fixed — drawn as an action box. Set
    /// by the view model once a selection lands; `dragRange` is what the finger is drawing
    /// out right now, so the box never blinks between the two.
    var editingRange: ClosedRange<Int>? { didSet { dragRange = nil; setNeedsDisplay() } }

    var onProgress: ((_ liveAccuracy: Double, _ wordsWritten: Int, _ hasInk: Bool) -> Void)?
    /// Fires when the layout changes so the scroll view can resize its content.
    var onLayoutChange: ((CGFloat) -> Void)?
    /// The record boundary moved — the unbroken run of fully-traced rows grew or shrank.
    /// Carries the record's length in characters of `text`.
    var onRecordChange: ((Int) -> Void)?
    /// A row was selected (by tap, pen-down or auto-advance) — the view model stops the
    /// mic and the page scrolls to it.
    var onSelectRow: ((Int) -> Void)?
    /// An untraced word was held for fixing: its character range and current text.
    var onEditWord: ((ClosedRange<Int>, String) -> Void)?
    /// §8.1b — a word was finished with letters drawn in the wrong order, and the child
    /// is done with it. Fired at pen-up, once per word; the view model presents the
    /// remediation modal.
    var onFormationHelpNeeded: ((FormationHelpRequest) -> Void)?
    /// The finished ink changed — a stroke landed, was undone, erased or cleared, or an
    /// archive was put back. Fired after the tally and the record have caught up, so
    /// the view model can keep the archive current on every one of them: a crash or a
    /// jettison between two strokes must cost one stroke, never a page (§6).
    var onInkChange: (() -> Void)?
    /// The ABC tool was tapped past the last word: the child wants to add more (v3.2).
    var onAppendRequested: (() -> Void)?
    /// Whether the page has any ink at all, and any doodles — what enables "I'm finished"
    /// and the tools while the crayon is in hand.
    var onPageState: ((_ hasAnyInk: Bool, _ hasDoodles: Bool) -> Void)?

    // MARK: - State

    private(set) var strokes: [TracingStroke] = []
    /// The crayon layer — never in `strokes`, so nothing that scores can see it (v3.2).
    private(set) var doodles: [TracingStroke] = []
    private(set) var tally = ScoringEngine.Tally(letterCount: 0)
    private let maskRenderer = MaskRenderer()
    /// §8.1a — judges each letter's ink against its taught formation. nil for every
    /// face the formations are not fitted to, where no order discount applies.
    private var orderJudge: FormationOrderJudge?
    private var judgeSetup: WritingSetup?

    // §8.1b — remediation. A letter the child has re-traced correctly in the help modal
    // is forgiven its order discount for the life of the entry; a word prompts for help
    // at most once per sitting; and words already complete when a page is restored never
    // prompt — only a word finished under the child's own pen does.
    private var remediatedLetters: Set<Int> = []
    private var pendingRemediatedChars: [Int]?
    private var promptedWords: Set<Int> = []
    private var knownCompletedWords: Set<Int> = []
    /// Words complete with wrong-order letters, waiting for the child to be done with
    /// them before the modal interrupts (§8.1b).
    private var pendingHelpWords: Set<Int> = []
    /// Letters whose ink covers every part of their formation, per the judge.
    private var coveredLetters: Set<Int> = []
    private var suppressHelpPrompts = false
    private var current: TracingStroke?
    private var committedImage: UIImage?
    private var eraserCentre: CGPoint?
    private var builtForSize: CGSize = .zero
    private var builtForText = ""
    private var pendingRestore: [TracingStroke]?
    /// The canvas width the pending archive was drawn at, or 0 when it is not known.
    private var restoreWidth: CGFloat = 0
    /// Whether the staged archive carries each point's letter (HJST v2), so a restore
    /// keeps the attribution the record was derived from.
    private var restoreAttributed = false
    /// A restore landed during this rebuild; the ink report is owed once the record
    /// has caught up.
    private var restoredThisBuild = false

    /// Whether the ink on this canvas stands for the archive it was given (§6). A
    /// surface that never put its archive back must not be allowed to write one.
    enum InkProvenance {
        /// Nothing was asked to be restored — every stroke here is this sitting's.
        case fresh
        /// An archive is staged and waits for the layout it belongs to.
        case pending
        /// The archive is on the page; the strokes here are it plus this sitting's.
        case restored
        /// The archive could not be put back, or the ink was wiped by a relayout. The
        /// strokes here no longer stand for the entry's ink.
        case lost
    }
    private(set) var provenance: InkProvenance = .fresh
    /// True when an archive written from this canvas would be the whole truth.
    var accountsForArchive: Bool { provenance == .fresh || provenance == .restored }

    /// Glyph index -> row, so a stroke point can be coloured without a lookup per segment.
    private var lineOfGlyph: [Int] = []

    /// The row being written, if any. Ink lands here and nowhere else.
    private(set) var selectedRow: Int?

    /// End of the record in characters of `text` — derived from the ink (see above).
    private(set) var recordEnd = 0
    private var lastEmittedRecord = -1

    /// Rows mid-settle, 0…1. Their guide is fading to faint and their ink to graphite.
    private var settling: [Int: CGFloat] = [:]
    private var settleLink: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    private struct PendingTap {
        let row: Int
        let start: CGPoint
        let began: CFTimeInterval
        let canDraw: Bool
        /// Whether lifting without moving picks the row — true for the pencil and for
        /// the handle, false for a finger on the words (v3.2).
        let selectsOnTap: Bool
    }
    private var pendingTap: PendingTap?
    /// A hand resting on the page, being ignored until it lifts.
    private var ignoredTouch: UITouch?
    /// A tap past the last word with the ABC tool in hand, resolved at pen-up.
    private var pendingAppendTap: CGPoint?
    /// The first unwritten row should come up as soon as the layout exists (v3.2).
    private var wantsFirstRowSelection = false

    /// The word the finger came down on, and the run it has been dragged over. Held here
    /// rather than round-tripped through the view model so the highlight tracks the finger
    /// frame by frame.
    private var dragAnchor: ClosedRange<Int>?
    private(set) var dragRange: ClosedRange<Int>?

    /// The scroll view asks this before it cancels our touches: a selection in progress is
    /// not a scroll that has not started yet.
    var isSelectingText: Bool { dragAnchor != nil }

    /// A settled row keeps this much of the guide — enough to read as letterforms under
    /// the ink, faint enough that the ink is unmistakably the text now.
    static let tracedGuideAlpha: CGFloat = 0.18

    private var widthRange: ClosedRange<CGFloat> {
        let scale = setup.size.size / 72
        return (1.5 * scale)...(5.0 * scale)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Tokens.Colour.paper)
        isMultipleTouchEnabled = false
        isOpaque = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit { settleLink?.invalidate() }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { stopSettleLink() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Height matters as much as width: dictation makes the page taller, and the frame
        // the mask is built in clips anything past its own bounds.
        let widthChanged = abs(bounds.width - builtForSize.width) > 0.5
        let heightChanged = abs(bounds.height - builtForSize.height) > 0.5
        if widthChanged || heightChanged { rebuild(force: widthChanged) }
    }

    // MARK: - Layout

    /// How tall the page needs to be for this text at this width.
    func requiredHeight(forWidth width: CGFloat) -> CGFloat {
        let textWidth = width - Tokens.Layout.surfaceInset * 2
        guard textWidth > 0, !text.isEmpty else { return 1 }
        return MaskRenderer.contentHeight(text: text, setup: setup, width: textWidth)
    }

    /// `force` wipes the ink. Plain rebuilds keep it when the text under the existing ink
    /// has not moved — appends, and edits past every inked row, which is every legal
    /// change (edits are gated to rows with no inked row after them).
    private func rebuild(force: Bool = false, revalidate: Bool = false) {
        guard bounds.width > 0, bounds.height > 0, !text.isEmpty else {
            if text.isEmpty { clearForEmptyText() }
            return
        }

        // Everything up to the end of the last inked row (and the selected row) is under
        // ink or guide the child is using. If that prefix is untouched, every stroke
        // stays valid: greedy word wrap is prefix-stable, and each dictation starts its
        // own paragraph so earlier rows can never absorb later words.
        let stableLength = stablePrefixLength()
        let stablePrefix = String(builtForText.prefix(stableLength))
        let keepInk = !force && !builtForText.isEmpty && text.hasPrefix(stablePrefix)
            && abs(bounds.width - builtForSize.width) < 0.5

        let textChanged = builtForText != text || builtForSize != bounds.size
        if !revalidate || textChanged {
            builtForSize = bounds.size
            builtForText = text
            regenerate(layoutOnly: isDictating)
        } else {
            regenerate(layoutOnly: false)   // dictation ended; only the mask was missing
        }

        if pendingRestore != nil {
            applyRestore()
        } else if !keepInk {
            // Ink under a layout that moved is nobody's handwriting any more — and it
            // no longer stands for the entry's archive, which must be left alone. The
            // doodles count here too: a page that lost them must not write them away.
            if !strokes.isEmpty || !doodles.isEmpty { provenance = .lost }
            strokes.removeAll()
            doodles.removeAll()
            current = nil
            selectedRow = nil
            settling = [:]
            remediatedLetters = []
            promptedWords = []
            knownCompletedWords = []
            pendingHelpWords = []
            coveredLetters = []
            stopSettleLink()
        }
        if let row = selectedRow, (maskRenderer.layout.scorableByLine[row] ?? []).isEmpty {
            selectedRow = nil
        }
        retally()
        if restoredThisBuild {
            restoredThisBuild = false
            onInkChange?()
        }
        consumeFirstRowSelection()
        onLayoutChange?(bounds.height)
    }

    private func regenerate(layoutOnly: Bool) {
        // A very long entry makes a very tall bitmap; drop to 1x rather than allocate
        // tens of megabytes for a mask nobody looks at closely.
        let pixels = bounds.width * bounds.height * 4
        let scale: CGFloat = pixels > 40_000_000 ? 1 : min(2, UIScreen.main.scale)
        maskRenderer.generate(text: text, setup: setup, canvasSize: bounds.size,
                              screenScale: scale, layoutOnly: layoutOnly)
        lineOfGlyph = maskRenderer.layout.glyphBoxes.map(\.lineIndex)
        // The judge survives re-layouts — its caches self-invalidate per glyph — but a
        // setup change means a new face or size, and a fresh fit.
        if judgeSetup != setup {
            judgeSetup = setup
            orderJudge = FormationOrderJudge(setup: setup)
        }
    }

    private func clearForEmptyText() {
        if !strokes.isEmpty || !doodles.isEmpty { provenance = .lost }
        strokes.removeAll()
        doodles.removeAll()
        current = nil
        selectedRow = nil
        settling = [:]
        pendingHelpWords = []
        coveredLetters = []
        builtForText = ""
        recordEnd = 0
        stopSettleLink()
        setNeedsDisplay()
    }

    /// Characters whose layout the existing ink depends on.
    private func stablePrefixLength() -> Int {
        var end = recordEnd
        for row in inkedRows() {
            if let e = maskRenderer.layout.endCharIndex(ofLine: row) { end = max(end, e) }
        }
        if let row = selectedRow, let e = maskRenderer.layout.endCharIndex(ofLine: row) {
            end = max(end, e)
        }
        return end
    }

    var layout: MaskRenderer.Layout { maskRenderer.layout }
    var scorableLetterCount: Int { maskRenderer.layout.scorableCount }

    /// Where the child has got to — the view scrolls here on resume.
    func rect(forWord word: Int) -> CGRect? { maskRenderer.layout.rect(forWord: word) }
    func rect(forLine line: Int) -> CGRect? { maskRenderer.layout.rect(forLine: line) }

    // MARK: - Row state

    func rowHasAnyInk(_ row: Int) -> Bool {
        guard let indices = maskRenderer.layout.scorableByLine[row] else { return false }
        return indices.contains { tally.hasInk(letter: $0) }
    }

    func rowFullyInked(_ row: Int) -> Bool {
        guard let indices = maskRenderer.layout.scorableByLine[row], !indices.isEmpty else { return false }
        return indices.allSatisfy { tally.hasInk(letter: $0) }
    }

    private func inkedRows() -> [Int] {
        maskRenderer.layout.scorableByLine.keys.filter { rowHasAnyInk($0) }
    }

    /// The row of a stroke — where its first point landed.
    private func row(of stroke: TracingStroke) -> Int? {
        stroke.points.first.flatMap { lineOf($0) }
    }

    private func lineOf(_ point: StrokePoint) -> Int? {
        if point.letterIndex >= 0, point.letterIndex < lineOfGlyph.count {
            return lineOfGlyph[point.letterIndex]
        }
        return maskRenderer.layout.lineIndex(at: point.location)
    }

    // MARK: - Selection

    /// Selecting is the only mode there is: ink lands on the selected row, tools work on
    /// the selected row, and leaving a row settles it.
    func selectRow(_ row: Int?) {
        guard row != selectedRow else { return }
        if let row, (maskRenderer.layout.scorableByLine[row] ?? []).isEmpty { return }
        let previous = selectedRow
        selectedRow = row
        if let previous, rowHasAnyInk(previous) { settle(previous) }
        redrawCommitted()
        reportProgress()
        setNeedsDisplay()
        if let row { onSelectRow?(row) }
    }

    /// When the selected row's last letter gets ink, the next untraced row comes up on
    /// its own — the taps are for going back, not for going forward.
    private func maybeAdvance() {
        guard let row = selectedRow, rowFullyInked(row) else { return }
        let next = maskRenderer.layout.scorableByLine.keys
            .filter { $0 > row && !rowFullyInked($0) }
            .min()
        selectRow(next)
    }

    /// v3.2 — when a take ends, typed words land, or a page is reopened to write on, the
    /// first line with letters still to write comes up on its own, so the page says
    /// where to start (the pencil marker in the margin). If the layout is not there yet
    /// the request waits for the rebuild that brings it.
    func selectFirstUnwrittenRow() {
        wantsFirstRowSelection = true
        consumeFirstRowSelection()
    }

    private func firstUnwrittenRow() -> Int? {
        maskRenderer.layout.scorableByLine.keys.filter { !rowFullyInked($0) }.min()
    }

    private func consumeFirstRowSelection() {
        guard wantsFirstRowSelection, !isDictating, provenance != .pending,
              !maskRenderer.layout.scorableByLine.isEmpty else { return }
        wantsFirstRowSelection = false
        if selectedRow == nil, let row = firstUnwrittenRow() { selectRow(row) }
    }

    // MARK: - Restoring an earlier sitting

    /// Puts an archived tracing back on the page. The record re-derives from the ink, so
    /// a restored page reports the same boundary it was saved with.
    ///
    /// `capturedWidth` is the width the strokes were drawn at; pass 0 when it is not
    /// known. `attributed` says the archive carries each point's letter (HJST v2), so
    /// the restore can keep the attribution instead of re-deriving it.
    func restore(_ archived: [TracingStroke], capturedWidth: CGFloat = 0, attributed: Bool = false) {
        pendingRestore = archived
        restoreWidth = capturedWidth
        restoreAttributed = attributed
        provenance = .pending
        if !maskRenderer.layout.glyphBoxes.isEmpty {
            applyRestore()
            retally()
            if restoredThisBuild {
                restoredThisBuild = false
                onInkChange?()
            }
        }
    }

    /// **An archive only means anything at the width it was captured at.** Greedy word wrap
    /// puts different words on different lines at a different width, so the same points
    /// land on letters they were never drawn over: the tracing reads as scribble, the
    /// record re-derives as empty, and the child's writing is rewritten by ink that is not
    /// theirs. Showing the page without the ink is the honest failure — the archive is
    /// untouched, and the reading page still draws it correctly at its own width (§4.7).
    private func canRestore() -> Bool {
        restoreWidth <= 0 || abs(restoreWidth - bounds.width) < 0.5
    }

    private func applyRestore() {
        guard let restored = pendingRestore else { return }
        pendingRestore = nil
        guard canRestore() else { provenance = .lost; return }
        // Re-attribution tests every point against the mask bitmap, and while dictating the
        // mask is skipped because nobody can trace yet. Reopening a finished page and
        // tapping the mic does both at once, so without this every restored point would
        // read as outside its letter and the whole entry would score zero.
        if !maskRenderer.hasBitmap { regenerate(layoutOnly: false) }
        strokes = restored.ink
        doodles = restored.doodles
        current = nil
        selectedRow = nil
        settling = [:]
        // Restored words are already written — they never prompt for help (§8.1b).
        suppressHelpPrompts = true
        pendingHelpWords = []
        reattribute(keepingStored: restoreAttributed)
        provenance = .restored
        restoredThisBuild = true
    }

    /// Puts every point on its letter.
    ///
    /// An archive from HJST v2 on carries the letter each point was drawn against, and
    /// that attribution is kept: it is what the record was derived from when the page
    /// was saved, so the page reopens with exactly the record it closed with. Deriving
    /// it again against the mask is not the same thing — ink was attributed to the row
    /// in hand as it was drawn, and a descender's tail re-read against the whole page
    /// can land on the row below and unfinish a line the child finished. A point whose
    /// stored letter is not on this layout (an older archive, or one saved against
    /// other text) is attributed afresh.
    private func reattribute(keepingStored: Bool) {
        let boxes = maskRenderer.layout.glyphBoxes
        for s in strokes.indices {
            for p in strokes[s].points.indices {
                let point = strokes[s].points[p]
                if keepingStored {
                    let stored = point.letterIndex
                    if stored < 0 { continue }
                    if boxes.indices.contains(stored), boxes[stored].isScorable,
                       boxes[stored].rect.insetBy(dx: -24, dy: -24).contains(point.location) {
                        continue
                    }
                }
                strokes[s].points[p].letterIndex = maskRenderer.glyphIndex(at: point.location) ?? -1
                strokes[s].points[p].isInside = maskRenderer.isInsideLetter(point: point.location, tolerance: 2)
            }
        }
    }

    // MARK: - Finishing the entry

    /// "I'm finished" / Done. The score covers every row with any ink — the child traced
    /// it, so it counts, and its untouched letters score zero.
    func finishEntry(streak: Int) -> ScoreResult {
        selectRow(nil)
        let inked = Set(inkedRows())
        let committed = maskRenderer.layout.glyphBoxes.map { inked.contains($0.lineIndex) }
        return ScoringEngine.score(tally: tally, committed: committed,
                                   totalWords: maskRenderer.layout.wordCount, streak: streak)
    }

    /// The whole page's ink — handwriting and doodles in one archive, each stroke
    /// carrying its layer (§6.1, HJST v3).
    func archive() throws -> Data { try StrokeArchive.encode(strokes + doodles) }

    /// Always natural ink — a thumbnail is journal furniture, never a marked-up test.
    /// Doodles go in too, under the handwriting, because they are part of the page.
    func thumbnail(width: CGFloat = 320) -> Data? {
        let everything = doodles + strokes
        guard bounds.width > 0, !everything.isEmpty else { return nil }
        var ink = everything[0].bounds()
        for stroke in everything.dropFirst() { ink = ink.union(stroke.bounds()) }
        ink = ink.insetBy(dx: -8, dy: -8)
        guard ink.width > 0, ink.height > 0 else { return nil }
        let scale = width / ink.width
        let size = CGSize(width: width, height: min(ink.height * scale, width * 1.2))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(Tokens.Colour.paper).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: -ink.minX, y: -ink.minY)
            Crayon.draw(doodles, in: ctx.cgContext, widthScale: setup.size.size / 72)
            draw(strokes: strokes, in: ctx.cgContext) { _ in Self.naturalPalette }
        }.pngData()
    }

    // MARK: - Tools (scoped to the selected row)

    func undo() {
        if isDoodleActive {
            guard !doodles.isEmpty else { return }
            doodles.removeLast()
            doodlesChanged()
            return
        }
        guard let row = selectedRow,
              let index = strokes.lastIndex(where: { self.row(of: $0) == row }) else { return }
        strokes.remove(at: index)
        retally()
        onInkChange?()
    }

    func clearSelected() {
        if isDoodleActive {
            guard !doodles.isEmpty else { return }
            doodles.removeAll()
            doodlesChanged()
            return
        }
        guard let row = selectedRow else { return }
        let remaining = strokes.filter { self.row(of: $0) != row }
        guard remaining.count != strokes.count else { return }
        strokes = remaining
        current = nil
        retally()
        onInkChange?()
    }

    private func applyErase(at point: CGPoint) {
        if isDoodleActive {
            guard !doodles.isEmpty else { return }
            let result = StrokeEraser.erase(at: point, from: doodles)
            guard result.strokes.count != doodles.count
                    || result.strokes.pointCount != doodles.pointCount else { return }
            doodles = result.strokes
            doodlesChanged()
            return
        }
        guard let row = selectedRow else { return }
        let mine = strokes.filter { self.row(of: $0) == row }
        guard !mine.isEmpty else { return }
        let others = strokes.filter { self.row(of: $0) != row }
        let result = StrokeEraser.erase(at: point, from: mine)
        guard result.strokes.count != mine.count || !result.touchedLetters.isEmpty else { return }
        strokes = others + result.strokes
        retally()
        onInkChange?()
    }

    var selectedRowHasInk: Bool {
        guard let row = selectedRow else { return false }
        return rowHasAnyInk(row)
    }

    /// The crayon layer changed: the archive follows it like ink (§6), the tools learn
    /// whether there is anything left to undo, and the page redraws.
    private func doodlesChanged() {
        reportProgress()
        setNeedsDisplay()
        onInkChange?()
    }

    // MARK: - Touches

    private func drawingTouch(_ touch: UITouch) -> Bool {
        allowFinger || touch.type == .pencil
    }

    /// **A hand resting on the page is not an input** (§11.6, v3.2). A palm or the heel
    /// of a hand set down to write is far wider than any fingertip, so a wide direct
    /// touch is dropped before it can select, edit or draw anything. The threshold is a
    /// starting point to check on a device: fingertips report roughly 20–35 pt.
    static let handRadius: CGFloat = 50

    static func isHand(radius: CGFloat, type: UITouch.TouchType) -> Bool {
        type == .direct && radius > handRadius
    }

    private static func isHand(_ touch: UITouch) -> Bool {
        isHand(radius: touch.majorRadius, type: touch.type)
    }

    /// The row whose handle sits under a point — the margin gutter on the side the
    /// writing hand is not resting on. Any touch may pick a row here; it is the one
    /// place a finger selects (§11.11, v3.2).
    func handleRow(at point: CGPoint) -> Int? {
        let inset = Tokens.Layout.surfaceInset
        let inGutter = handlesOnRight ? point.x >= bounds.width - inset : point.x <= inset
        guard inGutter, let row = maskRenderer.layout.lineIndex(at: point),
              !(maskRenderer.layout.scorableByLine[row] ?? []).isEmpty else { return nil }
        return row
    }

    /// Past the last word — below the last line, or to its right on that line — where
    /// the ABC tool adds more words.
    func pointIsAfterText(_ point: CGPoint) -> Bool {
        guard let last = maskRenderer.layout.glyphBoxes.last else { return false }
        if point.y > last.rect.maxY + 8 { return true }
        return maskRenderer.layout.lineIndex(at: point) == last.lineIndex && point.x > last.rect.maxX
    }

    /// The word under a point, if its text can still be changed: spoken, on a row with no
    /// ink, and with no inked row below it (§11.13).
    private func editableWord(at point: CGPoint) -> (word: Int, range: ClosedRange<Int>, rect: CGRect)? {
        guard let row = maskRenderer.layout.lineIndex(at: point), wordIsEditable(onRow: row) else { return nil }
        return maskRenderer.layout.word(at: point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if Self.isHand(touch) { ignoredTouch = touch; return }
        let point = touch.location(in: self)

        // The ABC tool: any touch picks a spoken word to fix — a drag picks a run — or
        // the space after the last word to add more. Nothing here writes.
        if isTextEditActive {
            if let word = editableWord(at: point) {
                dragAnchor = word.range
                dragRange = word.range
                Haptics.tap()
                setNeedsDisplay()
            } else if pointIsAfterText(point) {
                pendingAppendTap = point
            }
            return
        }

        if isEraserActive, drawingTouch(touch) {
            eraserCentre = point
            applyErase(at: point)
            setNeedsDisplay()
            return
        }

        // The crayon: a drawing touch doodles wherever it lands. It selects nothing and
        // is attributed to nothing.
        if isDoodleActive {
            if drawingTouch(touch) { beginStroke(at: touch, layer: .doodle) }
            return
        }

        // Ink lands on the selected row. Its band is judged generously — descenders and
        // a child's overshoot both cross the printed band.
        if drawingTouch(touch), let row = selectedRow, pointIsOnBand(point, row: row) {
            beginStroke(at: touch)
            return
        }

        // The handle in the margin: a tap picks that row, finger or pen.
        if let row = handleRow(at: point) {
            pendingTap = PendingTap(row: row, start: point, began: CACurrentMediaTime(),
                                    canDraw: drawingTouch(touch), selectsOnTap: true)
            return
        }

        // On the words: the pencil picks a row with a tap and writes on it with a move.
        // A finger picks nothing here — a hand set down to write is the reason — unless
        // it is the writing finger, and then only a moving finger writes.
        guard let row = maskRenderer.layout.lineIndex(at: point),
              !(maskRenderer.layout.scorableByLine[row] ?? []).isEmpty,
              drawingTouch(touch) else { return }
        pendingTap = PendingTap(row: row, start: point, began: CACurrentMediaTime(),
                                canDraw: true, selectsOnTap: touch.type == .pencil)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if touch === ignoredTouch { return }
        let point = touch.location(in: self)

        // Dragging out a run of words. Anything the drag cannot reach — written text, the
        // row in hand, the gaps between lines — simply leaves the run where it was.
        if let anchor = dragAnchor {
            if let word = editableWord(at: point) {
                let low = min(anchor.lowerBound, word.range.lowerBound)
                let high = max(anchor.upperBound, word.range.upperBound)
                dragRange = low...high
                setNeedsDisplay()
            }
            return
        }

        if let start = pendingAppendTap {
            if hypot(point.x - start.x, point.y - start.y) > Self.tapSlop { pendingAppendTap = nil }
            return
        }

        if let pending = pendingTap {
            if hypot(point.x - pending.start.x, point.y - pending.start.y) > Self.tapSlop {
                pendingTap = nil
                // A moving pen is writing, wherever it started — select and ink.
                if pending.canDraw {
                    selectRow(pending.row)
                    beginStroke(at: touch)
                }
            }
            return
        }
        if isEraserActive, drawingTouch(touch) {
            eraserCentre = point
            applyErase(at: point)
        } else if current != nil {
            for coalesced in event?.coalescedTouches(for: touch) ?? [touch] { add(coalesced) }
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first, touch === ignoredTouch { ignoredTouch = nil; return }
        if dragAnchor != nil {
            dragAnchor = nil
            if let range = dragRange { onEditWord?(range, wordText(range)) }
            return
        }
        if pendingAppendTap != nil {
            pendingAppendTap = nil
            onAppendRequested?()
            return
        }
        if let pending = pendingTap {
            pendingTap = nil
            if pending.selectsOnTap {
                selectRow(pending.row)
                Haptics.tap()
            }
            return
        }
        endStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        ignoredTouch = nil
        pendingTap = nil
        pendingAppendTap = nil
        dragAnchor = nil
        dragRange = nil
        endStroke()
    }

    private static let tapSlop: CGFloat = 12

    private func pointIsOnBand(_ point: CGPoint, row: Int) -> Bool {
        guard let band = maskRenderer.layout.rect(forLine: row) else { return false }
        let spacing = maskRenderer.layout.lineSpacing
        let top = band.minY - 14
        let bottom = band.maxY + max(14, spacing * 0.2)
        return point.y >= top && point.y <= bottom
    }

    /// A word can be fixed only while its text is not under anyone's ink: the row has no
    /// ink, and no inked row sits below it — reflowing a traced row out from under its
    /// strokes is the one thing an edit must never do.
    private func wordIsEditable(onRow row: Int) -> Bool {
        guard !rowHasAnyInk(row) else { return false }
        return !maskRenderer.layout.scorableByLine.keys.contains { $0 > row && rowHasAnyInk($0) }
    }

    private func wordText(_ range: ClosedRange<Int>) -> String {
        let characters = Array(text)
        guard range.lowerBound >= 0, range.upperBound < characters.count else { return "" }
        return String(characters[range.lowerBound...range.upperBound])
    }

    private func beginStroke(at touch: UITouch, layer: TracingStroke.Layer = .ink) {
        current = TracingStroke(layer: layer, crayon: UInt8(clamping: crayon))
        add(touch)
        setNeedsDisplay()
    }

    private func add(_ touch: UITouch) {
        guard current != nil else { return }
        let location = touch.location(in: self)
        let force: CGFloat = touch.type == .pencil && touch.maximumPossibleForce > 0
            ? min(1, touch.force / touch.maximumPossibleForce)
            : 0.55
        if current?.isDoodle == true {
            // A doodle is attributed to nothing and scored against nothing.
            current?.append(StrokePoint(location: location, force: force, isInside: false, letterIndex: -1))
            return
        }
        // Ink scores only against the selected row — a stray wobble two rows down must
        // not put ink on a word the child has not reached.
        let letter = maskRenderer.glyphIndex(at: location, onLine: selectedRow) ?? -1
        let inside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
        current?.append(StrokePoint(location: location, force: force, isInside: inside, letterIndex: letter))
        if letter >= 0 { tally.record(letter: letter, isInside: inside) }
    }

    private func endStroke() {
        let finished = current
        current = nil
        eraserCentre = nil
        if let finished, !finished.isEmpty {
            if finished.isDoodle {
                doodles.append(finished)
                doodlesChanged()
                return
            }
            strokes.append(finished)
            retally(penUpOn: word(of: finished))
            onInkChange?()
            maybeAdvance()
            return
        }
        reportProgress()
        setNeedsDisplay()
    }

    /// Appends ink as if drawn — attributed against the selected row exactly the way a
    /// touch would be. The programmatic path used by previews and tests.
    func addInk(_ new: [TracingStroke]) {
        for var stroke in new {
            for i in stroke.points.indices {
                let location = stroke.points[i].location
                stroke.points[i].letterIndex = maskRenderer.glyphIndex(at: location, onLine: selectedRow) ?? -1
                stroke.points[i].isInside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
            }
            if !stroke.isEmpty { strokes.append(stroke) }
        }
        retally(penUpOn: strokes.last.flatMap { word(of: $0) })
        onInkChange?()
        maybeAdvance()
    }

    /// Appends doodles as if drawn with the crayon — attributed to nothing, scored against
    /// nothing. The programmatic path used by tests.
    func addDoodle(_ new: [TracingStroke], crayon: Int = 0) {
        for var stroke in new where !stroke.isEmpty {
            stroke.layer = .doodle
            stroke.crayon = UInt8(clamping: crayon)
            for i in stroke.points.indices {
                stroke.points[i].letterIndex = -1
                stroke.points[i].isInside = false
            }
            doodles.append(stroke)
        }
        doodlesChanged()
    }

    /// The word a stroke was written on — that of the first letter it touched.
    private func word(of stroke: TracingStroke) -> Int? {
        let boxes = maskRenderer.layout.glyphBoxes
        guard let point = stroke.points.first(where: { $0.letterIndex >= 0 }),
              boxes.indices.contains(point.letterIndex) else { return nil }
        return boxes[point.letterIndex].wordIndex
    }

    // MARK: - Scoring and the record

    /// `penUpOn` is the word the stroke that caused this landed on, when a pen-up did.
    private func retally(penUpOn word: Int? = nil) {
        let boxes = maskRenderer.layout.glyphBoxes
        adoptPendingRemediations(boxes: boxes)
        var fresh = ScoringEngine.Tally(wordOfLetter: boxes.map(\.wordIndex),
                                        scorable: boxes.map(\.isScorable),
                                        alphanumeric: boxes.map(\.isAlphanumeric),
                                        totalWords: maskRenderer.layout.wordCount)
        for stroke in strokes {
            for point in stroke.points where point.letterIndex >= 0 {
                fresh.record(letter: point.letterIndex, isInside: point.isInside)
            }
        }
        applyFormationOrder(to: &fresh, boxes: boxes)
        tally = fresh
        detectFormationHelp(boxes: boxes, penUpOn: word)
        recomputeRecord()
        redrawCommitted()
        reportProgress()
        setNeedsDisplay()
    }

    /// §8.1a — letters whose ink clearly took the wrong path (parts out of the taught
    /// order, or against their taught direction) take the order discount. The judge
    /// caches per-letter verdicts, so only letters whose ink changed are re-judged.
    /// A letter the child remediated in the help modal (§8.1b) is not re-docked. The
    /// same reading says which letters are fully covered — every part of their
    /// formation visited — which is what the help prompt waits for.
    private func applyFormationOrder(to tally: inout ScoringEngine.Tally,
                                     boxes: [MaskRenderer.GlyphBox]) {
        coveredLetters = []
        guard let judge = orderJudge else { return }
        for (letter, penPaths) in FormationOrderJudge.penPathsByLetter(in: strokes) {
            guard boxes.indices.contains(letter), boxes[letter].isScorable else { continue }
            let signature = FormationOrderJudge.signature(of: penPaths, box: boxes[letter])
            let analysis = judge.analysis(penPaths: penPaths, glyph: letter,
                                          box: boxes[letter], signature: signature)
            // No formation (punctuation): nothing to cover, nothing to dock.
            if analysis?.coveredAllStrokes != false { coveredLetters.insert(letter) }
            if analysis?.followed == false, !remediatedLetters.contains(letter) {
                tally.markOrder(letter: letter, followed: false)
            }
        }
    }

    // MARK: - Formation help (§8.1b)

    /// Offers help for a word that is complete with letters that took the order
    /// discount — but not before the child is done with it.
    ///
    /// A word reads as complete the moment its last letter has *any* ink, and a letter
    /// with several parts gets its first part first: the stem of a `t` completes the
    /// word before the crossbar exists, and a modal there would cover a letter the
    /// child was about to finish. So a qualifying word waits in `pendingHelpWords`
    /// until either every inked letter of it is fully covered — every part of every
    /// formation visited — or the child's pen lands on some other word, which is the
    /// child saying they are done with this one. Each word asks at most once per
    /// sitting, and only a word completed under the child's own pen ever asks: a page
    /// restored from its archive arrives with its words already written.
    private func detectFormationHelp(boxes: [MaskRenderer.GlyphBox], penUpOn penWord: Int?) {
        guard orderJudge != nil else { return }
        var glyphsOfWord: [Int: [Int]] = [:]
        for (i, box) in boxes.enumerated() where box.isScorable {
            glyphsOfWord[box.wordIndex, default: []].append(i)
        }
        let completed = Set(glyphsOfWord.filter { _, glyphs in
            glyphs.allSatisfy { tally.hasInk(letter: $0) }
        }.keys)
        let newly = completed.subtracting(knownCompletedWords)
        knownCompletedWords = completed
        if suppressHelpPrompts { suppressHelpPrompts = false; return }

        // A word undone back to incomplete waits to be completed again.
        pendingHelpWords.formUnion(newly.subtracting(promptedWords))
        pendingHelpWords.formIntersection(completed)

        for word in pendingHelpWords.sorted() {
            guard let glyphs = glyphsOfWord[word] else { pendingHelpWords.remove(word); continue }
            let finished = glyphs.allSatisfy { coveredLetters.contains($0) }
            let movedOn = penWord != nil && penWord != word
            guard finished || movedOn else { continue }
            pendingHelpWords.remove(word)
            promptedWords.insert(word)
            let letters = glyphs.enumerated().compactMap { offset, glyph -> FormationHelpRequest.Letter? in
                guard !tally.followedOrder[glyph] else { return nil }
                return FormationHelpRequest.Letter(glyph: glyph,
                                                   charIndex: boxes[glyph].charIndex,
                                                   offset: offset,
                                                   character: boxes[glyph].character)
            }
            guard !letters.isEmpty else { continue }
            let text = String(glyphs.map { boxes[$0].character })
            onFormationHelpNeeded?(FormationHelpRequest(word: word, wordText: text, letters: letters))
        }
    }

    /// The child traced this letter correctly in the help modal — its order discount is
    /// lifted for the life of the entry, and the tally re-derives without it.
    func markRemediated(letter: Int) {
        remediatedLetters.insert(letter)
        retally()
    }

    /// Remediations carried on the session, put back when the page reopens. Applied
    /// once the layout exists, by character position — glyph indices are not stable
    /// across sittings, character positions of the record are.
    func restoreRemediated(charIndices: [Int]) {
        guard !charIndices.isEmpty else { return }
        pendingRemediatedChars = (pendingRemediatedChars ?? []) + charIndices
        if !maskRenderer.layout.glyphBoxes.isEmpty { retally() }
    }

    private func adoptPendingRemediations(boxes: [MaskRenderer.GlyphBox]) {
        guard let chars = pendingRemediatedChars, !boxes.isEmpty else { return }
        pendingRemediatedChars = nil
        let wanted = Set(chars)
        for (i, box) in boxes.enumerated() where wanted.contains(box.charIndex) {
            remediatedLetters.insert(i)
        }
    }

    /// Where a glyph sits in the page text — what the session stores for a remediation.
    func charIndex(ofGlyph glyph: Int) -> Int? {
        let boxes = maskRenderer.layout.glyphBoxes
        guard boxes.indices.contains(glyph) else { return nil }
        return boxes[glyph].charIndex
    }

    /// The record is the unbroken run of fully-traced rows from the top of the page —
    /// derived from the ink, and re-derived identically from a restored archive.
    private func recomputeRecord() {
        var end = 0
        for row in 0..<maskRenderer.layout.lineCount {
            guard let indices = maskRenderer.layout.scorableByLine[row], !indices.isEmpty else { continue }
            guard indices.allSatisfy({ tally.hasInk(letter: $0) }) else { break }
            if let e = maskRenderer.layout.endCharIndex(ofLine: row) { end = max(end, e) }
        }
        recordEnd = end
        if end != lastEmittedRecord {
            lastEmittedRecord = end
            onRecordChange?(end)
        }
    }

    private func reportProgress() {
        // Words written = words with any ink, wherever they sit on the page.
        var words: Set<Int> = []
        for (i, box) in maskRenderer.layout.glyphBoxes.enumerated() where box.isScorable {
            if tally.hasInk(letter: i) { words.insert(box.wordIndex) }
        }
        onProgress?(tally.liveAccuracy, words.count, selectedRowHasInk)
        onPageState?(!strokes.isEmpty, !doodles.isEmpty)
    }

    // MARK: - The settle (§11.10 — on deselection, not on a sensor)

    private func settle(_ row: Int) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        settling[row] = 0
        startSettleLink()
        Haptics.settle()
    }

    private func startSettleLink() {
        guard settleLink == nil else { return }
        lastTick = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tickSettle))
        link.add(to: .main, forMode: .common)
        settleLink = link
    }

    private func stopSettleLink() {
        settleLink?.invalidate()
        settleLink = nil
    }

    @objc private func tickSettle() {
        let now = CACurrentMediaTime()
        let step = CGFloat(min(0.1, now - lastTick) / Tokens.Motion.settle)
        lastTick = now

        var finished = false
        var touched: [CGRect] = []
        for (row, progress) in settling {
            if let band = maskRenderer.layout.rect(forLine: row) { touched.append(band) }
            let next = progress + step
            if next >= 1 { settling[row] = nil; finished = true } else { settling[row] = next }
        }
        if finished { redrawCommitted() }       // the row is graphite for good now
        if settling.isEmpty { stopSettleLink() }
        // Only the settling rows changed, and the page can be thousands of points tall.
        for band in touched { setNeedsDisplay(band.insetBy(dx: 0, dy: -8)) }
    }

    // MARK: - Ink colour per row

    private struct Palette {
        let inside: UIColor
        let outside: UIColor
    }

    private static let naturalPalette = Palette(inside: UIColor(Tokens.Colour.inkNatural),
                                                outside: UIColor(Tokens.Colour.inkNatural))

    private var accuracyPalette: Palette {
        Palette(inside: UIColor(colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside),
                outside: UIColor(colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside))
    }

    private func settledPalette(for row: Int?) -> Palette {
        guard let row else { return accuracyPalette }
        return row == selectedRow ? accuracyPalette : Self.naturalPalette
    }

    private func blendedPalette(progress: CGFloat) -> Palette {
        let accuracy = accuracyPalette
        return Palette(inside: Self.blend(accuracy.inside, Self.naturalPalette.inside, progress),
                       outside: Self.blend(accuracy.outside, Self.naturalPalette.outside, progress))
    }

    private static func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = max(0, min(1, t))
        return UIColor(red: ar + (br - ar) * k, green: ag + (bg - ag) * k,
                       blue: ab + (bb - ab) * k, alpha: aa + (ba - aa) * k)
    }

    // MARK: - Drawing

    /// Everything except the rows currently settling, which are redrawn live so their
    /// colour can be interpolated frame by frame.
    private func redrawCommitted() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = min(2, UIScreen.main.scale)
        let settlingRows = Set(settling.keys)
        committedImage = UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
            draw(strokes: strokes, in: ctx.cgContext) { [weak self] row in
                guard let self else { return nil }
                if let row, settlingRows.contains(row) { return nil }
                return self.settledPalette(for: row)
            }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if showGuideLines { drawRuledLines(in: ctx, clip: rect) }

        if showGuideText {
            // The three row states: black on the selected row, faint grey under settled
            // ink, light grey for everything still waiting.
            let guide = UIColor(Tokens.Colour.guideText)
            let spoken = UIColor(Tokens.Colour.spokenText)
            let faint = Self.tracedGuideAlpha
            maskRenderer.drawGuide(in: ctx) { [weak self] row in
                guard let self else { return nil }
                if let progress = self.settling[row] { return (guide, 1 - progress * (1 - faint)) }
                if row == self.selectedRow { return (guide, 1) }
                if self.rowHasAnyInk(row) { return (guide, faint) }
                return (spoken, 1)
            }
        }

        // The crayon layer sits under the handwriting, multiplied so the letters read
        // through it (§4.4, v3.2). The doodle in hand is drawn with it.
        let widthScale = setup.size.size / 72
        Crayon.draw(doodles, in: ctx, widthScale: widthScale)
        if let live = current, live.isDoodle { Crayon.draw([live], in: ctx, widthScale: widthScale) }

        committedImage?.draw(at: .zero)

        if !settling.isEmpty {
            let settlingNow = settling
            draw(strokes: strokes, in: ctx) { [weak self] row in
                guard let self, let row, let progress = settlingNow[row] else { return nil }
                return self.blendedPalette(progress: progress)
            }
        }

        if let live = current, !live.isDoodle {
            let palette = accuracyPalette
            draw(strokes: [live], in: ctx) { _ in palette }
        }

        if let range = dragRange ?? editingRange { drawEditingBox(range, in: ctx) }
        if isDictating { drawCaret(in: ctx) }

        if isEraserActive, let centre = eraserCentre {
            let circle = CGRect(x: centre.x - StrokeEraser.radius, y: centre.y - StrokeEraser.radius,
                                width: StrokeEraser.radius * 2, height: StrokeEraser.radius * 2)
            ctx.setFillColor(UIColor(Tokens.Colour.paperSunk).withAlphaComponent(0.7).cgColor)
            ctx.fillEllipse(in: circle)
            ctx.setStrokeColor(UIColor(Tokens.Colour.textSecondary).cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.strokeEllipse(in: circle)
            ctx.setLineDash(phase: 0, lengths: [])
        }

        drawHandles(in: ctx)
    }

    /// §11.11 (v3.2) — every row with letters carries a handle in the margin gutter: a
    /// faint dot, or the pencil on the row in hand. It is what a finger taps to pick a
    /// row, and it says where the child is.
    private func drawHandles(in ctx: CGContext) {
        let inset = Tokens.Layout.surfaceInset
        let cx = handlesOnRight ? bounds.width - inset / 2 : inset / 2
        for (row, indices) in maskRenderer.layout.scorableByLine where !indices.isEmpty {
            guard let band = maskRenderer.layout.rect(forLine: row) else { continue }
            let cy = band.midY
            if row == selectedRow {
                let size: CGFloat = 22
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                if let marker = UIImage(systemName: "pencil.line", withConfiguration: config)?
                    .withTintColor(UIColor(Tokens.Colour.action), renderingMode: .alwaysOriginal) {
                    marker.draw(in: CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size))
                }
            } else {
                ctx.setFillColor(UIColor.black.withAlphaComponent(0.15).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
            }
        }
    }

    /// §11.13 — the spoken word being fixed.
    private func drawEditingBox(_ range: ClosedRange<Int>, in ctx: CGContext) {
        let boxes = maskRenderer.layout.glyphBoxes.filter { range.contains($0.charIndex) }
        guard let first = boxes.first else { return }
        let rect = boxes.dropFirst().reduce(first.rect) { $0.union($1.rect) }.insetBy(dx: -8, dy: -6)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: Tokens.Radius.chip)
        ctx.setFillColor(UIColor(Tokens.Colour.action).withAlphaComponent(0.10).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(UIColor(Tokens.Colour.action).cgColor)
        ctx.setLineWidth(Tokens.Stroke.emphasis)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
    }

    /// While listening, the next word will land here.
    private func drawCaret(in ctx: CGContext) {
        guard let last = maskRenderer.layout.glyphBoxes.last else { return }
        let rect = CGRect(x: last.rect.maxX + 8, y: last.rect.minY + 4, width: 3,
                          height: max(20, last.rect.height - 8))
        ctx.setFillColor(UIColor(Tokens.Colour.action).cgColor)
        ctx.fill(rect)
    }

    /// §11.2 — three rules per line, only the baseline solid. The child aims for the
    /// solid line. Ruled lines run the whole page: it is a page, not a caption.
    ///
    /// The rules are drawn from the baselines CoreText actually produced, not recomputed
    /// from the tokens. They are the thing the child aims at, so they must sit under the
    /// letters by construction rather than by two calculations agreeing.
    private func drawRuledLines(in ctx: CGContext, clip: CGRect) {
        let size = setup.size
        let inset = Tokens.Layout.surfaceInset
        let width = bounds.width - inset * 2
        guard width > 0 else { return }

        ctx.setStrokeColor(UIColor(Tokens.Colour.ruleLine).cgColor)
        ctx.setLineWidth(1)

        let measured = maskRenderer.layout.lineSpacing
        let advance = measured > 1 ? measured : MaskRenderer.lineAdvance(for: setup)
        var baseline = maskRenderer.layout.baselines.first ?? (Tokens.Space.s7 + size.ascent)
        var index = 0
        while baseline + size.descent < bounds.height {
            // Past the written text the page keeps ruling itself, because more dictation
            // can always be appended to it.
            if index < maskRenderer.layout.baselines.count {
                baseline = maskRenderer.layout.baselines[index]
            }
            if baseline + advance >= clip.minY && baseline - size.ascent <= clip.maxY {
                ctx.setLineDash(phase: 0, lengths: [6, 4])
                line(ctx, y: baseline - size.ascent, x: inset, width: width)
                line(ctx, y: baseline + size.descent, x: inset, width: width)
                ctx.setLineDash(phase: 0, lengths: [])
                line(ctx, y: baseline, x: inset, width: width)
            }
            index += 1
            if index >= maskRenderer.layout.baselines.count { baseline += advance }
        }
        ctx.setLineDash(phase: 0, lengths: [])
    }

    private func line(_ ctx: CGContext, y: CGFloat, x: CGFloat, width: CGFloat) {
        ctx.move(to: CGPoint(x: x, y: y.rounded() + 0.5))
        ctx.addLine(to: CGPoint(x: x + width, y: y.rounded() + 0.5))
        ctx.strokePath()
    }

    /// `palette` is asked once per segment, given the row that segment sits on.
    /// Returning nil skips the segment, which is how a pass draws only some of the page.
    private func draw(strokes list: [TracingStroke],
                      in ctx: CGContext,
                      palette: (Int?) -> Palette?) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let range = widthRange

        for stroke in list where stroke.points.count > 1 {
            for i in 1..<stroke.points.count {
                let a = stroke.points[i - 1], b = stroke.points[i]
                guard let colours = palette(lineOf(b)) else { continue }
                let force = (a.force + b.force) / 2
                ctx.setLineWidth(range.lowerBound + (range.upperBound - range.lowerBound) * force)
                ctx.setStrokeColor((b.isInside ? colours.inside : colours.outside).cgColor)
                ctx.move(to: a.location)
                ctx.addLine(to: b.location)
                ctx.strokePath()
            }
        }
    }
}
