import Testing
import UIKit
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §4.11 (v3.1) — the sheet shows what is done: a letter that earned
/// today draws in its status colour, and the letter in hand never does.
@MainActor
struct PracticeSheetColourTests {

    private func makeSheet(text: String = "Il",
                           completed: [Character: Int],
                           colourBlind: Bool = false,
                           selectFirst: Bool = false) -> PracticeCanvasView {
        FontRegistry.registerBundledFonts()
        let canvas = PracticeCanvasView()
        canvas.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        canvas.colourBlind = colourBlind
        canvas.autoSelectSoleGlyph = selectFirst
        canvas.text = text
        canvas.completed = completed
        canvas.frame = CGRect(x: 0, y: 0, width: 612, height: 480)
        canvas.layoutIfNeeded()
        return canvas
    }

    /// A point on the letter's ink: the middle of its first taught stroke, which the
    /// formation fitter runs down the centre of the glyph's stroke.
    private func inkPoint(of canvas: PracticeCanvasView, glyph: Int, dx: CGFloat = 0) -> CGPoint {
        let path = canvas.formationPaths(forGlyph: glyph).first ?? []
        // The geometric middle — a two-point stroke's middle index would be its end,
        // under the demo's arrowhead.
        let a = path[(path.count - 1) / 2], b = path[path.count / 2]
        return CGPoint(x: (a.x + b.x) / 2 + dx, y: (a.y + b.y) / 2)
    }

    /// Renders the sheet and reads back one pixel as (r, g, b).
    private func pixel(of canvas: PracticeCanvasView, at point: CGPoint) -> (r: Int, g: Int, b: Int) {
        let w = Int(canvas.bounds.width), h = Int(canvas.bounds.height)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        canvas.layer.render(in: ctx)
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        let offset = (Int(point.y) * w + Int(point.x)) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    private func close(_ p: (r: Int, g: Int, b: Int), to hex: UInt32, within tolerance: Int = 28) -> Bool {
        let r = Int((hex >> 16) & 0xFF), g = Int((hex >> 8) & 0xFF), b = Int(hex & 0xFF)
        return abs(p.r - r) <= tolerance && abs(p.g - g) <= tolerance && abs(p.b - b) <= tolerance
    }

    @Test("Two points paints the letter green, one point paints it orange")
    func statusColours() {
        let canvas = makeSheet(completed: ["I": 2, "l": 1])
        #expect(close(pixel(of: canvas, at: inkPoint(of: canvas, glyph: 0)), to: 0x43A047))
        #expect(close(pixel(of: canvas, at: inkPoint(of: canvas, glyph: 1)), to: 0xF28522))
    }

    @Test("A letter that has not earned keeps the guide colour")
    func untouchedStaysGrey() {
        let canvas = makeSheet(completed: ["I": 2])
        let p = pixel(of: canvas, at: inkPoint(of: canvas, glyph: 1))
        #expect(p.r < 90 && p.g < 90 && p.b < 90, "guide-text is black at 80% over paper: \(p)")
    }

    @Test("The colour-blind scheme uses the page's blue and orange")
    func colourBlindPair() {
        let canvas = makeSheet(completed: ["I": 2, "l": 1], colourBlind: true)
        #expect(close(pixel(of: canvas, at: inkPoint(of: canvas, glyph: 0)), to: 0x007AFF))
        #expect(close(pixel(of: canvas, at: inkPoint(of: canvas, glyph: 1)), to: 0xFF9500))
    }

    @Test("The letter in hand stays in the guide colour even when it has already earned")
    func selectedLetterStaysGuideColoured() {
        // Selecting glyph 0 plays its demo down the middle of the stroke; sample beside
        // the taught path, still well inside Jua's stem at the sheet's size.
        let canvas = makeSheet(completed: ["I": 2, "l": 2], selectFirst: true)
        let inHand = pixel(of: canvas, at: inkPoint(of: canvas, glyph: 0, dx: 10))
        #expect(inHand.r < 90 && inHand.g < 90 && inHand.b < 90, "the selected I must not go green: \(inHand)")
        #expect(close(pixel(of: canvas, at: inkPoint(of: canvas, glyph: 1)), to: 0x43A047))
    }

    @Test("Status colours by points")
    func statusColourTable() {
        #expect(PracticeCanvasView.statusColour(points: 0, colourBlind: false) == nil)
        #expect(PracticeCanvasView.statusColour(points: 1, colourBlind: false) == UIColor(Tokens.Colour.starOn))
        #expect(PracticeCanvasView.statusColour(points: 2, colourBlind: false) == UIColor(Tokens.Colour.success))
        #expect(PracticeCanvasView.statusColour(points: 3, colourBlind: false) == UIColor(Tokens.Colour.success))
        #expect(PracticeCanvasView.statusColour(points: 2, colourBlind: true) == UIColor(Tokens.Colour.inkInsideCB))
        #expect(PracticeCanvasView.statusColour(points: 1, colourBlind: true) == UIColor(Tokens.Colour.inkOutsideCB))
    }
}

/// The ledger read the sheet needs: today's letters and what each earned.
struct PracticeLettersTests {

    @Test("Today's letters come back with their points; other days and junk are ignored")
    func lettersForToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 12))!
        let profile = UserProfile(name: "Milo")
        profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar)
        profile.awardPractice(character: "g", followedOrder: false, on: day, calendar: calendar)
        profile.practiceLedger["2026-03-03|Z"] = 2
        profile.practiceLedger["2026-03-04|"] = 2
        profile.practiceLedger["garbage"] = 2
        #expect(profile.practiceLetters(on: day, calendar: calendar) == ["G": 2, "g": 1])
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        #expect(profile.practiceLetters(on: tomorrow, calendar: calendar).isEmpty)
    }
}
