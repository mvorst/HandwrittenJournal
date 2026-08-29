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

    @Binding var controller: TracingController

    func makeUIView(context: Context) -> ScrollingCanvas {
        let view = ScrollingCanvas()
        // The archive must be staged before the text lands: the canvas derives the record
        // from the ink, and a text without its ink would briefly report an empty record.
        if !restoring.isEmpty { view.canvas.restore(restoring) }
        view.apply(text: text, setup: setup)
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
        Task { @MainActor in
            controller.attach(view)
            view.focus(word: startAtWord, animated: false)
        }
        return view
    }

    func updateUIView(_ view: ScrollingCanvas, context: Context) {
        view.apply(text: text, setup: setup)
        view.focus(word: startAtWord, animated: true)
        view.canvas.showGuideLines = showGuideLines
        view.canvas.showGuideText = showGuideText
        view.canvas.colourBlind = colourBlind
        view.canvas.allowFinger = allowFinger
        view.canvas.isEraserActive = isEraserActive
        view.canvas.editingRange = editingRange
        let wasDictating = view.canvas.isDictating
        view.canvas.isDictating = isDictating
        if isDictating, !wasDictating || view.textJustGrew { view.followTail() }
        view.setFingerDraws(allowFinger && !isDictating)
    }
}

/// A scroll view whose content is one tall `TracingCanvasView`.
final class ScrollingCanvas: UIScrollView, UIScrollViewDelegate {

    let canvas = TracingCanvasView()
    private var appliedText = ""
    private var appliedSetup: WritingSetup?
    private var focusedWord: Int?
    private(set) var textJustGrew = false

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
        let height = max(bounds.height, canvas.requiredHeight(forWidth: bounds.width))
        if canvas.frame.size != CGSize(width: bounds.width, height: height) {
            canvas.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
            contentSize = canvas.frame.size
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

    /// While dictating, the newest words stay in view.
    func followTail() {
        layoutIfNeeded()
        let target = max(0, contentSize.height - bounds.height)
        if abs(contentOffset.y - target) > 4 {
            setContentOffset(CGPoint(x: 0, y: target), animated: false)
        }
    }

    private func scroll(to rect: CGRect, animated: Bool) {
        let target = max(0, min(rect.minY - bounds.height * 0.3, max(0, contentSize.height - bounds.height)))
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
        let step = (appliedSetup.map(MaskRenderer.lineAdvance(for:)) ?? 96) * CGFloat(lines)
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
    var hasInk: Bool = false
    /// Mirrored canvas state the footer hint reads. Updated alongside every progress
    /// report so observation actually fires.
    private(set) var hasSelection = false

    var onRecordChange: ((Int) -> Void)?
    var onSelectRow: ((Int) -> Void)?
    var onEditWord: ((ClosedRange<Int>, String) -> Void)?

    private weak var scroller: ScrollingCanvas?
    private var canvas: TracingCanvasView? { scroller?.canvas }

    func attach(_ scroller: ScrollingCanvas) { self.scroller = scroller }

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

    func makeUIView(context: Context) -> ReplayPageView { ReplayPageView() }

    func updateUIView(_ view: ReplayPageView, context: Context) {
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

        private let renderer = MaskRenderer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor(Tokens.Colour.paper)
            contentMode = .redraw
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

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
            }

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

            for stroke in strokes where stroke.points.count > 1 {
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
