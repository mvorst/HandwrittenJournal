import SwiftUI
import UIKit
import CoreText

/// The practice sheet's loop, reported up to SwiftUI chrome.
enum PracticePhase: Equatable {
    case idle                    // nothing chosen yet
    case watching(Character)     // the demo is playing
    case yourTurn(Character)     // demo done (or skipped) — trace it
    case traced(Character)       // enough good ink landed on the letter
}

/// Bridges the UIKit sheet to SwiftUI without leaking the view outward.
@Observable
@MainActor
final class PracticeController {
    private(set) var phase: PracticePhase = .idle
    private(set) var accuracyPercent: Int = 0
    private(set) var hasInk = false

    fileprivate weak var canvas: PracticeCanvasView?

    fileprivate func sync() {
        guard let canvas else { return }
        phase = canvas.phase
        accuracyPercent = canvas.accuracyPercent
        hasInk = canvas.hasInk
    }

    func undo() { canvas?.undo() }
    func clear() { canvas?.clearInk() }
}

/// Frame 44 — the alphabet sheet. One letter is practiced at a time: touching a letter
/// plays its formation demo, tracing it colors green and red exactly like the journal
/// page, and starting the next letter clears the last one. Nothing here is saved.
struct PracticeSurface: UIViewRepresentable {
    let setup: WritingSetup
    var allowFinger = true
    var colourBlind = false
    let controller: PracticeController

    func makeUIView(context: Context) -> PracticeScrollView {
        let view = PracticeScrollView()
        view.canvas.setup = setup
        view.canvas.allowFinger = allowFinger
        view.canvas.colourBlind = colourBlind
        view.canvas.text = PracticeSheet.text
        controller.canvas = view.canvas
        view.canvas.onStateChange = { [weak controller] in controller?.sync() }
        view.setFingerDraws(allowFinger)
        return view
    }

    func updateUIView(_ view: PracticeScrollView, context: Context) {
        view.canvas.allowFinger = allowFinger
        view.canvas.colourBlind = colourBlind
        view.setFingerDraws(allowFinger)
    }
}

/// Scroll wrapper with the writing page's touch split: the pencil never scrolls, and a
/// finger scrolls with one or two fingers depending on whether it also draws.
final class PracticeScrollView: UIScrollView {
    let canvas = PracticeCanvasView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Tokens.Colour.paper)
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .never
        // Never hold touches back from the canvas: the default ~150 ms delay means a
        // moving pen's first samples are gone before the canvas hears about them, and
        // the stroke starts visibly late. Scrolling still wins via touchesCancelled.
        delaysContentTouches = false
        panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
        ]
        addSubview(canvas)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setFingerDraws(_ fingerDraws: Bool) {
        panGestureRecognizer.minimumNumberOfTouches = fingerDraws ? 2 : 1
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
}

/// The sheet itself: ruled lines, the guide alphabet, the demo overlay, and the child's
/// ink. Deliberately independent of `TracingCanvasView` — the editor's record/settle
/// machinery is load-bearing for the journal and none of it applies to a sandbox.
final class PracticeCanvasView: UIView {

    var text = "" { didSet { if text != oldValue { fittedForWidth = 0; rebuild() } } }
    var setup = WritingSetup.default { didSet { if setup != oldValue { fittedForWidth = 0; rebuild() } } }
    var allowFinger = true
    var colourBlind = false
    var onStateChange: (() -> Void)?

    private(set) var phase: PracticePhase = .idle

    private let maskRenderer = MaskRenderer()
    private lazy var fitter = FormationFitter(font: sheetSetup.uiFont())
    private var builtForSize: CGSize = .zero

    /// What the sheet actually renders at. The caller's setup contributes the face; the
    /// size is the sheet's own: the largest type at which the widest row still fits, so
    /// the letters fill the screen on any iPad instead of huddling in a corner.
    private var sheetSetup = WritingSetup.default
    private var fittedForWidth: CGFloat = 0

