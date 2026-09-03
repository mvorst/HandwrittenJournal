import Testing
import UIKit
@testable import HandwrittenJournal

/// §8.1b — the remediation modal's one-letter sheet centres its row. The glyph box the
/// scorer uses, the mask it scores against and the guide the child sees all come from
/// the same centred frame, so the letter sits in the middle and is graded there.
@MainActor
struct PracticeSheetCentringTests {

    static let canvas = CGSize(width: 870, height: 440)

    @Test("A centred single letter lands mid-frame; a left one does not")
    func centredLetterIsMidFrame() {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup(face: .default, size: .default, mode: .trace)

        let left = MaskRenderer().generate(text: "h", setup: setup, canvasSize: Self.canvas,
                                           screenScale: 2, alignment: .left)
        let centred = MaskRenderer().generate(text: "h", setup: setup, canvasSize: Self.canvas,
                                              screenScale: 2, alignment: .center)
        let frameMid = centred.frameRect.midX

        #expect(left.glyphBoxes.count == 1 && centred.glyphBoxes.count == 1)
        #expect(abs(centred.glyphBoxes[0].rect.midX - frameMid) < 2,
                "centred box midX \(centred.glyphBoxes[0].rect.midX) vs frame \(frameMid)")
        #expect(left.glyphBoxes[0].rect.midX < frameMid - 100, "left alignment still hugs the edge")
    }

    @Test("The mask's ink is centred where the glyph box says it is")
    func maskFollowsTheCentredBox() {
        FontRegistry.registerBundledFonts()
        let setup = WritingSetup(face: .default, size: .default, mode: .trace)
        let renderer = MaskRenderer()
        let layout = renderer.generate(text: "h", setup: setup, canvasSize: Self.canvas,
                                       screenScale: 2, alignment: .center)
        let box = layout.glyphBoxes[0].rect
        // Every letter pixel is inside the box; the box is where the mask says the ink is.
        var inside = 0, outside = 0
        for y in stride(from: 0, to: Int(Self.canvas.height * 2), by: 2) {
            for x in stride(from: 0, to: Int(Self.canvas.width * 2), by: 2) where renderer.isLetterPixel(x: x, y: y) {
                let point = CGPoint(x: CGFloat(x) / 2, y: CGFloat(y) / 2)
                if box.insetBy(dx: -4, dy: -4).contains(point) { inside += 1 } else { outside += 1 }
            }
        }
        #expect(inside > 0)
        #expect(outside == 0, "\(outside) letter pixels fall outside the centred glyph box")
    }

    @Test("The practice canvas centres the modal's sheet and renders it")
    func practiceCanvasCentres() {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(origin: .zero, size: Self.canvas))
        view.setup = WritingSetup(face: .default, size: .default, mode: .trace)
        view.centred = true
        view.text = "h"
        view.layoutIfNeeded()
        let box = view.layout.glyphBoxes[0].rect
        #expect(abs(box.midX - view.layout.frameRect.midX) < 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
        if let dir = ProcessInfo.processInfo.environment["HJ_RENDER_DIR"], let data = image.pngData() {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("practice-centred.png"))
        }
    }
}
