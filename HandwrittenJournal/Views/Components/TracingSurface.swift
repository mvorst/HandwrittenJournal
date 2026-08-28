import SwiftUI
import UIKit

/// The scrolling writing page.
///
/// A scroll gesture and a pen stroke are hard to tell apart, so the two are separated by
/// touch count rather than by guesswork:
///
/// - **Finger tracing off** — one finger scrolls, only the pencil draws. Unambiguous.
/// - **Finger tracing on** — one finger draws, two fingers scroll. This is what Notes and
///   Procreate do, and it is learnable, but two fingers is a lot to ask of a five-year-old,
///   so the "next" button below the page scrolls without any gesture at all.
struct TracingSurface: UIViewRepresentable {

    let text: String
    let setup: WritingSetup
    var showGuideLines = true
    var showGuideText = true
    var colourBlind = false
    var allowFinger = true
    var isEraserActive = false
    /// Word index to scroll to — the resume point, and the first new word after the child
    /// says more and it is appended to the page.
    var startAtWord: Int = 0
    /// An earlier tracing of this same page, put back so the child carries on rather than
    /// starting again.
    var restoring: [TracingStroke] = []

    @Binding var controller: TracingController

    func makeUIView(context: Context) -> ScrollingCanvas {
        let view = ScrollingCanvas()
        view.apply(text: text, setup: setup)
        if !restoring.isEmpty { view.canvas.restore(restoring) }
        view.canvas.onProgress = { accuracy, words, hasInk in
            Task { @MainActor in
                controller.liveAccuracy = accuracy
                controller.wordsWritten = words
                controller.hasInk = hasInk
            }
        }
        view.canvas.onRetrace = { [weak view] line in
            view?.scrollToLine(line, animated: true)
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
        view.setFingerDraws(allowFinger)
    }
}

/// A scroll view whose content is one tall `TracingCanvasView`.
final class ScrollingCanvas: UIScrollView, UIScrollViewDelegate {

    let canvas = TracingCanvasView()
    private var appliedText = ""
    private var appliedSetup: WritingSetup?
    private var focusedWord: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Tokens.Colour.paper)
        alwaysBounceVertical = true
        showsVerticalScrollIndicator = true
        contentInsetAdjustmentBehavior = .never
        addSubview(canvas)
        delegate = self
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// One finger draws and two scroll, or one finger scrolls and only the pencil draws.
    func setFingerDraws(_ fingerDraws: Bool) {
        panGestureRecognizer.minimumNumberOfTouches = fingerDraws ? 2 : 1
    }

    func apply(text: String, setup: WritingSetup) {
        guard text != appliedText || setup != appliedSetup else { return }
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

    /// Puts a line near the top of the window — where the child re-traces it from.
    func scrollToLine(_ line: Int, animated: Bool = true) {
        layoutIfNeeded()
        guard let rect = canvas.rect(forLine: line) else { return }
        scroll(to: rect, animated: animated)
    }

    private func scroll(to rect: CGRect, animated: Bool) {
        let target = max(0, min(rect.minY - bounds.height * 0.3, max(0, contentSize.height - bounds.height)))
        setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    /// Scrolls to a word once per change. Called on resume and again when new dictation
    /// is appended, so the child lands on the first word they have not written.
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

    private weak var scroller: ScrollingCanvas?
    private var canvas: TracingCanvasView? { scroller?.canvas }

    func attach(_ scroller: ScrollingCanvas) { self.scroller = scroller }

    /// Lines the child has finished — the footer hint changes once there is one to tap.
    var gradedLineCount: Int { canvas?.gradedLines.count ?? 0 }
    var selectedLine: Int? { canvas?.selectedLine }

    func undo() { canvas?.undo() }
    func clear() { canvas?.clearAll() }
    func finish(streak: Int) -> ScoreResult? { canvas?.finish(streak: streak) }
    func archive() -> Data? { try? canvas?.archive() }
    func thumbnail() -> Data? { canvas?.thumbnail() }
    var canvasSize: CGSize { canvas?.bounds.size ?? .zero }
    var totalWords: Int { canvas?.layout.wordCount ?? 0 }

    func scrollToWord(_ word: Int, animated: Bool = false) { scroller?.scrollToWord(word, animated: animated) }
    func scrollToLine(_ line: Int, animated: Bool = true) { scroller?.scrollToLine(line, animated: animated) }
    func nextLines() { scroller?.scrollByLines(2) }
    func scrollToNextUnwritten() { scroller?.scrollToWord(wordsWritten, animated: true) }
}

// MARK: - Replay

/// Renders an archived tracing. Aspect-fit from the captured canvas so writing done on one
/// device reads correctly on another — letterboxed, never stretched.
struct InkReplayView: View {
    let strokes: [TracingStroke]
    let capturedSize: CGSize
    var setup: WritingSetup = .default
    var accuracyColours = false
    var colourBlind = false

    var body: some View {
        Canvas { context, size in
            guard capturedSize.width > 0, capturedSize.height > 0 else { return }
            let scale = min(size.width / capturedSize.width, size.height / capturedSize.height)
            let dx = (size.width - capturedSize.width * scale) / 2
            let dy = (size.height - capturedSize.height * scale) / 2
            let widthScale = setup.size.size / 72 * scale

            for stroke in strokes where stroke.points.count > 1 {
                for i in 1..<stroke.points.count {
                    let a = stroke.points[i - 1], b = stroke.points[i]
                    var path = Path()
                    path.move(to: CGPoint(x: a.location.x * scale + dx, y: a.location.y * scale + dy))
                    path.addLine(to: CGPoint(x: b.location.x * scale + dx, y: b.location.y * scale + dy))
                    let force = (a.force + b.force) / 2
                    let colour: Color = accuracyColours
                        ? (b.isInside ? (colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside)
                                      : (colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside))
                        : Tokens.Colour.inkNatural
                    context.stroke(path, with: .color(colour),
                                   style: StrokeStyle(lineWidth: max(0.4, (1.5 + 3.5 * force) * widthScale),
                                                      lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
