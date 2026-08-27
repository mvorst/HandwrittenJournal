import SwiftUI
import UIKit
import CoreText

// MARK: - Guide Text View (bottom layer — renders the guide text the same way as the mask)
class GuideTextView: UIView {
    var text: String = ""
    var levelConfig: LevelConfig = LevelDefinitions.config(for: 1)
    var showGuideLines: Bool = true

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let font = levelConfig.font
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = levelConfig.lineSpacing - font.pointSize
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)

        let margin = AppConstants.horizontalMargin
        let textWidth = bounds.width - margin * 2
        let framePath = CGPath(rect: CGRect(x: margin, y: 0, width: textWidth, height: bounds.height), transform: nil)

        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), framePath, nil)

        let lines = CTFrameGetLines(ctFrame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &origins)

        // Draw guide lines
        if showGuideLines {
            let lineColor = UIColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1.0) // #E5E5EA
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(1.0)

            for (i, line) in lines.enumerated() {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

                let baselineY = bounds.height - origins[i].y

                // Baseline (solid)
                context.beginPath()
                context.move(to: CGPoint(x: margin, y: baselineY))
                context.addLine(to: CGPoint(x: bounds.width - margin, y: baselineY))
                context.strokePath()

                // Top line (dashed)
                let topY = baselineY - ascent
                context.saveGState()
                context.setLineDash(phase: 0, lengths: [6, 4])
                context.beginPath()
                context.move(to: CGPoint(x: margin, y: topY))
                context.addLine(to: CGPoint(x: bounds.width - margin, y: topY))
                context.strokePath()
                context.restoreGState()

                // Descender line (dashed)
                let descenderY = baselineY + descent
                context.saveGState()
                context.setLineDash(phase: 0, lengths: [6, 4])
                context.beginPath()
                context.move(to: CGPoint(x: margin, y: descenderY))
                context.addLine(to: CGPoint(x: bounds.width - margin, y: descenderY))
                context.strokePath()
                context.restoreGState()
            }
        }

        // Draw text using CoreText (same as mask for pixel-perfect alignment)
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        CTFrameDraw(ctFrame, context)
        context.restoreGState()
    }
}

// MARK: - Stroke Render View (middle layer — draws colored strokes)
class StrokeRenderView: UIView {
    var strokes: [TracingStroke] = [] {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        CustomStrokeRenderer.render(strokes: strokes, in: context)
    }
}

// MARK: - Pencil Input Overlay (top layer — captures touch input)
@MainActor
protocol PencilInputDelegate: AnyObject {
    func pencilTouchBegan(at point: CGPoint, force: CGFloat, timestamp: TimeInterval)
    func pencilTouchMoved(to point: CGPoint, force: CGFloat, timestamp: TimeInterval, coalescedPoints: [(CGPoint, CGFloat, TimeInterval)])
    func pencilTouchEnded()
}

class PencilInputOverlay: UIView {
    weak var delegate: PencilInputDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // Accept all touch types in simulator, filter to pencil on device
        #if targetEnvironment(simulator)
        let point = touch.location(in: self)
        delegate?.pencilTouchBegan(at: point, force: max(touch.force, 0.5), timestamp: touch.timestamp)
        #else
        guard touch.type == .pencil else { return }
        let point = touch.location(in: self)
        delegate?.pencilTouchBegan(at: point, force: max(touch.force, 0.5), timestamp: touch.timestamp)
        #endif
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        #if !targetEnvironment(simulator)
        guard touch.type == .pencil else { return }
        #endif

        let point = touch.location(in: self)
        let force = max(touch.force, 0.5)

        // Get coalesced touches for higher resolution
        var coalesced: [(CGPoint, CGFloat, TimeInterval)] = []
        if let coalescedTouches = event?.coalescedTouches(for: touch) {
            for ct in coalescedTouches {
                coalesced.append((ct.location(in: self), max(ct.force, 0.5), ct.timestamp))
            }
        }

