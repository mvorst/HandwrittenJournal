import SwiftUI
import UIKit

/// The scrolling writing page.
///
/// **The pencil never scrolls** — its touches are excluded from the pan gesture outright,
/// so a pen on the page is always ink. Fingers scroll: one finger when finger tracing is
/// off, two when it is on (the Notes / Procreate split), and the chevron button below the
/// page scrolls with no gesture at all.
struct TracingSurface: UIViewRepresentable {

    /// The whole page: record + spoken buffer + the live partial while dictating.
    let text: String
    let setup: WritingSetup
    var showGuideLines = true
    var showGuideText = true
    var colourBlind = false
    var allowFinger = true
    var isEraserActive = false
    var isDictating = false
    /// The spoken word being fixed, if any — drawn boxed on the page.
    var editingRange: ClosedRange<Int>? = nil
    /// Word index to scroll to when the page first appears (resuming an entry).
    var startAtWord: Int = 0
    /// An earlier tracing of this same page, put back so the child carries on rather than
    /// starting again.
    var restoring: [TracingStroke] = []
    /// The canvas width that tracing was drawn at. The page lays itself out at that width
    /// and scales to fit the window, because ink cannot be moved to letters it never
    /// covered: greedy word wrap at any other width puts other words under it.
    var restoredWidth: CGFloat = 0
    /// Whether the archive carries each point's letter (HJST v2), so the restore keeps
    /// the attribution the record was derived from.
    var restoredAttributed = false
    /// Letters remediated in the help modal in an earlier sitting (§8.1b), by character
    /// position — their order discount stays lifted when the page reopens.
    var restoredRemediatedChars: [Int] = []
    /// The crayon is in hand: drawing touches doodle, nothing selects (v3.2).
    var isDoodleActive = false
    var crayon = 0
    /// The ABC tool is in hand: touches pick words to fix, or the space after them to
    /// add more (v3.2).
    var isTextEditActive = false
    /// Row handles sit in the gutter away from the writing hand.
    var handlesOnRight = false
    /// Room kept clear at the foot of the window — the stage the mic stands on while a
    /// take runs from an empty page, so the newest words never land under it.
    var bottomInset: CGFloat = 0

    @Binding var controller: TracingController

    func makeUIView(context: Context) -> ScrollingCanvas {
        let view = ScrollingCanvas()
        // The page lays out at the width its ink was drawn at, whatever the window is.
        view.layoutWidth = restoredWidth
        // The archive must be staged before the text lands: the canvas derives the record
        // from the ink, and a text without its ink would briefly report an empty record.
        if !restoring.isEmpty {
            view.canvas.restore(restoring, capturedWidth: restoredWidth, attributed: restoredAttributed)
        }
        if !restoredRemediatedChars.isEmpty {
            view.canvas.restoreRemediated(charIndices: restoredRemediatedChars)
        }
        view.apply(text: text, setup: setup)
        // Attached before anything can fire: every report below goes through the
        // controller, and a report that arrived before it knew its canvas would be lost.
        controller.attach(view)
        view.canvas.onProgress = { accuracy, words, hasInk in
            Task { @MainActor in
                controller.liveAccuracy = accuracy
                controller.wordsWritten = words
                controller.hasInk = hasInk
                controller.refresh()
            }
        }
        view.canvas.onRecordChange = { newLength in
            Task { @MainActor in controller.onRecordChange?(newLength) }
        }
        view.canvas.onSelectRow = { [weak view] row in
            view?.scrollToLine(row, animated: true)
            Task { @MainActor in controller.onSelectRow?(row) }
        }
        view.canvas.onEditWord = { range, word in
            Task { @MainActor in controller.onEditWord?(range, word) }
        }
        view.canvas.onFormationHelpNeeded = { request in
            Task { @MainActor in controller.onFormationHelp?(request) }
        }
        view.canvas.onInkChange = {
            Task { @MainActor in controller.onInkChange?() }
        }
        view.canvas.onAppendRequested = {
            Task { @MainActor in controller.onAppendRequested?() }
        }
        view.canvas.onPageState = { hasAnyInk, hasDoodles in
            Task { @MainActor in
                controller.pageHasInk = hasAnyInk
                controller.hasDoodles = hasDoodles
            }
        }
        Task { @MainActor in
            view.focus(word: startAtWord, animated: false)
        }
        return view
    }