    private func ensureFit(width: CGFloat) {
        guard width > 0, abs(width - fittedForWidth) > 0.5 else { return }
        fittedForWidth = width
        // 0.98: fitting flush to the frame lets rounding wrap the widest row.
        let content = (width - Tokens.Layout.surfaceInset * 2) * 0.98
        let reference: CGFloat = 100
        let font = setup.face.uiFont(size: reference)
        var widest: CGFloat = 1
        for line in text.split(separator: "\n") {
            let attributed = NSAttributedString(string: String(line), attributes: [.font: font])
            widest = max(widest, CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
        }
        let size = max(72, min(300, (content / widest * reference).rounded(.down)))
        sheetSetup = WritingSetup(face: setup.face,
                                  size: JournalSize(id: "fit", label: "Practice",
                                                    size: size, lineSpacing: (size * 4 / 3).rounded()),
                                  mode: .trace)
    }

    // Ink — all of it belongs to the selected letter.
    private var strokes: [TracingStroke] = []
    private var current: TracingStroke?
    private var selectedGlyph: Int?

    // Demo overlay
    private var demoLayers: [CALayer] = []
    private var demoFinishWork: DispatchWorkItem?

    private struct PendingTap {
        let point: CGPoint
        let canDraw: Bool
        /// Every sample seen while deciding tap-vs-stroke. When the touch graduates
        /// into a stroke these seed it, so ink begins at the exact first contact.
        var head: [(location: CGPoint, force: CGFloat)]
    }
    private var pendingTap: PendingTap?
    /// The one touch this view listens to. Multi-touch stays enabled so that a pencil
    /// arriving after a resting palm can still be seen — and adopted over it.
    private var activeTouch: UITouch?
    /// Set when a pencil-down switched letters; a lift with no movement then means
    /// "show me this letter", not a dot of ink.
    private var pencilSwitchedSelection = false
    private static let tapSlop: CGFloat = 12

    /// The child's ink lives on its own transparent view **above** the canvas — demo
    /// layers are inserted below it, so the pen always draws over the tutorial guide.
    /// (Sublayers render above a view's own content; drawing ink in `draw(_:)` would
    /// leave it permanently underneath the guide.)
    private let inkView = InkOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Tokens.Colour.paper)
        // Multi-touch on: a palm resting before the pencil lands must not be the only
        // touch this view ever hears about.
        isMultipleTouchEnabled = true
        contentMode = .redraw
        inkView.canvas = self
        inkView.isUserInteractionEnabled = false
        inkView.backgroundColor = .clear
        inkView.contentMode = .redraw
        addSubview(inkView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Every existing dirty-mark also repaints the ink overlay.
    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        inkView.setNeedsDisplay()
    }

    // MARK: - Layout / mask

    func requiredHeight(forWidth width: CGFloat) -> CGFloat {
        let textWidth = width - Tokens.Layout.surfaceInset * 2
        guard textWidth > 0, !text.isEmpty else { return 1 }
        ensureFit(width: width)
        return MaskRenderer.contentHeight(text: text, setup: sheetSetup, width: textWidth)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if inkView.frame != bounds { inkView.frame = bounds }
        if abs(bounds.width - builtForSize.width) > 0.5 || abs(bounds.height - builtForSize.height) > 0.5 {
            rebuild()
        }
    }

    private func rebuild() {
        guard bounds.width > 0, bounds.height > 0, !text.isEmpty else { return }
        builtForSize = bounds.size
        ensureFit(width: bounds.width)
        fitter = FormationFitter(font: sheetSetup.uiFont())
        let pixels = bounds.width * bounds.height * 4
        let scale: CGFloat = pixels > 40_000_000 ? 1 : min(2, UIScreen.main.scale)
        maskRenderer.generate(text: text, setup: sheetSetup, canvasSize: bounds.size, screenScale: scale)
        // Geometry moved under everything; selection and ink are void.
        clearDemo()
        strokes = []
        current = nil
        selectedGlyph = nil
        setPhase(.idle)
        setNeedsDisplay()
    }

    private var selectedBox: MaskRenderer.GlyphBox? {
        guard let i = selectedGlyph, maskRenderer.layout.glyphBoxes.indices.contains(i) else { return nil }
        return maskRenderer.layout.glyphBoxes[i]
    }

    // MARK: - State out

    var hasInk: Bool { !strokes.isEmpty || current != nil }

    var accuracyPercent: Int {
        var inside = 0, total = 0
        for stroke in strokes {
            for p in stroke.points { total += 1; if p.isInside { inside += 1 } }
        }
        if let current {
            for p in current.points { total += 1; if p.isInside { inside += 1 } }
        }
        guard total > 0 else { return 0 }
        return Int((Double(inside) / Double(total) * 100).rounded())
    }

