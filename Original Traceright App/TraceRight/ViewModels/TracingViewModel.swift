import SwiftUI

@MainActor
final class TracingViewModel: ObservableObject {
    @Published var session: TracingSession
    @Published var liveAccuracy: CGFloat = 0
    @Published var isReady: Bool = false

    let maskRenderer = MaskRenderer()
    var colorizer: StrokeColorizer?
    var layoutInfo: MaskRenderer.LayoutInfo?
    let levelConfig: LevelConfig

    init(text: String, level: Int) {
        self.session = TracingSession(text: text, level: level)
        self.levelConfig = LevelDefinitions.config(for: level)
    }

    func prepareMask(canvasSize: CGSize, screenScale: CGFloat) {
        layoutInfo = maskRenderer.generateMask(
            text: session.text,
            levelConfig: levelConfig,
            canvasSize: canvasSize,
            screenScale: screenScale
        )
        colorizer = StrokeColorizer(maskRenderer: maskRenderer, tolerance: levelConfig.edgeTolerance)
        isReady = true
    }

    func addPoint(_ point: CGPoint, force: CGFloat, timestamp: TimeInterval) {
        guard let colorizer = colorizer else { return }
        let isInside = colorizer.classify(point: point)
        let tracingPoint = TracingPoint(
            location: point,
            timestamp: timestamp,
            force: force,
            isInsideLetter: isInside
        )

        if session.strokes.isEmpty {
            session.strokes.append(TracingStroke(points: [tracingPoint]))
        } else {
            session.strokes[session.strokes.count - 1].points.append(tracingPoint)
        }

        updateLiveAccuracy()
    }

    func beginNewStroke() {
        session.strokes.append(TracingStroke(points: []))
    }

    func undoLastStroke() {
        guard !session.strokes.isEmpty else { return }
        session.strokes.removeLast()
        updateLiveAccuracy()
    }

    func clearAll() {
        session.strokes.removeAll()
        liveAccuracy = 0
    }

    private func updateLiveAccuracy() {
        liveAccuracy = session.overallAccuracy
    }
}
