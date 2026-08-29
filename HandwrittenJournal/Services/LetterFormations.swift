import UIKit
import CoreText

/// The practice sheet — the fixed text of frame 44 and the one place it is defined.
enum PracticeSheet {
    static let text = """
    Aa Bb Cc Dd Ee
    Ff Gg Hh Ii Jj Kk
    Ll Mm Nn Oo Pp
    Qq Rr Ss Tt Uu
    Vv Ww Xx Yy Zz
    0 1 2 3 4 5 6 7 8 9
    """

    /// Every character a formation must exist for.
    static var characters: [Character] { text.filter { !$0.isWhitespace } }
}

/// One pen-down-to-pen-up gesture of a letter's school formation, authored in the
/// glyph's **ink-box space**: (0,0) is the top-left of the letter's actual drawn
/// bounds, (1,1) the bottom-right, y down. A single point is a pen dot (the dot of
/// an i or j).
struct FormationStroke {
    let points: [CGPoint]
    /// Curved strokes are corner-cut smooth before rendering; straight ones keep
    /// their corners (the arms of an E must not bow).
    let curved: Bool

    var isDot: Bool { points.count == 1 }
}

/// How a character is written: its strokes, in the order a US classroom teaches them
/// (ball-and-stick print), each with a start, a direction, and an end.
///
/// Hand-fitted to **Jua** — the faces differ enough (bowl shapes, hooks, the tail of
/// the y) that one set of paths cannot be honest for all five, so the practice screen
/// locks to Jua and these coordinates are eyeballed against its outlines. Tweaking a
/// letter is editing one line of this file.
struct LetterFormation {
    let strokes: [FormationStroke]
}

enum LetterFormations {

    static func formation(for character: Character) -> LetterFormation? {
        all[character]
    }

    // MARK: - Authoring helpers

    private typealias P = (x: CGFloat, y: CGFloat)

    private static func pts(_ list: [P]) -> [CGPoint] { list.map { CGPoint(x: $0.x, y: $0.y) } }
    private static func line(_ list: P...) -> FormationStroke { FormationStroke(points: pts(list), curved: false) }
    private static func curve(_ list: P...) -> FormationStroke { FormationStroke(points: pts(list), curved: true) }
    private static func dot(_ x: CGFloat, _ y: CGFloat) -> FormationStroke {
        FormationStroke(points: [CGPoint(x: x, y: y)], curved: false)
    }

