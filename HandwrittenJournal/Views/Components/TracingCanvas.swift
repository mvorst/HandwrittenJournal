import SwiftUI
import UIKit

/// The writing surface — one continuous scrolling page. WIREFRAME_SPEC.md §11.
///
/// Every line of the page is in exactly one of three states (§11.11):
///
/// | State | Guide | Ink |
/// |---|---|---|
/// | **Graded** — every letter written | removed | `ink-natural` |
/// | **In hand** — being written now | shown | accuracy colours |
/// | **Untraced** — not reached yet | shown | none |
///
/// Dropping the guide out from under a finished line is what makes the page read as the
/// child's own handwriting rather than a half-finished worksheet, and it is what makes
/// tap-to-re-trace legible: a line with no guide under it is a line you have written.
final class TracingCanvasView: UIView {

    // MARK: - Configuration

    var text: String = "" { didSet { if text != oldValue { rebuild() } } }
    var setup: WritingSetup = .default { didSet { if setup != oldValue { rebuild(force: true) } } }
    var showGuideLines = true { didSet { setNeedsDisplay() } }
    var showGuideText = true { didSet { setNeedsDisplay() } }
    var colourBlind = false { didSet { redrawCommitted() } }
    var allowFinger = true
    var isEraserActive = false {
        didSet {
            eraserCentre = nil
            if isEraserActive { select(nil) }   // one mode at a time
            setNeedsDisplay()
        }
    }

    var onProgress: ((_ liveAccuracy: Double, _ wordsWritten: Int, _ hasInk: Bool) -> Void)?
    /// Fires when the layout changes so the scroll view can resize its content.
    var onLayoutChange: ((CGFloat) -> Void)?
    /// Fires when a graded line is cleared for re-tracing, so the page can scroll to it.
    var onRetrace: ((Int) -> Void)?

    // MARK: - State

    private(set) var strokes: [TracingStroke] = []
    private(set) var tally = ScoringEngine.Tally(letterCount: 0)
    private let maskRenderer = MaskRenderer()
    private var current: TracingStroke?
    private var committed: UIImage?
    private var eraserCentre: CGPoint?
    private var builtForSize: CGSize = .zero
    private var builtForText = ""
    private var pendingRestore: [TracingStroke]?

    /// Glyph index -> line, so a stroke point can be coloured without a lookup per segment.
    private var lineOfGlyph: [Int] = []

    /// Lines whose every letter has ink. Not necessarily a prefix: re-tracing a line in
    /// the middle of the page takes it out of this set while the lines after it stay in.
    private(set) var gradedLines: Set<Int> = []
    /// Lines mid-settle, 0…1. Their guide is fading and their ink is turning to graphite.
    private var settling: [Int: CGFloat] = [:]
    private var settleLink: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    private(set) var selectedLine: Int?
    private var chipRect: CGRect = .zero
    private var pendingTap: (line: Int, start: CGPoint)?

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
        // Height matters as much as width: appending words makes the page taller, and the
        // frame the mask is built in clips anything past its own bounds. Rebuilding only
        // on a width change left the new lines laid out but unreachable.
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

    /// `force` wipes the ink. Plain rebuilds keep it, because the common case is the
    /// child saying more and the new words being appended to the page they are on.
    private func rebuild(force: Bool = false) {
        guard bounds.width > 0, bounds.height > 0, !text.isEmpty else { return }

        // Greedy word wrap is prefix-stable: appending words cannot move a word that is
        // already on the page, so every stroke stays exactly where the child drew it.
        let isAppend = !force && !builtForText.isEmpty && text.hasPrefix(builtForText)
            && abs(bounds.width - builtForSize.width) < 0.5
        builtForSize = bounds.size
        builtForText = text

        // A very long entry makes a very tall bitmap; drop to 1x rather than allocate
        // tens of megabytes for a mask nobody looks at closely.
        let pixels = bounds.width * bounds.height * 4
        let scale: CGFloat = pixels > 40_000_000 ? 1 : min(2, UIScreen.main.scale)

        maskRenderer.generate(text: text, setup: setup, canvasSize: bounds.size, screenScale: scale)
        lineOfGlyph = maskRenderer.layout.glyphBoxes.map(\.lineIndex)

        if pendingRestore != nil {
            applyRestore()
        } else if isAppend {
            reattribute()               // the mask is new; the ink must be re-scored against it
        } else {
            strokes.removeAll()
            current = nil
            gradedLines = []
            settling = [:]
            stopSettleLink()
        }
        select(nil)
        retally(animateSettle: false)
        onLayoutChange?(bounds.height)
    }

