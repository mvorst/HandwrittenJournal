import SwiftUI
import UIKit

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
    /// While dictating the mask is skipped (nobody can trace yet — selecting a row stops
    /// the mic) and a caret marks where the next word will land.
    var isDictating = false {
        didSet {
            guard isDictating != oldValue else { return }
            if !isDictating { rebuild(revalidate: true) }   // bring the mask back
            setNeedsDisplay()
        }
    }
    /// The character range of a spoken word being fixed — drawn as an action box.
    var editingRange: ClosedRange<Int>? { didSet { setNeedsDisplay() } }

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

    // MARK: - State

    private(set) var strokes: [TracingStroke] = []
    private(set) var tally = ScoringEngine.Tally(letterCount: 0)
    private let maskRenderer = MaskRenderer()
    private var current: TracingStroke?
    private var committedImage: UIImage?
    private var eraserCentre: CGPoint?
    private var builtForSize: CGSize = .zero
    private var builtForText = ""
    private var pendingRestore: [TracingStroke]?

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
    }
    private var pendingTap: PendingTap?

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
            strokes.removeAll()
            current = nil
            selectedRow = nil
            settling = [:]
            stopSettleLink()
        }
        if let row = selectedRow, (maskRenderer.layout.scorableByLine[row] ?? []).isEmpty {
            selectedRow = nil
        }
        retally()
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
    }

    private func clearForEmptyText() {
        strokes.removeAll()
        current = nil
        selectedRow = nil
        settling = [:]
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

    // MARK: - Restoring an earlier sitting

    /// Puts an archived tracing back on the page. The record re-derives from the ink, so
    /// a restored page reports the same boundary it was saved with.
    func restore(_ archived: [TracingStroke]) {
        pendingRestore = archived
        if !maskRenderer.layout.glyphBoxes.isEmpty { applyRestore(); retally() }
    }

    private func applyRestore() {
        guard let restored = pendingRestore else { return }
        pendingRestore = nil
        strokes = restored
        current = nil
        selectedRow = nil
        settling = [:]
        reattribute()
    }

    /// Recomputes every point's letter and inside-ness against the current mask.
    /// Only needed on restore — appends and gated edits cannot move inked glyphs.
    private func reattribute() {
        for s in strokes.indices {
            for p in strokes[s].points.indices {
                let location = strokes[s].points[p].location
                strokes[s].points[p].letterIndex = maskRenderer.glyphIndex(at: location) ?? -1
                strokes[s].points[p].isInside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
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

    func archive() throws -> Data { try StrokeArchive.encode(strokes) }

    /// Always natural ink — a thumbnail is journal furniture, never a marked-up test.
    func thumbnail(width: CGFloat = 320) -> Data? {
        guard bounds.width > 0, !strokes.isEmpty else { return nil }
        var ink = strokes[0].bounds()
        for stroke in strokes.dropFirst() { ink = ink.union(stroke.bounds()) }
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
            draw(strokes: strokes, in: ctx.cgContext) { _ in Self.naturalPalette }
        }.pngData()
    }

    // MARK: - Tools (scoped to the selected row)

    func undo() {
        guard let row = selectedRow,
              let index = strokes.lastIndex(where: { self.row(of: $0) == row }) else { return }
        strokes.remove(at: index)
        retally()
    }

    func clearSelected() {
        guard let row = selectedRow else { return }
        let remaining = strokes.filter { self.row(of: $0) != row }
        guard remaining.count != strokes.count else { return }
        strokes = remaining
        current = nil
        retally()
    }

    private func applyErase(at point: CGPoint) {
        guard let row = selectedRow else { return }
        let mine = strokes.filter { self.row(of: $0) == row }
        guard !mine.isEmpty else { return }
        let others = strokes.filter { self.row(of: $0) != row }
        let result = StrokeEraser.erase(at: point, from: mine)
        guard result.strokes.count != mine.count || !result.touchedLetters.isEmpty else { return }
        strokes = others + result.strokes
        retally()
    }

    var selectedRowHasInk: Bool {
        guard let row = selectedRow else { return false }
        return rowHasAnyInk(row)
    }

    // MARK: - Touches

    private func drawingTouch(_ touch: UITouch) -> Bool {
        allowFinger || touch.type == .pencil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if isEraserActive, drawingTouch(touch) {
            eraserCentre = point
            applyErase(at: point)
            setNeedsDisplay()
            return
        }

        // Ink lands on the selected row. Its band is judged generously — descenders and
        // a child's overshoot both cross the printed band.
        if drawingTouch(touch), let row = selectedRow, pointIsOnBand(point, row: row) {
            beginStroke(at: touch)
            return
        }

        // Anywhere else: a tap selects the row it lands on — any row, any time. A pen
        // that starts moving becomes ink on that row; a held finger opens a word for
        // fixing.
        guard let row = maskRenderer.layout.lineIndex(at: point),
              !(maskRenderer.layout.scorableByLine[row] ?? []).isEmpty else { return }
        pendingTap = PendingTap(row: row, start: point, began: CACurrentMediaTime(),
                                canDraw: drawingTouch(touch))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

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
        if let pending = pendingTap {
            pendingTap = nil
            // A held touch on an editable word opens it for fixing; a tap selects.
            if CACurrentMediaTime() - pending.began > 0.5,
               wordIsEditable(onRow: pending.row),
               let touch = touches.first,
               let word = maskRenderer.layout.word(at: touch.location(in: self)) {
                onEditWord?(word.range, wordText(word.range))
            } else {
                selectRow(pending.row)
                Haptics.tap()
            }
            return
        }
        endStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pendingTap = nil
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

    private func beginStroke(at touch: UITouch) {
        current = TracingStroke()
        add(touch)
        setNeedsDisplay()
    }

    private func add(_ touch: UITouch) {
        guard current != nil else { return }
        let location = touch.location(in: self)
        let force: CGFloat = touch.type == .pencil && touch.maximumPossibleForce > 0
            ? min(1, touch.force / touch.maximumPossibleForce)
            : 0.55
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
            strokes.append(finished)
            retally()
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
        retally()
        maybeAdvance()
    }

    // MARK: - Scoring and the record

    private func retally() {
        let boxes = maskRenderer.layout.glyphBoxes
        var fresh = ScoringEngine.Tally(wordOfLetter: boxes.map(\.wordIndex),
                                        scorable: boxes.map(\.isScorable),
                                        totalWords: maskRenderer.layout.wordCount)
        for stroke in strokes {
            for point in stroke.points where point.letterIndex >= 0 {
                fresh.record(letter: point.letterIndex, isInside: point.isInside)
            }
        }
        tally = fresh
        recomputeRecord()
        redrawCommitted()
        reportProgress()
        setNeedsDisplay()
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

        committedImage?.draw(at: .zero)

        if !settling.isEmpty {
            let settlingNow = settling
            draw(strokes: strokes, in: ctx) { [weak self] row in
                guard let self, let row, let progress = settlingNow[row] else { return nil }
                return self.blendedPalette(progress: progress)
            }
        }

        if let live = current {
            let palette = accuracyPalette
            draw(strokes: [live], in: ctx) { _ in palette }
        }

        if let range = editingRange { drawEditingBox(range, in: ctx) }
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