    func updateUIView(_ view: ScrollingCanvas, context: Context) {
        view.layoutWidth = restoredWidth
        view.apply(text: text, setup: setup)
        view.focus(word: startAtWord, animated: true)
        view.canvas.showGuideLines = showGuideLines
        view.canvas.showGuideText = showGuideText
        view.canvas.colourBlind = colourBlind
        view.canvas.allowFinger = allowFinger
        view.canvas.isEraserActive = isEraserActive
        view.canvas.editingRange = editingRange
        view.canvas.isDoodleActive = isDoodleActive
        view.canvas.crayon = crayon
        view.canvas.isTextEditActive = isTextEditActive
        view.canvas.handlesOnRight = handlesOnRight
        if abs(view.contentInset.bottom - bottomInset) > 0.5 {
            view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        }
        let wasDictating = view.canvas.isDictating
        view.canvas.isDictating = isDictating
        if isDictating, !wasDictating || view.textJustGrew { view.followTail() }
        view.setFingerDraws(allowFinger && !isDictating)
    }
}

/// A scroll view whose content is one tall `TracingCanvasView`.
///
/// **The page has one width for life.** The canvas lays out at `layoutWidth` — the
/// width the entry's ink was first drawn at — and is scaled to the window. Greedy word
/// wrap at a different width would put different words under the child's strokes, so
/// a page opened in a narrower or wider window (Stage Manager, Split View, a bigger
/// iPad) keeps its geometry and shrinks or grows as a whole, the way the reading view
/// already does. Touches arrive in the canvas's own coordinates, so the pen and the
/// eraser need no conversion; only scrolling does.
final class ScrollingCanvas: UIScrollView, UIScrollViewDelegate {

