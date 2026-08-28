import Testing
import UIKit
@testable import HandwrittenJournal

/// The glyph boxes and the rendered mask must occupy the same space. They are produced by
/// two different CoreText calls, and when they drift, per-letter scoring silently
/// attributes a child's ink to the wrong letter.
///
/// This caught exactly that: `CTFrameGetLineOrigins` returns x relative to the frame path,
/// so the surface inset had to be added back.
struct MaskAlignmentTests {

    static let canvas = CGSize(width: 754, height: 530)

    private func inkBounds(_ renderer: MaskRenderer) -> CGRect? {
        var minRow = Int.max, maxRow = -1, minCol = Int.max, maxCol = -1
        for row in 0..<renderer.height {
            for col in 0..<renderer.width where renderer.isLetterPixel(x: col, y: row) {
                minRow = min(minRow, row); maxRow = max(maxRow, row)
                minCol = min(minCol, col); maxCol = max(maxCol, col)
            }
        }
        guard maxRow >= 0 else { return nil }
        let s = renderer.scale
        return CGRect(x: CGFloat(minCol) / s, y: CGFloat(minRow) / s,
                      width: CGFloat(maxCol - minCol) / s, height: CGFloat(maxRow - minRow) / s)
    }

    @Test("Every glyph box contains ink, and the ink lies inside the boxes")
    func boxesAndInkAgree() {
        FontRegistry.registerBundledFonts()
        for face in JournalFace.available {
            let renderer = MaskRenderer()
            let setup = WritingSetup(face: face, size: .size(id: "l"), mode: .trace)
            let layout = renderer.generate(text: "handwriting", setup: setup,
                                           canvasSize: Self.canvas, screenScale: 2)
            guard let ink = inkBounds(renderer) else { Issue.record("no ink for \(face.label)"); continue }

            let boxes = layout.glyphBoxes.filter(\.isScorable)
            #expect(!boxes.isEmpty)

            // The union of the boxes must cover the ink.
            var union = boxes[0].rect
            for box in boxes.dropFirst() { union = union.union(box.rect) }
            #expect(union.insetBy(dx: -2, dy: -2).contains(ink),
                    "\(face.label): boxes \(union) do not cover ink \(ink)")

            // And each box must sit on some ink of its own.
            for box in boxes {
                var found = false
                var x = box.rect.minX
                while x <= box.rect.maxX, !found {
                    var y = box.rect.minY
                    while y <= box.rect.maxY, !found {
                        if renderer.isLetterPixel(x: Int(x * renderer.scale), y: Int(y * renderer.scale)) { found = true }
                        y += 2
                    }
                    x += 2
                }
                #expect(found, "\(face.label): glyph '\(box.character)' has no ink in its box")
            }
        }
    }

    @Test("A point on a letter is attributed to that letter, not its neighbour")
    func attributionSurvivesTheInset() {
        FontRegistry.registerBundledFonts()
        let renderer = MaskRenderer()
        let layout = renderer.generate(text: "abcdefgh", setup: .default,
                                       canvasSize: Self.canvas, screenScale: 2)
        let boxes = layout.glyphBoxes.filter(\.isScorable)
        for (index, box) in boxes.enumerated() {
            #expect(renderer.glyphIndex(at: box.center, slack: 0) == index)
        }
    }
}
