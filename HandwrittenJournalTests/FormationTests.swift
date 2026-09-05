import Testing
import CoreGraphics
import CoreText
import UIKit
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

/// The generated data is only useful if it fits the actual registered font at
/// runtime. These checks also catch wrong font lookup and ink-box placement bugs.
@MainActor
struct FontFormationTests {
    @Test("All 310 font/character combinations have final paths inside their own outlines")
    func everyFontFitsItsOwnGlyphs() {
        FontRegistry.registerBundledFonts()
        #expect(Set(JournalFace.all.map(\.id)) == ["andika", "comic", "jua", "sniglet", "varela"])
        for face in JournalFace.all {
            let font = face.uiFont(size: 128)
            let fitter = FormationFitter(font: font)
            for character in PracticeSheet.characters {
                let box = box(for: character, font: font)
                guard let strokes = fitter.placedStrokes(for: box), !strokes.isEmpty,
                      let outline = outline(for: character, box: box, font: font) else {
                    Issue.record("Missing \(face.label) \(character)"); continue
                }
                // Generation rasterization is at 512 pt. Half a point allows its
                // subpixel rounding without allowing paths outside an entire stem.
                let edge = outline.copy(strokingWithWidth: 1, lineCap: .round,
                                        lineJoin: .round, miterLimit: 2)
                for stroke in strokes {
                    #expect(!stroke.curved, "Placed paths must not be smoothed twice")
                    #expect(!stroke.points.isEmpty)
                    for point in samples(stroke.points, spacing: 1) {
                        #expect(outline.contains(point) || edge.contains(point),
                                "\(face.label) \(character) outside its outline at \(point)")
                    }
                }
            }
        }
    }

    @Test("Font-specific structures and essential pen lifts are preserved")
    func structuresAreFontSpecific() {
        FontRegistry.registerBundledFonts()
        for face in JournalFace.all {
            let font = face.uiFont(size: 96)
            let fitter = FormationFitter(font: font)
            for character in "ij" {
                let paths = fitter.placedStrokes(for: box(for: character, font: font))!
                #expect(paths.filter(\.isDot).count == 1, "\(face.label) \(character) needs its dot")
                #expect(paths.last?.isDot == true, "The dot follows the stem")
            }
            for character in "tT" {
                let paths = fitter.placedStrokes(for: box(for: character, font: font))!
                #expect(paths.count >= 2, "\(face.label) \(character) needs its crossbar")
            }
            let capitalI = fitter.placedStrokes(for: box(for: "I", font: font))!
            let serifI = face.id == "andika" || face.id == "comic"
            #expect(capitalI.count == (serifI ? 3 : 1), "\(face.label) I must match its serifs")
            if face.id == "jua" {
                #expect(fitter.placedStrokes(for: box(for: "a", font: font))?.count == 2)
                #expect(fitter.placedStrokes(for: box(for: "t", font: font))?.count == 2)
            }
        }
        // Varela's two-storey a is not a scaled copy of Jua's single-storey a.
        let jua = LetterFormations.formation(for: "a", fontName: "Jua-Regular")!
        let varela = LetterFormations.formation(for: "a", fontName: "VarelaRound-Regular")!
        #expect(jua.strokes[0].points != varela.strokes[0].points)
        #expect(LetterFormations.formation(for: "é", fontName: "Jua-Regular") == nil)
        #expect(LetterFormations.formation(for: "a", fontName: "UnsupportedFont") == nil)
    }

    @Test("Reviewed corners and medial twigs do not become extra required pen lifts")
    func reviewedShapesKeepMeaningfulStrokes() {
        let singleGestures: [(String, Character)] = [
            ("Jua-Regular", "2"), ("Andika-Bold", "Z"),
            ("ComicNeue-Bold", "3"), ("VarelaRound-Regular", "3"),
        ]
        for (fontName, character) in singleGestures {
            let formation = LetterFormations.formation(for: character, fontName: fontName)!
            #expect(formation.strokes.count == 1, "\(fontName) \(character) is one continuous gesture")
        }
        for character in "FN" {
            let formation = LetterFormations.formation(for: character, fontName: "Sniglet-ExtraBold")!
            #expect(formation.strokes.count == 3, "\(character) must not require an incidental fourth twig")
        }
        // The waist is part of the continuous 3, even though its medial graph
        // represents that inward turn as a branch.
        let waistChecks: [(String, CGFloat)] = [("ComicNeue-Bold", 0.60), ("VarelaRound-Regular", 0.45)]
        for (fontName, waistX) in waistChecks {
            let points = LetterFormations.formation(for: "3", fontName: fontName)!.strokes[0].points
            #expect(points.contains { $0.y > 0.35 && $0.y < 0.57 && $0.x < waistX })
        }
    }

    @Test("Comic Neue g flows down its right stem and left around the hook")
    func comicGHasOneDirectedStemAndHook() {
        let formation = LetterFormations.formation(for: "g", fontName: "ComicNeue-Bold")!
        #expect(formation.strokes.count == 2, "The bowl and the stem with its hook are the two gestures")
        guard formation.strokes.count == 2,
              let start = formation.strokes[1].points.first,
              let end = formation.strokes[1].points.last else { return }
        #expect(start.x > 0.75 && start.y < 0.2)
        #expect(end.x < 0.35 && end.y > 0.8)
        #expect(formation.strokes[1].points.prefix { $0.y < 0.7 }.allSatisfy { $0.x > 0.7 },
                "The descending stem must not detour left around the bowl")
    }

    private func box(for character: Character, font: UIFont) -> MaskRenderer.GlyphBox {
        let width = (String(character) as NSString).size(withAttributes: [.font: font]).width
        return .init(charIndex: 0, wordIndex: 0, lineIndex: 0, character: character,
                     rect: CGRect(x: 20, y: 30, width: width, height: font.lineHeight))
    }

    private func outline(for character: Character, box: MaskRenderer.GlyphBox, font: UIFont) -> CGPath? {
        let utf16 = Array(String(character).utf16)
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font as CTFont, utf16, &glyph, 1),
              let path = CTFontCreatePathForGlyph(font as CTFont, glyph, nil) else { return nil }
        var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                         tx: box.rect.minX, ty: box.rect.minY + font.ascender)
        return path.copy(using: &transform)
    }

    private func samples(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var result = [first]
        for (a, b) in zip(points, points.dropFirst()) {
            let steps = max(1, Int(ceil(hypot(b.x - a.x, b.y - a.y) / spacing)))
            for index in 1...steps {
                let t = CGFloat(index) / CGFloat(steps)
                result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return result
    }
}