    private func setPhase(_ new: PracticePhase) {
        phase = new
        onStateChange?()
    }

    // MARK: - Selection

    private func select(glyph index: Int, playDemo: Bool) {
        let switching = index != selectedGlyph
        if switching {
            // The rule of the sheet: starting the next letter clears the last one.
            strokes = []
            current = nil
            selectedGlyph = index
        }
        clearDemo()
        guard let box = selectedBox else { return }
        if playDemo, let formation = LetterFormations.formation(for: box.character) {
            buildDemo(formation, for: box, animated: !UIAccessibility.isReduceMotionEnabled)
            setPhase(.watching(box.character))
        } else {
            setPhase(.yourTurn(box.character))
        }
        setNeedsDisplay()
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        refreshCompletion()
        setNeedsDisplay()
    }

    func clearInk() {
        strokes = []
        current = nil
        if let box = selectedBox { setPhase(.yourTurn(box.character)) } else { setPhase(.idle) }
        setNeedsDisplay()
    }

    // MARK: - Touches
    //
    // The pencil is a pen: it inks immediately, from the exact point it lands — no
    // tap-slop dead zone, no lost stroke head. The finger keeps the tap gesture
    // (tap = play the demo), so a finger stroke passes through a short deciding phase;
    // every sample seen during it is buffered and replayed into the stroke, so finger
    // ink also begins at first contact.

    private func drawingTouch(_ touch: UITouch) -> Bool {
        allowFinger || touch.type == .pencil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Prefer a pencil over anything else in this batch — and over a finger or palm
        // that got here first. The pencil always wins the pen.
        if let pencil = touches.first(where: { $0.type == .pencil }) {
            if activeTouch !== pencil {
                pendingTap = nil
                current = nil          // a palm's half-stroke is noise, not writing
                activeTouch = pencil
            }
            beginPencilStroke(with: pencil)
            return
        }
        // A finger while another touch is live is a palm — ignore it.
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        pendingTap = PendingTap(point: touch.location(in: self),
                                canDraw: drawingTouch(touch),
                                head: [(touch.location(in: self), forceOf(touch))])
    }

    /// Pencil-down: resolve the letter, then start inking at the touch point itself.
    private func beginPencilStroke(with touch: UITouch) {
        let point = touch.location(in: self)
        pencilSwitchedSelection = false
        if let hit = maskRenderer.glyphIndex(at: point, slack: 10), hit != selectedGlyph {
            select(glyph: hit, playDemo: false)
            pencilSwitchedSelection = true
        } else if case .watching(let char) = phase {
            // Writing over the demo ends the show — it is their turn now.
            finishDemoEarly(char)
        }
        guard selectedGlyph != nil else { return }
        current = TracingStroke()
        add(touch)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        let point = active.location(in: self)

        if var pending = pendingTap {
            for touch in event?.coalescedTouches(for: active) ?? [active] {
                pending.head.append((touch.location(in: self), forceOf(touch)))
            }
            guard hypot(point.x - pending.point.x, point.y - pending.point.y) > Self.tapSlop else {
                pendingTap = pending
                return
            }
            pendingTap = nil
            guard pending.canDraw else { return }
            // A moving finger is writing. If it started on a different letter, the
            // sheet moves on to that letter — demo skipped, they are already tracing.
            if let hit = maskRenderer.glyphIndex(at: pending.point, slack: 10), hit != selectedGlyph {
                select(glyph: hit, playDemo: false)
            } else if case .watching(let char) = phase {
                finishDemoEarly(char)
            }
            guard selectedGlyph != nil else { return }
            current = TracingStroke()
            // The whole buffered head, so the stroke begins where the touch did.
            for sample in pending.head { append(location: sample.location, force: sample.force) }
            setNeedsDisplay()
            return
        }
        guard current != nil else { return }
        for coalesced in event?.coalescedTouches(for: active) ?? [active] { add(coalesced) }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        activeTouch = nil
        if let pending = pendingTap {
            pendingTap = nil
            // A finger tap asks to see the letter. The same letter replays.
            if let hit = maskRenderer.glyphIndex(at: pending.point, slack: 10) {
                Haptics.tap()
                select(glyph: hit, playDemo: true)
            }
            return
        }
        endStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        activeTouch = nil
        pendingTap = nil
        endStroke()
    }