    let canvas = TracingCanvasView()
    /// The width the canvas lays out at, or 0 to take the window's.
    var layoutWidth: CGFloat = 0 {
        didSet { if layoutWidth != oldValue { setNeedsLayout() } }
    }
    /// Window points per canvas point.
    private(set) var scale: CGFloat = 1
    private var appliedText = ""
    private var appliedSetup: WritingSetup?
    private var focusedWord: Int?
    private(set) var textJustGrew = false
    /// The window shape the last layout was for; a change is a rotation (v3.3).
    private var laidOutFor = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Tokens.Colour.paper)
        alwaysBounceVertical = true
        showsVerticalScrollIndicator = true
        contentInsetAdjustmentBehavior = .never
        // Same rule as the practice sheet: touches reach the canvas immediately, or a
        // fast pen loses its stroke head to the scroll view's touch delay.
        delaysContentTouches = false
        // The pencil never scrolls — a pen on the page is always ink, so only direct
        // touches (and trackpad pointers) can pan.
        panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
        ]
        addSubview(canvas)
        delegate = self
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// One finger draws and two scroll, or one finger scrolls and only the pencil draws.
    func setFingerDraws(_ fingerDraws: Bool) {
        panGestureRecognizer.minimumNumberOfTouches = fingerDraws ? 2 : 1
    }

    /// A finger dragging out a run of words is not a scroll that has not started yet, so
    /// the scroll view must not take the touch off the canvas half way through it.
    override func touchesShouldCancel(in view: UIView) -> Bool {
        canvas.isSelectingText ? false : super.touchesShouldCancel(in: view)
    }

    func apply(text: String, setup: WritingSetup) {
        guard text != appliedText || setup != appliedSetup else { textJustGrew = false; return }
        textJustGrew = text.count > appliedText.count
        appliedText = text
        appliedSetup = setup
        canvas.text = text
        canvas.setup = setup
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let reshaped = laidOutFor != .zero && laidOutFor != bounds.size
        laidOutFor = bounds.size
        let width = layoutWidth > 0 ? layoutWidth : bounds.width
        let zoom = bounds.width / width
        let height = max(bounds.height / zoom, canvas.requiredHeight(forWidth: width))
        let size = CGSize(width: width, height: height)
        if canvas.bounds.size != size || abs(scale - zoom) > 0.0001 {
            scale = zoom
            // A transformed view's frame is undefined; size it by bounds and place it
            // by centre.
            canvas.transform = .identity
            canvas.bounds = CGRect(origin: .zero, size: size)
            canvas.transform = CGAffineTransform(scaleX: zoom, y: zoom)
            canvas.center = CGPoint(x: size.width * zoom / 2, y: size.height * zoom / 2)
            // Rasterise at the scale the page is shown at, so a page grown to a wider
            // window is not a blown-up bitmap.
            canvas.contentScaleFactor = min(4, UIScreen.main.scale * max(1, zoom))
            contentSize = CGSize(width: size.width * zoom, height: size.height * zoom)
        }
        if reshaped { keepRowInView() }
    }

    /// After a rotation the window is a different height — in landscape the page shows
    /// about eight lines at Large rather than ten — so the row in hand stays where the
    /// child can see it, and with nothing in hand the offset is only clamped (v3.3).
    private func keepRowInView() {
        if let row = canvas.selectedRow, let rect = canvas.rect(forLine: row) {
            scroll(to: rect, animated: false)
        } else {
            let maxY = max(0, contentSize.height + contentInset.bottom - bounds.height)
            if contentOffset.y > maxY { setContentOffset(CGPoint(x: 0, y: maxY), animated: false) }
        }
    }

    /// Brings a word into view with a little headroom above it.
    func scrollToWord(_ word: Int, animated: Bool = false) {
        layoutIfNeeded()
        guard word > 0, let rect = canvas.rect(forWord: word) else { return }
        scroll(to: rect, animated: animated)
    }

    /// Puts a line near the top of the window — where the child writes it from.
    func scrollToLine(_ line: Int, animated: Bool = true) {
        layoutIfNeeded()
        guard let rect = canvas.rect(forLine: line) else { return }
        scroll(to: rect, animated: animated)
    }

    /// While dictating, the newest words stay in view — above the stage, when the mic is
    /// standing on the page.
    func followTail() {
        layoutIfNeeded()
        let target = max(0, contentSize.height + contentInset.bottom - bounds.height)
        if abs(contentOffset.y - target) > 4 {
            setContentOffset(CGPoint(x: 0, y: target), animated: false)
        }
    }

    /// `rect` is in canvas points; the offset is in window points.
    private func scroll(to rect: CGRect, animated: Bool) {
        let top = rect.minY * scale
        let target = max(0, min(top - bounds.height * 0.3, max(0, contentSize.height - bounds.height)))
        setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    /// Scrolls to a word once per change. Called on resume, so the child lands on the
    /// first word they have not written.
    func focus(word: Int, animated: Bool) {
        guard focusedWord != word else { return }
        let isFirst = focusedWord == nil
        focusedWord = word
        scrollToWord(word, animated: animated && !isFirst)
    }

    func scrollByLines(_ lines: Int, animated: Bool = true) {
        let step = (appliedSetup.map(MaskRenderer.lineAdvance(for:)) ?? 96) * CGFloat(lines) * scale
        let target = max(0, min(contentOffset.y + step, max(0, contentSize.height - bounds.height)))
        setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    var isAtBottom: Bool {
        contentOffset.y >= max(0, contentSize.height - bounds.height) - 4
    }
}

/// Bridges SwiftUI state to the UIKit canvas without leaking the view into view models.
@Observable
@MainActor
final class TracingController {
    var liveAccuracy: Double = 0
    var wordsWritten: Int = 0
    /// The selected row has ink — what enables the row tools.
    var hasInk: Bool = false
    /// The page has ink anywhere — what enables "I'm finished" (v3.2).
    var pageHasInk: Bool = false
    /// The page has doodles — what enables the tools while the crayon is in hand (v3.2).
    var hasDoodles: Bool = false
    /// Mirrored canvas state the footer hint reads. Updated alongside every progress
    /// report so observation actually fires.
    private(set) var hasSelection = false

    var onRecordChange: ((Int) -> Void)?
    var onSelectRow: ((Int) -> Void)?
    var onEditWord: ((ClosedRange<Int>, String) -> Void)?
    /// §8.1b — a word was finished with letters drawn in the wrong order.
    var onFormationHelp: ((FormationHelpRequest) -> Void)?
    /// The finished ink changed; the archive should follow it (§6).
    var onInkChange: (() -> Void)?
    /// The ABC tool was tapped past the last word (v3.2).
    var onAppendRequested: (() -> Void)?
    /// Asked to take the first unwritten row in hand before any surface existed.
    private var wantsFirstRowSelection = false

    // Not observed: it is set from inside a SwiftUI update, and nothing draws from it.
    @ObservationIgnored private weak var scroller: ScrollingCanvas?
    private var canvas: TracingCanvasView? { scroller?.canvas }

    func attach(_ scroller: ScrollingCanvas) {
        self.scroller = scroller
        if wantsFirstRowSelection {
            wantsFirstRowSelection = false
            scroller.canvas.selectFirstUnwrittenRow()
        }
    }

    /// v3.2 — asks the page to take its first unwritten line in hand, so the child can
    /// see where to start. Remembered until there is a surface to ask.
    func selectFirstUnwrittenRow() {
        guard let canvas else { wantsFirstRowSelection = true; return }
        canvas.selectFirstUnwrittenRow()
        refresh()
    }

    /// Whether a surface is on screen to speak for.
    var isAttached: Bool { canvas != nil }
    /// Whether the surface's ink stands for the entry's archive — false while a
    /// restore is pending or failed, and when there is no surface at all.
    var accountsForArchive: Bool { canvas?.accountsForArchive ?? false }

    func refresh() {
        hasSelection = canvas?.selectedRow != nil
    }

    var selectedRow: Int? { canvas?.selectedRow }

    func undo() { canvas?.undo() }
    func clear() { canvas?.clearSelected() }
    func selectRow(_ row: Int?) { canvas?.selectRow(row); refresh() }
    func finishEntry(streak: Int) -> ScoreResult? {
        let result = canvas?.finishEntry(streak: streak)
        refresh()
        return result
    }
    func archive() -> Data? { try? canvas?.archive() }
    /// §8.1b — lifts the order discount from a letter remediated in the help modal.
    func markRemediated(letter: Int) { canvas?.markRemediated(letter: letter) }
    func charIndex(ofGlyph glyph: Int) -> Int? { canvas?.charIndex(ofGlyph: glyph) }
    var strokeCount: Int { canvas?.strokes.count ?? 0 }
    func thumbnail() -> Data? { canvas?.thumbnail() }
    var canvasSize: CGSize { canvas?.bounds.size ?? .zero }
    var totalWords: Int { canvas?.layout.wordCount ?? 0 }

    func scrollToWord(_ word: Int, animated: Bool = false) { scroller?.scrollToWord(word, animated: animated) }
    func scrollToLine(_ line: Int, animated: Bool = true) { scroller?.scrollToLine(line, animated: animated) }
    func nextLines() { scroller?.scrollByLines(2) }
}

// MARK: - Replay

/// Renders a finished entry the way the editor showed it: ruled paper, the words the
/// child traced faint underneath, and their ink on top.
///
/// **Everything is drawn through one transform taken from the captured page**, which is
/// what keeps the guide under the ink. Laying the text out at the review page's own width
/// would re-wrap it — different line breaks, different baselines — and the words would
/// drift out from under the strokes that belong to them. So the context is scaled to the
/// width the child actually wrote at and the original layout is reproduced, never
/// recomputed.
///
/// Scaling is by width alone. A page is a vertical thing: it keeps its width and grows
/// downwards, and the caller sizes the view to match.
struct PageReplayView: UIViewRepresentable {
    let strokes: [TracingStroke]
    /// The record — the words that have ink on them. Because a session's spoken remainder
    /// is always appended after a hard break, laying out the record alone reproduces the
    /// record's own lines exactly as they were written.
    let text: String
    /// Width of the canvas the strokes were captured on.
    let capturedWidth: CGFloat
    var setup: WritingSetup = .default
    var showGuideText = true
    var showRules = true
    var accuracyColours = false
    var colourBlind = false
    /// A pencil touch on the finished page. Putting the pen down *is* the ask to write, so
    /// the reading page hands over to the writing one rather than making the child find a
    /// button first.
    var onPencilTap: (() -> Void)?

    func makeUIView(context: Context) -> ReplayPageView { ReplayPageView() }

    func updateUIView(_ view: ReplayPageView, context: Context) {
        view.onPencilTap = onPencilTap
        view.strokes = strokes
        view.text = text
        view.capturedWidth = capturedWidth
        view.setup = setup
        view.showGuideText = showGuideText
        view.showRules = showRules
        view.accuracyColours = accuracyColours
        view.colourBlind = colourBlind
        view.setNeedsDisplay()
    }

    final class ReplayPageView: UIView {
        var strokes: [TracingStroke] = []
        var text = ""
        var capturedWidth: CGFloat = 0
        var setup = WritingSetup.default
        var showGuideText = true
        var showRules = true
        var accuracyColours = false
        var colourBlind = false

        var onPencilTap: (() -> Void)?

        private let renderer = MaskRenderer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor(Tokens.Colour.paper)
            contentMode = .redraw
            let pencil = UITapGestureRecognizer(target: self, action: #selector(pencilTapped))
            pencil.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            addGestureRecognizer(pencil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        @objc private func pencilTapped() { onPencilTap?() }

        override func draw(_ rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext(),
                  capturedWidth > 0, bounds.width > 0, bounds.height > 0 else { return }

            let scale = bounds.width / capturedWidth
            ctx.saveGState()
            ctx.scaleBy(x: scale, y: scale)

            // From here the context *is* the page as it was written.
            let pageSize = CGSize(width: capturedWidth, height: bounds.height / scale)

            if !text.isEmpty {
                // layoutOnly: the mask bitmap is for scoring, and nothing is being scored.
                renderer.generate(text: text, setup: setup, canvasSize: pageSize, layoutOnly: true)
                if showRules { drawRules(in: ctx, pageSize: pageSize) }
                if showGuideText {
                    // The same faintness the editor uses beneath finished ink, from the
                    // same constant, so the two readings cannot drift apart.
                    renderer.drawGuide(in: ctx,
                                       colour: UIColor(Tokens.Colour.guideText),
                                       alphaForLine: { _ in TracingCanvasView.tracedGuideAlpha })
                }
            } else if showRules {
                // Nothing written yet, but doodles to show: still a ruled page (v3.2).
                drawRules(in: ctx, pageSize: pageSize)
            }

            // The crayon layer under the handwriting, as the page showed it (v3.2).
            Crayon.draw(strokes.doodles, in: ctx, widthScale: setup.size.size / 72)
            drawInk(in: ctx)
            ctx.restoreGState()
        }

        /// Ruled like the writing page — dashed ascender and descender, solid baseline —
        /// from the baselines CoreText actually produced, so the rules sit under the
        /// letters by construction rather than by two calculations agreeing.
        private func drawRules(in ctx: CGContext, pageSize: CGSize) {
            let size = setup.size
            let inset = Tokens.Layout.surfaceInset
            let width = pageSize.width - inset * 2
            guard width > 0 else { return }

            ctx.setStrokeColor(UIColor(Tokens.Colour.ruleLine).cgColor)
            ctx.setLineWidth(1)

            let measured = renderer.layout.lineSpacing
            let advance = measured > 1 ? measured : MaskRenderer.lineAdvance(for: setup)
            var baseline = renderer.layout.baselines.first ?? (Tokens.Space.s7 + size.ascent)
            var index = 0
            while baseline + size.descent < pageSize.height {
                if index < renderer.layout.baselines.count {
                    baseline = renderer.layout.baselines[index]
                }
                ctx.setLineDash(phase: 0, lengths: [6, 4])
                rule(ctx, y: baseline - size.ascent, x: inset, width: width)
                rule(ctx, y: baseline + size.descent, x: inset, width: width)
                ctx.setLineDash(phase: 0, lengths: [])
                rule(ctx, y: baseline, x: inset, width: width)

                index += 1
                if index >= renderer.layout.baselines.count { baseline += advance }
            }
            ctx.setLineDash(phase: 0, lengths: [])
        }

        private func rule(_ ctx: CGContext, y: CGFloat, x: CGFloat, width: CGFloat) {
            ctx.move(to: CGPoint(x: x, y: y.rounded() + 0.5))
            ctx.addLine(to: CGPoint(x: x + width, y: y.rounded() + 0.5))
            ctx.strokePath()
        }

        /// Graphite by default — a journal should read like handwriting, not like a
        /// marked-up test. Widths match the editor's range exactly.
        private func drawInk(in ctx: CGContext) {
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let s = setup.size.size / 72
            let low = 1.5 * s, high = 5.0 * s

            for stroke in strokes.ink where stroke.points.count > 1 {
                for i in 1..<stroke.points.count {
                    let a = stroke.points[i - 1], b = stroke.points[i]
                    let force = (a.force + b.force) / 2
                    let colour: Color = accuracyColours
                        ? (b.isInside ? (colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside)
                                      : (colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside))
                        : Tokens.Colour.inkNatural
                    ctx.setLineWidth(low + (high - low) * force)
                    ctx.setStrokeColor(UIColor(colour).cgColor)
                    ctx.move(to: a.location)
                    ctx.addLine(to: b.location)
                    ctx.strokePath()
                }
            }
        }
    }
}