        delegate?.pencilTouchMoved(to: point, force: force, timestamp: touch.timestamp, coalescedPoints: coalesced)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if !targetEnvironment(simulator)
        guard let touch = touches.first, touch.type == .pencil else { return }
        #endif
        delegate?.pencilTouchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.pencilTouchEnded()
    }
}

// MARK: - UIViewRepresentable Coordinator
@MainActor
class TracingCanvasCoordinator: NSObject, PencilInputDelegate {
    var parent: TracingCanvasRepresentable
    var guideTextView: GuideTextView?
    var strokeRenderView: StrokeRenderView?
    var inputOverlay: PencilInputOverlay?

    init(parent: TracingCanvasRepresentable) {
        self.parent = parent
    }

    func pencilTouchBegan(at point: CGPoint, force: CGFloat, timestamp: TimeInterval) {
        parent.viewModel.beginNewStroke()
        parent.viewModel.addPoint(point, force: force, timestamp: timestamp)
        strokeRenderView?.strokes = parent.viewModel.session.strokes

        if let lastPoint = parent.viewModel.session.strokes.last?.points.last, !lastPoint.isInsideLetter {
            if parent.hapticsEnabled {
                HapticsService.shared.outsideLetterHaptic()
            }
        }
    }

    func pencilTouchMoved(to point: CGPoint, force: CGFloat, timestamp: TimeInterval, coalescedPoints: [(CGPoint, CGFloat, TimeInterval)]) {
        if coalescedPoints.count > 1 {
            for cp in coalescedPoints {
                parent.viewModel.addPoint(cp.0, force: cp.1, timestamp: cp.2)
            }
        } else {
            parent.viewModel.addPoint(point, force: force, timestamp: timestamp)
        }
        strokeRenderView?.strokes = parent.viewModel.session.strokes

        if let lastPoint = parent.viewModel.session.strokes.last?.points.last, !lastPoint.isInsideLetter {
            if parent.hapticsEnabled {
                HapticsService.shared.outsideLetterHaptic()
            }
        }
    }

    func pencilTouchEnded() {
        strokeRenderView?.strokes = parent.viewModel.session.strokes
    }
}

// MARK: - UIViewRepresentable
struct TracingCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: TracingViewModel
    var guideAlpha: CGFloat = 1.0
    var showGuideLines: Bool = true
    var hapticsEnabled: Bool = true

    func makeCoordinator() -> TracingCanvasCoordinator {
        TracingCanvasCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.98, green: 0.973, blue: 0.961, alpha: 1.0)
        container.clipsToBounds = true

        let guideView = GuideTextView()
        guideView.backgroundColor = .clear
        guideView.text = viewModel.session.text
        guideView.levelConfig = viewModel.levelConfig
        guideView.showGuideLines = showGuideLines
        guideView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(guideView)

        let strokeView = StrokeRenderView()
        strokeView.backgroundColor = .clear
        strokeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(strokeView)

        let overlay = PencilInputOverlay()
        overlay.delegate = context.coordinator
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            guideView.topAnchor.constraint(equalTo: container.topAnchor),
            guideView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            guideView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            guideView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            strokeView.topAnchor.constraint(equalTo: container.topAnchor),
            strokeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            strokeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            strokeView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.guideTextView = guideView
        context.coordinator.strokeRenderView = strokeView
        context.coordinator.inputOverlay = overlay

        // Generate mask after layout
        DispatchQueue.main.async {
            let size = container.bounds.size
            if size.width > 0 && size.height > 0 {
                viewModel.prepareMask(canvasSize: size, screenScale: UIScreen.main.scale)
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self

        if let guideView = context.coordinator.guideTextView {
            guideView.alpha = guideAlpha
            guideView.showGuideLines = showGuideLines
            guideView.setNeedsDisplay()
        }

        context.coordinator.strokeRenderView?.strokes = viewModel.session.strokes
        context.coordinator.strokeRenderView?.setNeedsDisplay()

        // Regenerate mask if needed
        let size = uiView.bounds.size
        if size.width > 0 && size.height > 0 && !viewModel.isReady {
            viewModel.prepareMask(canvasSize: size, screenScale: UIScreen.main.scale)
        }
    }
}