    private func forceOf(_ touch: UITouch) -> CGFloat {
        touch.type == .pencil && touch.maximumPossibleForce > 0
            ? min(1, touch.force / touch.maximumPossibleForce)
            : 0.55
    }

    private func add(_ touch: UITouch) {
        append(location: touch.location(in: self), force: forceOf(touch))
    }

    private func append(location: CGPoint, force: CGFloat) {
        guard current != nil else { return }
        let line = selectedBox?.lineIndex
        let letter = maskRenderer.glyphIndex(at: location, onLine: line) ?? -1
        let inside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
        current?.append(StrokePoint(location: location, force: force, isInside: inside, letterIndex: letter))
    }

    private func endStroke() {
        let switched = pencilSwitchedSelection
        pencilSwitchedSelection = false
        if var finished = current {
            current = nil
            if finished.points.count == 1 {
                if switched {
                    // The pencil landed on a fresh letter and lifted without writing —
                    // that is a tap, and a tap asks to see the letter.
                    if let index = selectedGlyph {
                        Haptics.tap()
                        select(glyph: index, playDemo: true)
                    }
                    setNeedsDisplay()
                    return
                }
                // A deliberate pencil dot (the dot of an i) — give it body to render.
                var copy = finished.points[0]
                copy.location.x += 0.5
                finished.append(copy)
            }
            if !finished.isEmpty { strokes.append(finished) }
        }
        refreshCompletion()
        setNeedsDisplay()
    }

    /// Enough good ink on the selected letter counts as traced — a nudge, not a grade.
    ///
    /// The measure is **distance, not samples**: ink travelled inside the letter against
    /// the formation's own path length. A fast confident trace produces far fewer touch
    /// samples than a slow careful one and deserves the same credit.
    private func refreshCompletion() {
        guard let index = selectedGlyph, let box = selectedBox else { onStateChange?(); return }
        if case .traced = phase { onStateChange?(); return }

        var goodTravel: CGFloat = 0
        var inside = 0, total = 0
        for stroke in strokes {
            for i in stroke.points.indices {
                let p = stroke.points[i]
                total += 1
                if p.isInside { inside += 1 }
                guard i > 0 else { continue }
                let a = stroke.points[i - 1]
                if p.isInside, p.letterIndex == index || a.letterIndex == index {
                    goodTravel += hypot(p.location.x - a.location.x, p.location.y - a.location.y)
                }
            }
        }
        if total > 0, goodTravel >= formationLength(for: box) * 0.5,
           Double(inside) / Double(total) >= 0.5 {
            Haptics.success()
            setPhase(.traced(box.character))
        } else {
            onStateChange?()
        }
    }

    /// What tracing this letter is worth in pen-travel, from its own formation.
    private func formationLength(for box: MaskRenderer.GlyphBox) -> CGFloat {
        guard let formation = LetterFormations.formation(for: box.character) else {
            // No formation: fall back to a loop around the letter's ink.
            let rect = fitter.inkRect(for: box)
            return (rect.width + rect.height) * 1.5
        }
        let inkRect = formationRect(for: box)
        var length: CGFloat = 0
        for stroke in formation.strokes {
            let points = FormationFitter.place(stroke, in: inkRect)
            for i in 1..<max(1, points.count) {
                length += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            }
        }
        return max(length, 1)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        drawRules(in: ctx)
        drawHighlight(in: ctx)
        maskRenderer.drawGuide(in: ctx, colour: UIColor(Tokens.Colour.guideText))
        // Ink is drawn by `inkView`, above the demo layers.
    }

    /// Ruled like the writing page, but only where the sheet has letters — this is a
    /// worksheet, not an open page.
    private func drawRules(in ctx: CGContext) {
        let size = sheetSetup.size
        let inset = Tokens.Layout.surfaceInset
        let width = bounds.width - inset * 2
        guard width > 0 else { return }
        ctx.setStrokeColor(UIColor(Tokens.Colour.ruleLine).cgColor)
        ctx.setLineWidth(1)
        for baseline in maskRenderer.layout.baselines {
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            rule(ctx, y: baseline - size.ascent, x: inset, width: width)
            rule(ctx, y: baseline + size.descent, x: inset, width: width)
            ctx.setLineDash(phase: 0, lengths: [])
            rule(ctx, y: baseline, x: inset, width: width)
        }
    }

