import Testing
import UIKit
@testable import HandwrittenJournal

/// WIREFRAME_SPEC.md §3 (v3.3) — landscape. The page keeps the device's portrait width,
/// the rest of the window is the rail, and the rail sits on the side of the free hand.
struct ScreenLayoutTests {

    /// Portrait sizes of the iPads the app runs on: 13-inch, 11-inch, 10th gen / Air, mini.
    static let portraits: [CGSize] = [
        CGSize(width: 1032, height: 1376), CGSize(width: 834, height: 1194),
        CGSize(width: 820, height: 1180), CGSize(width: 744, height: 1133),
    ]

    @Test("The page keeps the device's portrait width in both orientations")
    func pageWidth() {
        for portrait in Self.portraits {
            let landscape = CGSize(width: portrait.height, height: portrait.width)
            let up = ScreenLayout(size: portrait), across = ScreenLayout(size: landscape)
            #expect(!up.isLandscape && across.isLandscape)
            #expect(up.pageWidth == portrait.width)
            #expect(across.pageWidth == portrait.width, "\(portrait) would re-wrap in landscape")
            #expect(up.railWidth == 0)
            #expect(across.railWidth == portrait.height - portrait.width)
        }
    }

    @Test("The rail has room for the scroll chevron and the finish control on every iPad")
    func railFitsItsControls() {
        for portrait in Self.portraits {
            let across = ScreenLayout(size: CGSize(width: portrait.height, height: portrait.width))
            let inner = across.railWidth - Tokens.Layout.screenMargin * 2
            // A 44 pt chevron, a gap, and the compact finish button (label ≈ 190 + 32 padding).
            #expect(inner >= 44 + Tokens.Space.s4 + 222, "\(portrait): rail is \(across.railWidth)")
        }
    }

    @Test("Auto keeps the rail on the side of the free hand; Left and Right pin it")
    func railSide() {
        #expect(RailSide.auto.resolved(isLeftHanded: false) == .left)
        #expect(RailSide.auto.resolved(isLeftHanded: true) == .right)
        for handed in [false, true] {
            #expect(RailSide.left.resolved(isLeftHanded: handed) == .left)
            #expect(RailSide.right.resolved(isLeftHanded: handed) == .right)
        }
        let across = ScreenLayout(size: CGSize(width: 1194, height: 834), railSide: .right)
        #expect(across.railOnRight && !across.railOnLeft)
        let up = ScreenLayout(size: CGSize(width: 834, height: 1194), railSide: .right)
        #expect(!up.railOnRight && !up.railOnLeft, "there is no rail in portrait")
    }

    @Test("Journal Home's dashboard column never takes more than half the width")
    func dashboardWidth() {
        let eleven = ScreenLayout(size: CGSize(width: 1194, height: 834))
        #expect(eleven.dashboardWidth == 560)
        let mini = ScreenLayout(size: CGSize(width: 1133, height: 744))
        let content = 1133 - Tokens.Layout.screenMargin * 2
        #expect(mini.dashboardWidth <= (content - Tokens.Layout.screenMargin) / 2)
        #expect(mini.dashboardWidth < 560)
    }

    @Test("A rotation keeps the row in hand in view")
    @MainActor
    func rotationKeepsRowInView() {
        FontRegistry.registerBundledFonts()
        let scroller = ScrollingCanvas()
        scroller.frame = CGRect(x: 0, y: 0, width: 834, height: 958)
        scroller.layoutWidth = 834
        scroller.apply(text: String(repeating: "Today we went to the park and I saw a big dog. ", count: 6),
                       setup: .default)
        scroller.layoutIfNeeded()
        let lines = scroller.canvas.layout.lineCount
        #expect(lines > 12, "the fixture must outrun both viewports")
        let row = lines - 2
        scroller.canvas.selectRow(row)
        scroller.scrollToLine(row, animated: false)
        #expect(scroller.canvas.selectedRow == row)

        // Landscape: the same width, a shorter window.
        scroller.frame = CGRect(x: 0, y: 0, width: 834, height: 762)
        scroller.layoutIfNeeded()

        guard let band = scroller.canvas.rect(forLine: row) else { Issue.record("no band for the row"); return }
        let visible = CGRect(origin: scroller.contentOffset, size: scroller.bounds.size)
        #expect(visible.contains(CGPoint(x: band.midX, y: band.midY)),
                "row \(row) at \(band) is outside \(visible)")
    }
}
