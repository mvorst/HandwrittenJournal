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
    /// §8.1a — false when the selected letter's ink took the taught parts out of
    /// order or direction; the live % above already carries the discount.
    private(set) var followedOrder = true
    /// §8.1b — whether every stroke of the letter's formation has been covered.
    private(set) var formationComplete = false
    /// §8.1b — grows by one each time finished ink turns out wrong-order.
    private(set) var attemptFailures = 0

    fileprivate weak var canvas: PracticeCanvasView?

    fileprivate func sync() {
        guard let canvas else { return }
        phase = canvas.phase
        accuracyPercent = canvas.accuracyPercent
        hasInk = canvas.hasInk
        followedOrder = canvas.followedOrder
        formationComplete = canvas.formationComplete
        attemptFailures = canvas.attemptFailures
    }

    func undo() { canvas?.undo() }
    func clear() { canvas?.clearInk() }
    /// §8.1b — wipe the ink and play the arrows again after a wrong-order attempt.
    func startOverWithDemo() { canvas?.startOverWithDemo() }
}

/// Frame 44 — the alphabet sheet. One letter is practiced at a time: touching a letter
/// plays its formation demo, tracing it colors green and red exactly like the journal
/// page, and starting the next letter clears the last one. Nothing here is saved.
struct PracticeSurface: UIViewRepresentable {
    let setup: WritingSetup
    var allowFinger = true
    var colourBlind = false
    /// The sheet to lay out — the full alphabet by default; the remediation modal
    /// passes the one letter being practiced (§8.1b).
    var sheetText = PracticeSheet.text
    var autoSelectSoleGlyph = false
    var requireFullFormation = false
    /// §8.3 (v3.1) — the letters that have already earned today, by points, so the
    /// sheet can colour what is done. Empty on the remediation modal's sheet.
    var completed: [Character: Int] = [:]
    let controller: PracticeController

    func makeUIView(context: Context) -> PracticeScrollView {
        let view = PracticeScrollView()
        view.canvas.setup = setup
        view.canvas.allowFinger = allowFinger
        view.canvas.colourBlind = colourBlind
        view.canvas.autoSelectSoleGlyph = autoSelectSoleGlyph
        view.canvas.requireFullFormation = requireFullFormation
        view.canvas.completed = completed
        view.canvas.text = sheetText
        controller.canvas = view.canvas
        view.canvas.onStateChange = { [weak controller] in controller?.sync() }
        view.setFingerDraws(allowFinger)
        return view
    }

    func updateUIView(_ view: PracticeScrollView, context: Context) {
        view.canvas.allowFinger = allowFinger
        view.canvas.colourBlind = colourBlind
        view.canvas.completed = completed
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
    /// §8.1b — the remediation modal's sheet holds one letter: select it and play its
    /// demo the moment the sheet is built, with no touch needed.
    var autoSelectSoleGlyph = false
    /// §8.1b — completion means the whole letter, correctly: `.traced` requires the
    /// formation followed in order *and* every one of its strokes covered, not just
    /// enough good ink. Off for the practice sheet, on for the remediation modal.
    var requireFullFormation = false
    /// §8.3 (v3.1) — the letters that have already earned today, by points. Each draws
    /// in its status colour so the sheet shows what is done; the letter in hand always
    /// draws in the guide colour, or its own green ink would vanish into a green letter.
    var completed: [Character: Int] = [:] {
        didSet { if completed != oldValue { setNeedsDisplay() } }
    }
    var onStateChange: (() -> Void)?

    private(set) var phase: PracticePhase = .idle

    private let maskRenderer = MaskRenderer()
    private lazy var fitter = FormationFitter(font: sheetSetup.uiFont())
    /// §8.1a — the sheet teaches the same rule the journal grades, so its live %
    /// takes the same order discount.
    private var orderJudge: FormationOrderJudge?
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
        orderJudge = FormationOrderJudge(setup: sheetSetup)
        let pixels = bounds.width * bounds.height * 4
        let scale: CGFloat = pixels > 40_000_000 ? 1 : min(2, UIScreen.main.scale)
        maskRenderer.generate(text: text, setup: sheetSetup, canvasSize: bounds.size, screenScale: scale)
        // Geometry moved under everything; selection and ink are void.
        clearDemo()
        strokes = []
        current = nil
        followedOrder = true
        formationComplete = false
        selectedGlyph = nil
        setPhase(.idle)
        // The remediation modal's one letter shows itself — no touch needed (§8.1b).
        if autoSelectSoleGlyph,
           let first = maskRenderer.layout.glyphBoxes.firstIndex(where: \.isScorable) {
            select(glyph: first, playDemo: true)
        }
        setNeedsDisplay()
    }

