import CoreGraphics

final class StrokeColorizer {
    private let maskRenderer: MaskRenderer
    private let tolerance: Int

    init(maskRenderer: MaskRenderer, tolerance: Int) {
        self.maskRenderer = maskRenderer
        self.tolerance = tolerance
    }

    func classify(point: CGPoint) -> Bool {
        return maskRenderer.isInsideLetter(point: point, tolerance: tolerance)
    }
}
