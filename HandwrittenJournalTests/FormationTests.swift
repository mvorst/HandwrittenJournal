import Testing
import CoreGraphics
@testable import HandwrittenJournal

/// The practice sheet is only as good as its data: a missing formation means a letter
/// that never demos, and a wild coordinate draws a guide across the neighboring glyph.
struct FormationTests {

    @Test("Every character on the practice sheet has a formation")
    func sheetIsFullyCovered() {
        let characters = PracticeSheet.characters
        #expect(characters.count == 62)   // 26 + 26 + 10
        for character in characters {
            #expect(LetterFormations.formation(for: character) != nil,
                    "no formation for '\(character)'")
        }
    }

    @Test("Formations are sane: 1–4 strokes, coordinates near the unit box")
    func formationsAreSane() {
        for character in PracticeSheet.characters {
            guard let formation = LetterFormations.formation(for: character) else { continue }
            #expect((1...4).contains(formation.strokes.count), "'\(character)' stroke count")
            for stroke in formation.strokes {
                #expect(!stroke.points.isEmpty)
                if stroke.points.count == 1 {
                    // Dots belong to i and j alone.
                    #expect(character == "i" || character == "j", "unexpected dot in '\(character)'")
                }
                for p in stroke.points {
                    #expect(p.x > -0.3 && p.x < 1.3 && p.y > -0.3 && p.y < 1.3,
                            "'\(character)' point \(p) far outside the unit box")
                }
            }
        }
    }

    @Test("Placement maps the unit box onto the ink rect, endpoints preserved")
    func placementMapsIntoInkRect() {
        let stroke = FormationStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], curved: false)
        let rect = CGRect(x: 100, y: 50, width: 40, height: 80)
        let placed = FormationFitter.place(stroke, in: rect)
        #expect(placed.first == CGPoint(x: 100, y: 50))
        #expect(placed.last == CGPoint(x: 140, y: 130))
    }

    @Test("Chaikin smoothing keeps endpoints and adds points")
    func smoothingKeepsEndpoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]
        let smooth = FormationFitter.smooth(points)
        #expect(smooth.first == points.first)
        #expect(smooth.last == points.last)
        #expect(smooth.count > points.count)
    }
}