    /// Elliptical arc sampled in ink-box space. Degrees, y-down: 0° = right,
    /// 90° = bottom, 180° = left, 270° (or −90°) = top. Sweeping from a larger angle
    /// to a smaller one runs counterclockwise on screen — the direction school
    /// letterforms circle (like a c).
    private static func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                            _ from: CGFloat, _ to: CGFloat, steps: Int = 22) -> [P] {
        (0...steps).map { i in
            let t = from + (to - from) * CGFloat(i) / CGFloat(steps)
            let r = t * .pi / 180
            return (cx + rx * cos(r), cy + ry * sin(r))
        }
    }

    /// One curved stroke assembled from parts (a stem flowing into a bowl).
    private static func joined(_ parts: [P]...) -> FormationStroke {
        FormationStroke(points: pts(parts.flatMap { $0 }), curved: true)
    }

    // MARK: - The alphabet

    private static let all: [Character: LetterFormation] = build()

    private static func build() -> [Character: LetterFormation] {
        var f: [Character: LetterFormation] = [:]

        // Capitals — the box spans cap height to baseline.
        f["A"] = LetterFormation(strokes: [line((0.5, 0), (0.03, 1)),
                                           line((0.5, 0), (0.97, 1)),
                                           line((0.2, 0.63), (0.8, 0.63))])
        f["B"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           joined([(0.1, 0.02)], arc(0.5, 0.26, 0.42, 0.24, -90, 90),
                                                  [(0.1, 0.5)], arc(0.52, 0.75, 0.46, 0.25, -90, 90), [(0.1, 0.98)])])
        f["C"] = LetterFormation(strokes: [joined(arc(0.52, 0.5, 0.47, 0.48, -55, -305))])
        f["D"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           joined([(0.1, 0.02), (0.35, 0.02)], arc(0.35, 0.5, 0.6, 0.48, -90, 90), [(0.1, 0.98)])])
        f["E"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           line((0.1, 0.02), (0.95, 0.02)),
                                           line((0.1, 0.5), (0.85, 0.5)),
                                           line((0.1, 0.98), (0.95, 0.98))])
        f["F"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           line((0.1, 0.02), (0.95, 0.02)),
                                           line((0.1, 0.52), (0.8, 0.52))])
        f["G"] = LetterFormation(strokes: [joined(arc(0.5, 0.5, 0.46, 0.48, -55, -320)),
                                           line((0.55, 0.6), (0.96, 0.6))])
        f["H"] = LetterFormation(strokes: [line((0.08, 0), (0.08, 1)),
                                           line((0.92, 0), (0.92, 1)),
                                           line((0.08, 0.52), (0.92, 0.52))])
        f["I"] = LetterFormation(strokes: [line((0.5, 0), (0.5, 1))])
        f["J"] = LetterFormation(strokes: [joined([(0.78, 0), (0.78, 0.6)], arc(0.44, 0.6, 0.34, 0.37, 0, 190))])
        f["K"] = LetterFormation(strokes: [line((0.08, 0), (0.08, 1)),
                                           line((0.95, 0), (0.1, 0.55)),
                                           line((0.42, 0.42), (0.98, 1))])
        f["L"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 0.98), (0.95, 0.98))])
        f["M"] = LetterFormation(strokes: [line((0.05, 0), (0.05, 1)),
                                           line((0.05, 0), (0.5, 0.78)),
                                           line((0.5, 0.78), (0.95, 0)),
                                           line((0.95, 0), (0.95, 1))])
        f["N"] = LetterFormation(strokes: [line((0.07, 0), (0.07, 1)),
                                           line((0.07, 0), (0.93, 1)),
                                           line((0.93, 0), (0.93, 1))])
        f["O"] = LetterFormation(strokes: [joined(arc(0.5, 0.5, 0.46, 0.48, -90, -450))])
        f["P"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           joined([(0.1, 0.02)], arc(0.48, 0.28, 0.46, 0.26, -90, 90), [(0.1, 0.54)])])
        f["Q"] = LetterFormation(strokes: [joined(arc(0.5, 0.5, 0.46, 0.48, -90, -450)),
                                           line((0.6, 0.62), (0.98, 1))])
        f["R"] = LetterFormation(strokes: [line((0.1, 0), (0.1, 1)),
                                           joined([(0.1, 0.02)], arc(0.48, 0.28, 0.46, 0.26, -90, 90), [(0.1, 0.54)]),
                                           line((0.45, 0.55), (0.95, 1))])
        f["S"] = LetterFormation(strokes: [curve((0.88, 0.14), (0.7, 0.02), (0.42, 0.0), (0.18, 0.1), (0.12, 0.28),
                                                 (0.26, 0.44), (0.55, 0.52), (0.8, 0.62), (0.88, 0.78), (0.75, 0.94),
                                                 (0.45, 1.0), (0.16, 0.92), (0.08, 0.78))])
        f["T"] = LetterFormation(strokes: [line((0.5, 0.02), (0.5, 1)),
                                           line((0.02, 0.02), (0.98, 0.02))])
        f["U"] = LetterFormation(strokes: [joined([(0.07, 0), (0.07, 0.5)], arc(0.5, 0.52, 0.43, 0.46, 180, 0), [(0.93, 0)])])
        f["V"] = LetterFormation(strokes: [line((0.03, 0), (0.5, 1), (0.97, 0))])
        f["W"] = LetterFormation(strokes: [line((0.02, 0), (0.26, 1), (0.5, 0.22), (0.74, 1), (0.98, 0))])
        f["X"] = LetterFormation(strokes: [line((0.05, 0), (0.95, 1)),
                                           line((0.95, 0), (0.05, 1))])
        f["Y"] = LetterFormation(strokes: [line((0.05, 0), (0.5, 0.48)),
                                           line((0.95, 0), (0.5, 0.48), (0.5, 1))])
        f["Z"] = LetterFormation(strokes: [line((0.05, 0.02), (0.95, 0.02), (0.05, 0.98), (0.95, 0.98))])

        // Lowercase. x-height letters span x-height to baseline; ascender letters put
        // the x-height at about 0.32 of their taller box; descender letters put the
        // baseline at about 0.68 of theirs.
        f["a"] = LetterFormation(strokes: [joined(arc(0.42, 0.5, 0.38, 0.46, -40, -320)),
                                           line((0.93, 0.02), (0.93, 1))])
        f["b"] = LetterFormation(strokes: [line((0.08, 0), (0.08, 1)),
                                           joined([(0.08, 0.55)], arc(0.5, 0.66, 0.42, 0.32, -125, 125), [(0.08, 0.95)])])
        f["c"] = LetterFormation(strokes: [joined(arc(0.54, 0.5, 0.46, 0.47, -50, -310))])
        f["d"] = LetterFormation(strokes: [joined(arc(0.42, 0.66, 0.4, 0.32, -50, -310)),
                                           line((0.92, 0), (0.92, 1))])
        f["e"] = LetterFormation(strokes: [joined([(0.08, 0.56), (0.88, 0.56)], arc(0.5, 0.5, 0.44, 0.47, -8, -285))])
        f["f"] = LetterFormation(strokes: [curve((0.85, 0.12), (0.66, 0.02), (0.45, 0.03), (0.32, 0.14), (0.28, 0.32), (0.28, 1)),
                                           line((0.05, 0.4), (0.72, 0.4))])
        f["g"] = LetterFormation(strokes: [joined(arc(0.42, 0.34, 0.4, 0.33, -40, -320)),
                                           curve((0.92, 0), (0.92, 0.55), (0.86, 0.85), (0.62, 1.0), (0.32, 0.95), (0.14, 0.8))])
        f["h"] = LetterFormation(strokes: [line((0.08, 0), (0.08, 1)),
                                           joined([(0.08, 0.62)], arc(0.5, 0.62, 0.42, 0.3, 180, 360), [(0.92, 1)])])
        f["i"] = LetterFormation(strokes: [line((0.5, 0.32), (0.5, 1)),
                                           dot(0.5, 0.06)])
        f["j"] = LetterFormation(strokes: [curve((0.72, 0.3), (0.72, 0.75), (0.62, 0.95), (0.4, 1.0), (0.18, 0.92)),
                                           dot(0.72, 0.05)])
        f["k"] = LetterFormation(strokes: [line((0.08, 0), (0.08, 1)),
                                           line((0.85, 0.3), (0.1, 0.66)),
                                           line((0.4, 0.52), (0.92, 1))])
        f["l"] = LetterFormation(strokes: [line((0.5, 0), (0.5, 1))])
        f["m"] = LetterFormation(strokes: [line((0.06, 0.05), (0.06, 1)),
                                           joined([(0.06, 0.5)], arc(0.28, 0.45, 0.22, 0.42, 180, 360), [(0.5, 1)]),
                                           joined([(0.5, 0.5)], arc(0.72, 0.45, 0.22, 0.42, 180, 360), [(0.94, 1)])])
        f["n"] = LetterFormation(strokes: [line((0.07, 0.05), (0.07, 1)),
                                           joined([(0.07, 0.5)], arc(0.5, 0.45, 0.43, 0.42, 180, 360), [(0.93, 1)])])
        f["o"] = LetterFormation(strokes: [joined(arc(0.5, 0.5, 0.45, 0.46, -90, -450))])
        f["p"] = LetterFormation(strokes: [line((0.08, 0.05), (0.08, 1)),
                                           joined([(0.08, 0.12)], arc(0.5, 0.34, 0.42, 0.32, -125, 125), [(0.08, 0.58)])])
        f["q"] = LetterFormation(strokes: [joined(arc(0.42, 0.34, 0.4, 0.33, -40, -320)),
                                           line((0.92, 0), (0.92, 1))])
        f["r"] = LetterFormation(strokes: [line((0.09, 0.05), (0.09, 1)),
                                           joined([(0.09, 0.5)], arc(0.5, 0.45, 0.41, 0.4, 180, 320))])
        f["s"] = LetterFormation(strokes: [curve((0.86, 0.16), (0.66, 0.02), (0.4, 0.0), (0.18, 0.12), (0.14, 0.3),
                                                 (0.3, 0.44), (0.56, 0.52), (0.8, 0.62), (0.86, 0.78), (0.7, 0.94),
                                                 (0.42, 1.0), (0.16, 0.9), (0.1, 0.76))])
        f["t"] = LetterFormation(strokes: [curve((0.42, 0), (0.42, 0.72), (0.5, 0.93), (0.72, 1.0), (0.9, 0.94)),
                                           line((0.05, 0.28), (0.85, 0.28))])
        f["u"] = LetterFormation(strokes: [joined([(0.07, 0), (0.07, 0.5)], arc(0.5, 0.5, 0.43, 0.45, 180, 0), [(0.93, 0)]),
                                           line((0.93, 0), (0.93, 1))])
        f["v"] = LetterFormation(strokes: [line((0.03, 0), (0.5, 1), (0.97, 0))])
        f["w"] = LetterFormation(strokes: [line((0.02, 0), (0.26, 1), (0.5, 0.22), (0.74, 1), (0.98, 0))])
        f["x"] = LetterFormation(strokes: [line((0.05, 0), (0.95, 1)),
                                           line((0.95, 0), (0.05, 1))])
        f["y"] = LetterFormation(strokes: [joined([(0.06, 0), (0.06, 0.42)], arc(0.47, 0.44, 0.41, 0.24, 180, 0), [(0.88, 0)]),
                                           curve((0.88, 0), (0.88, 0.6), (0.82, 0.88), (0.6, 1.0), (0.34, 0.96), (0.16, 0.82))])
        f["z"] = LetterFormation(strokes: [line((0.05, 0.02), (0.95, 0.02), (0.05, 0.98), (0.95, 0.98))])

        // Digits — the box spans cap height to baseline.
        f["0"] = LetterFormation(strokes: [joined(arc(0.5, 0.5, 0.44, 0.48, -90, -450))])
        f["1"] = LetterFormation(strokes: [line((0.1, 0.22), (0.5, 0.02), (0.5, 1))])
        f["2"] = LetterFormation(strokes: [curve((0.1, 0.28), (0.16, 0.1), (0.38, 0.0), (0.64, 0.02), (0.84, 0.16),
                                                 (0.86, 0.38), (0.62, 0.62), (0.3, 0.82), (0.08, 0.97), (0.95, 0.97))])
        f["3"] = LetterFormation(strokes: [curve((0.12, 0.14), (0.3, 0.02), (0.6, 0.0), (0.82, 0.1), (0.86, 0.28),
                                                 (0.72, 0.44), (0.48, 0.5), (0.74, 0.55), (0.9, 0.7), (0.86, 0.88),
                                                 (0.62, 1.0), (0.3, 0.98), (0.1, 0.85))])
        f["4"] = LetterFormation(strokes: [line((0.62, 0.02), (0.06, 0.66), (0.94, 0.66)),
                                           line((0.72, 0.02), (0.72, 1))])
        f["5"] = LetterFormation(strokes: [curve((0.16, 0.02), (0.13, 0.42), (0.35, 0.36), (0.62, 0.4), (0.84, 0.55),
                                                 (0.88, 0.74), (0.72, 0.94), (0.42, 1.0), (0.14, 0.88)),
                                           line((0.16, 0.02), (0.9, 0.02))])
        f["6"] = LetterFormation(strokes: [curve((0.8, 0.02), (0.5, 0.16), (0.26, 0.42), (0.14, 0.68), (0.2, 0.88),
                                                 (0.44, 1.0), (0.7, 0.96), (0.86, 0.78), (0.82, 0.58), (0.6, 0.48),
                                                 (0.34, 0.52), (0.16, 0.66))])
        f["7"] = LetterFormation(strokes: [line((0.05, 0.02), (0.95, 0.02), (0.36, 1))])
        f["8"] = LetterFormation(strokes: [curve((0.8, 0.14), (0.58, 0.02), (0.3, 0.06), (0.18, 0.22), (0.3, 0.4),
                                                 (0.52, 0.48), (0.76, 0.58), (0.86, 0.74), (0.74, 0.92), (0.48, 1.0),
                                                 (0.24, 0.92), (0.14, 0.76), (0.26, 0.58), (0.5, 0.48), (0.7, 0.4),
                                                 (0.8, 0.22), (0.72, 0.08))])
        f["9"] = LetterFormation(strokes: [joined(arc(0.46, 0.3, 0.4, 0.29, -40, -400)),
                                           curve((0.86, 0.12), (0.86, 0.6), (0.8, 0.86), (0.62, 1.0))])
        return f
    }
}