    var layout: MaskRenderer.Layout { maskRenderer.layout }
    var scorableLetterCount: Int { maskRenderer.layout.scorableCount }

    /// Where the child has got to — the view scrolls here on resume.
    func rect(forWord word: Int) -> CGRect? { maskRenderer.layout.rect(forWord: word) }
    func rect(forLine line: Int) -> CGRect? { maskRenderer.layout.rect(forLine: line) }

    // MARK: - Restoring an earlier sitting

    /// Puts an archived tracing back on the page. Resuming an unfinished entry and
    /// tapping "Keep writing" both come through here — without it, finishing a resumed
    /// entry would record an empty page over the child's work.
    func restore(_ archived: [TracingStroke]) {
        pendingRestore = archived
        if !maskRenderer.layout.glyphBoxes.isEmpty { applyRestore(); retally(animateSettle: false) }
    }

    private func applyRestore() {
        guard let restored = pendingRestore else { return }
        pendingRestore = nil
        strokes = restored
        current = nil
        gradedLines = []
        settling = [:]
        reattribute()
    }

    /// Recomputes every point's letter and inside-ness against the current mask.
    ///
    /// Needed whenever the page changes under existing ink: restoring an archive, or
    /// appending new dictation, which re-lays-out the frame the strokes were scored on.
    private func reattribute() {
        for s in strokes.indices {
            for p in strokes[s].points.indices {
                let location = strokes[s].points[p].location
                strokes[s].points[p].letterIndex = maskRenderer.glyphIndex(at: location) ?? -1
                strokes[s].points[p].isInside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
            }
        }
    }

