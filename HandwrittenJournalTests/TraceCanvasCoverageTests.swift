import Testing
import UIKit
@testable import HandwrittenJournal

@MainActor
struct TraceCanvasCoverageTests {
    private func practice(_ character: String, face: JournalFace = .default) -> PracticeCanvasView {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 360, height: 440))
        view.setup = WritingSetup(face: face, size: .default, mode: .trace)
        view.centred = true
        view.autoSelectSoleGlyph = true
        view.text = character
        view.frame.size.height = max(440, view.requiredHeight(forWidth: 360))
        view.layoutIfNeeded()
        return view
    }

    private func ink(_ paths: [[CGPoint]]) -> [TracingStroke] {
        paths.map { path in
            TracingStroke(points: path.map {
                StrokePoint(location: $0, force: 0.5, isInside: false, letterIndex: -1)
            })
        }
    }

    @Test("Practice demonstrations complete the same shapes scored in every font with reviewed guides")
    func allFontPractice() {
        for face in JournalFace.all {
            for character in ["a", "g", "i", "I", "t", "1", "8"] {
                let view = practice(character, face: face)
                let paths = view.formationPaths(forGlyph: 0)
                #expect(!paths.isEmpty, "Missing \(face.id) \(character)")
                view.addInk(ink(paths))
                #expect(view.formationComplete, "Incomplete \(face.id) \(character)")
                #expect(view.phase == .traced(Character(character)))
                #expect(view.accuracyPercent >= 90, "Off-font demo: \(face.id) \(character)")
            }
        }
    }

    @Test("Retracing a tiny area does not complete a practice letter")
    func repeatedTinyMarks() throws {
        let view = practice("I")
        let first = try #require(view.formationPaths(forGlyph: 0).first?.first)
        let mark = ink([[first, CGPoint(x: first.x, y: first.y + 2)]])[0]
        view.addInk(Array(repeating: mark, count: 100))
        #expect(!view.formationComplete)
        #expect(view.phase != .traced("I"))
    }

    @Test("Changing the practice font remeasures the full alphabet without resizing the viewport")
    func changingFontKeepsEntireSheet() {
        FontRegistry.registerBundledFonts()
        let scroll = PracticeScrollView(frame: CGRect(x: 0, y: 0, width: 768, height: 600))
        scroll.canvas.text = PracticeSheet.text
        scroll.layoutIfNeeded()
        for face in JournalFace.all.reversed() {
            scroll.canvas.setup = WritingSetup(face: face, size: .default, mode: .trace)
            scroll.layoutIfNeeded()
            scroll.canvas.layoutIfNeeded()
            let expectedHeight = max(scroll.bounds.height,
                                     scroll.canvas.requiredHeight(forWidth: scroll.bounds.width))
            #expect(abs(scroll.contentSize.height - expectedHeight) < 0.5, "Stale height for \(face.id)")
            let glyphs = scroll.canvas.layout.glyphBoxes.filter(\.isScorable)
            #expect(glyphs.count == 62, "Clipped alphabet for \(face.id)")
            #expect(glyphs.last?.character == "9")
        }
    }

    @Test("Undoing an essential part makes practice incomplete again")
    func undoCompletion() throws {
        let view = practice("i")
        let paths = view.formationPaths(forGlyph: 0)
        #expect(paths.contains { $0.count == 1 }, "The dot must remain a distinct part")
        view.addInk(ink(paths))
        #expect(view.phase == .traced("i"))
        view.undo()
        #expect(!view.formationComplete)
        #expect(view.phase == .yourTurn("i"))
        #expect(view.isShowingStartDot)
        view.clearInk()
        #expect(!view.hasInk)
        #expect(view.accuracyPercent == 0)
    }

    @Test("A missing crossbar does not complete a practice letter")
    func missingCrossbar() throws {
        let view = practice("t")
        let paths = view.formationPaths(forGlyph: 0)
        #expect(paths.count >= 2)
        view.addInk(ink([try #require(paths.first)]))
        #expect(!view.formationComplete)
        #expect(view.phase != .traced("t"))
        view.addInk(ink(Array(paths.dropFirst())))
        #expect(view.phase == .traced("t"))
    }
}