// MARK: - Fitting to the real glyphs

/// Maps formation coordinates onto the actual ink of a laid-out glyph.
///
/// The layout's glyph boxes are advance boxes — pen position to pen position, full line
/// height — but formations are authored against the letter's drawn bounds. The fitter
/// asks CoreText for the glyph's outline path and computes those bounds once per
/// character, so a formation lands on the letter itself wherever it sits on the page.
@MainActor
final class FormationFitter {
    private var cache: [Character: CGRect?] = [:]
    private let font: UIFont

    init(font: UIFont) { self.font = font }

    /// The glyph's ink bounds in canvas coordinates, or a conservative inset of the
    /// advance box when the outline is unavailable.
    func inkRect(for box: MaskRenderer.GlyphBox) -> CGRect {
        let baseline = box.rect.minY + font.ascender
        if let bounds = pathBounds(for: box.character) {
            return CGRect(x: box.rect.minX + bounds.minX,
                          y: baseline - bounds.maxY,
                          width: bounds.width,
                          height: bounds.height)
        }
        return box.rect.insetBy(dx: box.rect.width * 0.12, dy: box.rect.height * 0.2)
    }

    /// Outline bounds relative to the pen position, y-up (CoreText's space).
    private func pathBounds(for character: Character) -> CGRect? {
        if let cached = cache[character] { return cached }
        var result: CGRect?
        let utf16 = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        if CTFontGetGlyphsForCharacters(font as CTFont, utf16, &glyphs, utf16.count),
           let glyph = glyphs.first, glyph != 0,
           let path = CTFontCreatePathForGlyph(font as CTFont, glyph, nil) {
            let bounds = path.boundingBoxOfPath
            if !bounds.isNull, bounds.width > 0, bounds.height > 0 { result = bounds }
        }
        cache[character] = result
        return result
    }

    /// A formation stroke as canvas-space points, corner-cut smooth when curved.
    nonisolated static func place(_ stroke: FormationStroke, in inkRect: CGRect) -> [CGPoint] {
        let mapped = stroke.points.map { p in
            CGPoint(x: inkRect.minX + p.x * inkRect.width,
                    y: inkRect.minY + p.y * inkRect.height)
        }
        return stroke.curved ? smooth(mapped) : mapped
    }

    /// Two rounds of Chaikin corner-cutting; endpoints stay put.
    nonisolated static func smooth(_ points: [CGPoint], rounds: Int = 2) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var current = points
        for _ in 0..<rounds {
            var next: [CGPoint] = [current[0]]
            for i in 0..<(current.count - 1) {
                let a = current[i], b = current[i + 1]
                next.append(CGPoint(x: a.x * 0.75 + b.x * 0.25, y: a.y * 0.75 + b.y * 0.25))
                next.append(CGPoint(x: a.x * 0.25 + b.x * 0.75, y: a.y * 0.25 + b.y * 0.75))
            }
            next.append(current[current.count - 1])
            current = next
        }
        return current
    }
}