    /// §8.1b — a failed attempt starts over: the ink clears and the arrows play again.
    func startOverWithDemo() {
        guard let index = selectedGlyph else { return }
        clearInk()
        select(glyph: index, playDemo: true)
    }

    var layout: MaskRenderer.Layout { maskRenderer.layout }

    /// A glyph's taught path in canvas space — what a perfect trace runs along. The
    /// programmatic counterpart of following the demo, used by tests.
    func formationPaths(forGlyph index: Int) -> [[CGPoint]] {
        guard maskRenderer.layout.glyphBoxes.indices.contains(index),
              let formation = LetterFormations.formation(for: maskRenderer.layout.glyphBoxes[index].character)
        else { return [] }
        let rect = fitter.formationRect(for: maskRenderer.layout.glyphBoxes[index])
        return FormationOrder.place(formation, in: rect).map(\.points)
    }

    /// Appends ink as if drawn — attributed the way a touch would be, each stroke
    /// finishing with the same pen-up judgment. The programmatic path used by tests.
    func addInk(_ new: [TracingStroke]) {
        for var stroke in new {
            for i in stroke.points.indices {
                let location = stroke.points[i].location
                stroke.points[i].letterIndex = maskRenderer.glyphIndex(at: location, onLine: selectedBox?.lineIndex) ?? -1
                stroke.points[i].isInside = maskRenderer.isInsideLetter(point: location, tolerance: 2)
            }
            if stroke.points.count == 1 {
                var copy = stroke.points[0]
                copy.location.x += 0.5
                stroke.append(copy)
            }
            if !stroke.isEmpty { strokes.append(stroke) }
            refreshCompletion()
        }
        setNeedsDisplay()
    }

    private var selectedBox: MaskRenderer.GlyphBox? {
        guard let i = selectedGlyph, maskRenderer.layout.glyphBoxes.indices.contains(i) else { return nil }
        return maskRenderer.layout.glyphBoxes[i]
    }

    // MARK: - State out

    var hasInk: Bool { !strokes.isEmpty || current != nil }

    /// §8.1a — whether the selected letter's finished ink followed its formation.
    /// Judged at pen-up; a letter with no verdict yet reads as followed.
    private(set) var followedOrder = true
    /// §8.1b — whether every stroke of the selected letter's formation has been covered.
    private(set) var formationComplete = false
    /// §8.1b — bumped each time finished ink turns out to have taken the wrong path.
    /// The remediation modal watches this to clear the ink and replay the arrows.
    private(set) var attemptFailures = 0

    var accuracyPercent: Int {
        var inside = 0, total = 0
        for stroke in strokes {
            for p in stroke.points { total += 1; if p.isInside { inside += 1 } }
        }
        if let current {
            for p in current.points { total += 1; if p.isInside { inside += 1 } }
        }
        guard total > 0 else { return 0 }
        let raw = Double(inside) / Double(total)
        let discounted = followedOrder ? raw : raw * ScoringEngine.orderDiscount
        return Int((discounted * 100).rounded())
    }