    // MARK: - Actions

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        retally()
    }

    func clearAll() {
        strokes.removeAll()
        current = nil
        retally()
    }

    func finish(streak: Int) -> ScoreResult { ScoringEngine.score(tally: tally, streak: streak) }
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

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, accepts(touch) else { return }
        let point = touch.location(in: self)

        if let line = selectedLine, chipRect.contains(point) {
            beginRetrace(of: line)
            return
        }
        if isEraserActive {
            eraserCentre = point
            applyErase(at: point)
            setNeedsDisplay()
            return
        }
        // A finished line is not something you draw on — it is something you tap to redo.
        if let line = maskRenderer.layout.lineIndex(at: point), gradedLines.contains(line) {
            pendingTap = (line, point)
            return
        }
        select(nil)
        current = TracingStroke()
        add(touch)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, accepts(touch) else { return }
        if let pending = pendingTap {
            // A drag that started on written work is a scroll attempt, not a tap.
            let moved = hypot(touch.location(in: self).x - pending.start.x,
                              touch.location(in: self).y - pending.start.y)
            if moved > Self.tapSlop { pendingTap = nil }
            return
        }
        if isEraserActive {
            eraserCentre = touch.location(in: self)
            applyErase(at: touch.location(in: self))
        } else {
            for coalesced in event?.coalescedTouches(for: touch) ?? [touch] { add(coalesced) }
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let pending = pendingTap {
            pendingTap = nil
            select(selectedLine == pending.line ? nil : pending.line)
            Haptics.tap()
            return
        }
        endStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pendingTap = nil
        endStroke()
    }

    private static let tapSlop: CGFloat = 12

    private func accepts(_ touch: UITouch) -> Bool { allowFinger || touch.type == .pencil }

    private func add(_ touch: UITouch) {
        guard current != nil else { return }
        let location = touch.location(in: self)
        let force: CGFloat = touch.type == .pencil && touch.maximumPossibleForce > 0
            ? min(1, touch.force / touch.maximumPossibleForce)
            : 0.55
        let letter = maskRenderer.glyphIndex(at: location) ?? -1
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
            retally()          // a finished stroke may have finished a line
            return
        }
        reportProgress()
        setNeedsDisplay()
    }

    private func applyErase(at point: CGPoint) {
        let result = StrokeEraser.erase(at: point, from: strokes)
        guard result.strokes.count != strokes.count || !result.touchedLetters.isEmpty else { return }
        strokes = result.strokes
        retally()
    }

    // MARK: - Selecting a line to write again

    /// Selecting is API rather than a private detail of touch handling: the page can be
    /// driven from a controller, and it is the only way to exercise §11.12 in a test.
    func selectLine(_ line: Int?) {
        guard line == nil || gradedLines.contains(line!) else { return }
        select(line)
    }

    /// Hands a graded line back to the child. The chip calls this; so can a test.
    func writeLineAgain(_ line: Int) { beginRetrace(of: line) }

    private func select(_ line: Int?) {
        guard selectedLine != line else { return }
        selectedLine = line
        if line == nil { chipRect = .zero }
        setNeedsDisplay()
    }

    /// Clears the line's ink and hands it back to the child in the in-hand state.
    ///
    /// The old tracing is discarded rather than archived: only the latest tracing is ever
    /// kept (DESIGN_DOCUMENT.md §5.5), so this replaces, and the entry's accuracy is
    /// recomputed from what is on the page now.
    private func beginRetrace(of line: Int) {
        guard let indices = maskRenderer.layout.scorableByLine[line], !indices.isEmpty else { return }
        strokes = removingLine(line, from: strokes)
        settling[line] = nil
        select(nil)
        retally(animateSettle: false)
        onRetrace?(line)
        Haptics.tap()
    }

    private func removingLine(_ line: Int, from list: [TracingStroke]) -> [TracingStroke] {
        var out: [TracingStroke] = []
        for stroke in list {
            var run = TracingStroke()
            for point in stroke.points {
                if lineOf(point) == line {
                    if !run.isEmpty { out.append(run) }
                    run = TracingStroke()
                } else {
                    run.append(point)
                }
            }
            if !run.isEmpty { out.append(run) }
        }
        return out
    }

    private func lineOf(_ point: StrokePoint) -> Int? {
        if point.letterIndex >= 0, point.letterIndex < lineOfGlyph.count {
            return lineOfGlyph[point.letterIndex]
        }
        return maskRenderer.layout.lineIndex(at: point.location)
    }

    // MARK: - Scoring and line state

    private func retally(animateSettle: Bool = true) {
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
        refreshLineStates(animateSettle: animateSettle)
    }

    private func refreshLineStates(animateSettle: Bool) {
        let graded = computeGradedLines()
        let newly = graded.subtracting(gradedLines)
        gradedLines = graded

        // A line that lost its ink — erased, undone, or handed back for re-tracing —
        // stops settling and gets its guide back.
        for line in settling.keys where !graded.contains(line) { settling[line] = nil }

        if animateSettle, !newly.isEmpty {
            if UIAccessibility.isReduceMotionEnabled {
                Haptics.settle()
            } else {
                for line in newly { settling[line] = 0 }
                startSettleLink()
                Haptics.settle()
            }
        }
        if let selected = selectedLine, !graded.contains(selected) { select(nil) }

        redrawCommitted()
        reportProgress()
        setNeedsDisplay()
    }

    private func computeGradedLines() -> Set<Int> {
        var out: Set<Int> = []
        for (line, indices) in maskRenderer.layout.scorableByLine where !indices.isEmpty {
            if indices.allSatisfy({ tally.hasInk(letter: $0) }) { out.insert(line) }
        }
        return out
    }

    private func reportProgress() {
        onProgress?(tally.liveAccuracy, tally.wordsWritten, !strokes.isEmpty)
    }

    // MARK: - The settle (§11.10)

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
        for (line, progress) in settling {
            if let band = maskRenderer.layout.rect(forLine: line) { touched.append(band) }
            let next = progress + step
            if next >= 1 { settling[line] = nil; finished = true } else { settling[line] = next }
        }
        if finished { redrawCommitted() }       // the line is graphite for good now
        if settling.isEmpty { stopSettleLink() }
        // Only the settling lines changed, and the page can be thousands of points tall.
        for line in touched { setNeedsDisplay(line.insetBy(dx: 0, dy: -8)) }
    }

    // MARK: - Ink colour per line

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

    /// The palette for a line that is not mid-settle: graphite once graded, accuracy
    /// colours while it is still in hand.
    private func settledPalette(for line: Int?) -> Palette {
        guard let line, gradedLines.contains(line) else { return accuracyPalette }
        return Self.naturalPalette
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

    /// Everything except the lines currently settling, which are redrawn live so their
    /// colour can be interpolated frame by frame.
    private func redrawCommitted() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = min(2, UIScreen.main.scale)
        let settlingLines = Set(settling.keys)
        committed = UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
            draw(strokes: strokes, in: ctx.cgContext) { [weak self] line in
                guard let self else { return nil }
                if let line, settlingLines.contains(line) { return nil }
                return self.settledPalette(for: line)
            }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if showGuideLines { drawRuledLines(in: ctx, clip: rect) }

        if showGuideText {
            // §11.11 — a graded line has no guide under it at all; a settling one fades.
            maskRenderer.drawGuide(in: ctx, colour: UIColor(Tokens.Colour.guideText)) { [weak self] line in
                guard let self else { return 1 }
                if let progress = self.settling[line] { return 1 - progress }
                return self.gradedLines.contains(line) ? 0 : 1
            }
        }

        committed?.draw(at: .zero)

        if !settling.isEmpty {
            let settlingNow = settling
            draw(strokes: strokes, in: ctx) { [weak self] line in
                guard let self, let line, let progress = settlingNow[line] else { return nil }
                return self.blendedPalette(progress: progress)
            }
        }

        if let live = current {
            let palette = accuracyPalette
            draw(strokes: [live], in: ctx) { _ in palette }
        }

        if let line = selectedLine { drawSelection(line, in: ctx) }

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

    /// §11.12 — the band, the outline and the chip that resolves the selection.
    private func drawSelection(_ line: Int, in ctx: CGContext) {
        guard let band = maskRenderer.layout.rect(forLine: line) else { return }
        let highlight = band.insetBy(dx: -8, dy: -6)
        let path = UIBezierPath(roundedRect: highlight, cornerRadius: Tokens.Radius.chip)
        ctx.setFillColor(UIColor(Tokens.Colour.action).withAlphaComponent(0.12).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(UIColor(Tokens.Colour.action).cgColor)
        ctx.setLineWidth(Tokens.Stroke.emphasis)
        ctx.addPath(path.cgPath)
        ctx.strokePath()

        let size = CGSize(width: 360, height: 60)
        let top = min(highlight.maxY + 12, bounds.height - size.height - 4)
        chipRect = CGRect(x: band.minX + 60, y: max(0, top), width: size.width, height: size.height)

        // The chip sits over the line below, so it has to read as something floating on
        // top of the page rather than as part of it.
        let chip = UIBezierPath(roundedRect: chipRect, cornerRadius: Tokens.Radius.button)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 18,
                      color: UIColor.black.withAlphaComponent(0.18).cgColor)
        ctx.setFillColor(UIColor(Tokens.Colour.paperRaised).cgColor)
        ctx.addPath(chip.cgPath)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.setStrokeColor(UIColor(Tokens.Colour.action).cgColor)
        ctx.setLineWidth(Tokens.Stroke.emphasis)
        ctx.addPath(chip.cgPath)
        ctx.strokePath()

        let label = NSAttributedString(string: "Write this line again", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor(Tokens.Colour.action),
        ])
        let labelSize = label.boundingRect(with: chipRect.size, options: .usesLineFragmentOrigin, context: nil)
        label.draw(at: CGPoint(x: chipRect.midX - labelSize.width / 2,
                               y: chipRect.midY - labelSize.height / 2))
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

        let advance = max(1, maskRenderer.layout.lineSpacing)
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

    /// `palette` is asked once per segment, given the line that segment sits on.
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