    private func rule(_ ctx: CGContext, y: CGFloat, x: CGFloat, width: CGFloat) {
        ctx.move(to: CGPoint(x: x, y: y.rounded() + 0.5))
        ctx.addLine(to: CGPoint(x: x + width, y: y.rounded() + 0.5))
        ctx.strokePath()
    }

    /// The worksheet cell around the letter being practiced.
    private func drawHighlight(in ctx: CGContext) {
        guard let box = selectedBox else { return }
        let scale = sheetSetup.size.size / 72
        let cell = fitter.inkRect(for: box).insetBy(dx: -12 * scale, dy: -10 * scale)
        let path = UIBezierPath(roundedRect: cell, cornerRadius: 10 * scale)
        let tint = doneTracing ? Tokens.Colour.inkInside : Tokens.Colour.action
        ctx.setFillColor(UIColor(tint).withAlphaComponent(0.10).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(UIColor(tint).withAlphaComponent(0.38).cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
    }

    private var doneTracing: Bool {
        if case .traced = phase { return true }
        return false
    }

    private var widthRange: ClosedRange<CGFloat> {
        let scale = sheetSetup.size.size / 72
        return (1.5 * scale)...(5.0 * scale)
    }

    fileprivate func drawInk(in ctx: CGContext) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let range = widthRange
        let inside = UIColor(colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside)
        let outside = UIColor(colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside)
        for stroke in strokes + (current.map { [$0] } ?? []) where stroke.points.count > 1 {
            for i in 1..<stroke.points.count {
                let a = stroke.points[i - 1], b = stroke.points[i]
                let force = (a.force + b.force) / 2
                ctx.setLineWidth(range.lowerBound + (range.upperBound - range.lowerBound) * force)
                ctx.setStrokeColor((b.isInside ? inside : outside).cgColor)
                ctx.move(to: a.location)
                ctx.addLine(to: b.location)
                ctx.strokePath()
            }
        }
    }

    // MARK: - The demo

    private func clearDemo() {
        demoFinishWork?.cancel()
        demoFinishWork = nil
        demoLayers.forEach { $0.removeFromSuperlayer() }
        demoLayers = []
    }

    private func finishDemoEarly(_ char: Character) {
        demoFinishWork?.cancel()
        demoFinishWork = nil
        for layer in demoLayers { staticize(layer) }
        setPhase(.yourTurn(char))
    }

    /// Where formations land: the glyph's ink bounds pulled in by half of Jua's stroke
    /// width, so the guide runs down the **middle** of the letter's stroke instead of
    /// hugging its outline. Formations describe the pen's path, not the letter's edge.
    private func formationRect(for box: MaskRenderer.GlyphBox) -> CGRect {
        let inset = sheetSetup.size.size * 0.075
        let rect = fitter.inkRect(for: box)
        // Never collapse a thin glyph (l, i, 1) — cap the inset at a third of each side.
        return rect.insetBy(dx: min(inset, rect.width / 3), dy: min(inset, rect.height / 3))
    }

    /// The formation drawn stroke by stroke: each path draws itself at a followable
    /// pace with an arrowhead at its end. When the show is over the arrowheads leave
    /// and the thin lines stay — order is carried by the animation alone.
    private func buildDemo(_ formation: LetterFormation, for box: MaskRenderer.GlyphBox, animated: Bool) {
        let inkRect = formationRect(for: box)
        let scale = sheetSetup.size.size / 72
        // A thin inner line, not a fat marker — the guide runs down the middle of the
        // letter and must leave room for the child's ink around it.
        let lineWidth = max(2.5, 3 * scale)
        let segment = UIColor(Tokens.Colour.practicePath)
        let now = CACurrentMediaTime()
        var start = now + 0.15
        let drawRate: CGFloat = max(120, 170 * scale)   // points per second, child pace

        for (index, stroke) in formation.strokes.enumerated() {
            let points = FormationFitter.place(stroke, in: inkRect)
            guard let first = points.first else { continue }

            if stroke.isDot {
                let dot = CAShapeLayer()
                let r = lineWidth * 0.85
                dot.path = UIBezierPath(ovalIn: CGRect(x: first.x - r, y: first.y - r,
                                                       width: r * 2, height: r * 2)).cgPath
                dot.fillColor = segment.cgColor
                dot.name = "stroke"
                install(dot, appearAt: start, animated: animated)
                start += animated ? 0.45 : 0
                continue
            }

            let path = UIBezierPath()
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            var length: CGFloat = 0
            for i in 1..<points.count { length += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y) }
            let duration = animated ? max(0.35, min(1.6, length / drawRate)) : 0

            let shape = CAShapeLayer()
            shape.path = path.cgPath
            shape.strokeColor = segment.cgColor
            shape.fillColor = nil
            shape.lineWidth = lineWidth
            shape.lineCap = .round
            shape.lineJoin = .round
            shape.name = "stroke"
            layer.insertSublayer(shape, below: inkView.layer)
            demoLayers.append(shape)

            if animated {
                shape.strokeEnd = 0
                let draw = CABasicAnimation(keyPath: "strokeEnd")
                draw.fromValue = 0
                draw.toValue = 1
                draw.beginTime = start
                draw.duration = duration
                draw.fillMode = .both
                draw.isRemovedOnCompletion = false
                shape.add(draw, forKey: "draw")
                shape.strokeEnd = 1
            }

            if points.count > 1 {
                let tail = points[points.count - 1]
                let prev = points[max(0, points.count - 2)]
                addArrow(at: tail, from: prev, lineWidth: lineWidth * 1.6, tint: segment,
                         appearAt: start + duration, animated: animated)
            }
            start += duration + (animated ? 0.3 : 0)
        }

        if animated {
            let work = DispatchWorkItem { [weak self] in
                guard let self, case .watching(let char) = self.phase else { return }
                for layer in self.demoLayers { self.staticize(layer) }
                self.setPhase(.yourTurn(char))
            }
            demoFinishWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (start - now) + 0.1, execute: work)
        } else {
            for layer in demoLayers { staticize(layer) }
            setPhase(.yourTurn(box.character))
            // Phase is set again by the caller for the un-animated path; harmless.
        }
    }

    /// The after-state: the thin inner lines stay exactly as drawn — solid, full
    /// strength — and the arrowheads leave.
    private func staticize(_ layer: CALayer) {
        layer.removeAllAnimations()
        if layer.name == "arrow" {
            layer.removeFromSuperlayer()
            return
        }
        if let shape = layer as? CAShapeLayer, shape.name == "stroke" {
            shape.strokeEnd = 1
        }
        layer.opacity = 1
    }

    private func install(_ layer: CALayer, appearAt time: CFTimeInterval, animated: Bool) {
        self.layer.insertSublayer(layer, below: inkView.layer)
        demoLayers.append(layer)
        guard animated else { return }
        layer.opacity = 0
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        appear.beginTime = time
        appear.duration = 0.12
        appear.fillMode = .both
        appear.isRemovedOnCompletion = false
        layer.add(appear, forKey: "appear")
        layer.opacity = 1
    }

    private func addArrow(at tip: CGPoint, from previous: CGPoint, lineWidth: CGFloat,
                          tint: UIColor, appearAt time: CFTimeInterval, animated: Bool) {
        let angle = atan2(tip.y - previous.y, tip.x - previous.x)
        let length = lineWidth * 2.6
        let spread: CGFloat = .pi * 0.78
        let path = UIBezierPath()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x + cos(angle + spread) * length,
                                 y: tip.y + sin(angle + spread) * length))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x + cos(angle - spread) * length,
                                 y: tip.y + sin(angle - spread) * length))
        let arrow = CAShapeLayer()
        arrow.path = path.cgPath
        arrow.strokeColor = tint.cgColor
        arrow.fillColor = nil
        arrow.lineWidth = lineWidth * 0.8
        arrow.lineCap = .round
        arrow.name = "arrow"
        install(arrow, appearAt: time, animated: animated)
    }
}


/// Transparent top sheet that renders the child's strokes. Touches pass through; the
/// canvas beneath owns all input and marks this view dirty alongside itself.
private final class InkOverlayView: UIView {
    weak var canvas: PracticeCanvasView?

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        canvas?.drawInk(in: ctx)
    }
}