    /// Re-judges the selected letter's ink against its formation. Called wherever the
    /// finished strokes change — pen-up, undo, clear — never mid-stroke.
    private func refreshOrderVerdict() {
        let was = followedOrder
        followedOrder = true
        formationComplete = false
        guard let judge = orderJudge, let index = selectedGlyph, let box = selectedBox,
              !strokes.isEmpty else { return }
        let penPaths = FormationOrderJudge.penPathsByLetter(in: strokes)[index] ?? []
        guard !penPaths.isEmpty else { return }
        let signature = FormationOrderJudge.signature(of: penPaths, box: box)
        guard let analysis = judge.analysis(penPaths: penPaths, glyph: index,
                                            box: box, signature: signature) else { return }
        followedOrder = analysis.followed
        formationComplete = analysis.coveredAllStrokes
        if was, !followedOrder { attemptFailures += 1 }
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
            followedOrder = true
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
        followedOrder = true
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
            // §8.1b — on the sole-letter sheet, once tracing has begun a finger tap is
            // how the dot of an i gets inked (the pencil already dots by tapping). The
            // full formation is required there, so a tap that only ever replayed the
            // demo would lock a finger tracer out of every dotted letter for good;
            // replays live on the modal's own button instead.
            if autoSelectSoleGlyph, hasInk, pending.canDraw,
               maskRenderer.glyphIndex(at: pending.point, slack: 10) == selectedGlyph {
                current = TracingStroke()
                append(location: pending.point, force: 0.55)
                endStroke()
                return
            }
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
        refreshOrderVerdict()
        guard let index = selectedGlyph, let box = selectedBox else { onStateChange?(); return }
        if case .traced = phase { onStateChange?(); return }

        // §8.1b — a wrong-order verdict is sticky: the order and direction of first
        // visits are made and no further ink can unmake them. When the whole formation
        // is required, the attempt resets *now*, at the pen-up that condemned it — a
        // delayed reset leaves doomed ink on the sheet, and a child who immediately
        // retraces correctly merges into it and can never complete.
        if requireFullFormation, !followedOrder {
            startOverWithDemo()
            return
        }

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
           Double(inside) / Double(total) >= 0.5,
           !requireFullFormation || (followedOrder && formationComplete) {
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
        let inkRect = fitter.formationRect(for: box)
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
        let statuses = statusColours()
        maskRenderer.drawGuide(in: ctx, colour: UIColor(Tokens.Colour.guideText),
                               colourForCharacter: { statuses[$0] })
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

    /// The completed letters' colours by `charIndex`, the letter in hand excepted.
    private func statusColours() -> [Int: UIColor] {
        guard !completed.isEmpty else { return [:] }
        var out: [Int: UIColor] = [:]
        let inHand = selectedBox?.charIndex
        for box in maskRenderer.layout.glyphBoxes where box.isScorable && box.charIndex != inHand {
            if let points = completed[box.character],
               let colour = Self.statusColour(points: points, colourBlind: colourBlind) {
                out[box.charIndex] = colour
            }
        }
        return out
    }

    /// Green for a letter that earned both points, orange for one that earned a single
    /// point out of arrow order — or the colour-blind pair the page's ink already uses.
    static func statusColour(points: Int, colourBlind: Bool) -> UIColor? {
        switch points {
        case 2...: return UIColor(colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.success)
        case 1:    return UIColor(colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.starOn)
        default:   return nil
        }
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

    /// The formation drawn stroke by stroke: each path draws itself at a followable
    /// pace with an arrowhead at its end. When the show is over the arrowheads leave
    /// and the thin lines stay — order is carried by the animation alone.
    /// (`fitter.formationRect` puts the guide down the middle of the letter's stroke.)
    private func buildDemo(_ formation: LetterFormation, for box: MaskRenderer.GlyphBox, animated: Bool) {
        let inkRect = fitter.formationRect(for: box)
        let scale = sheetSetup.size.size / 72
        // A thin inner line, not a fat marker — the guide runs down the middle of the
        // letter and must leave room for the child's ink around it.
        let lineWidth = max(2.5, 3 * scale)
        let segment = UIColor(Tokens.Colour.practicePath)
        let now = CACurrentMediaTime()
        var start = now + 0.15
        let drawRate: CGFloat = max(120, 170 * scale)   // points per second, child pace

        for stroke in formation.strokes {
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
