import Testing
import UIKit
@testable import HandwrittenJournal

/// v3.11 — the tour's spotlight beyond Journal Home: the practice sheet's first tap on
/// the big A (§4.11, frame 63) and the first entry's tap on the microphone (§4.4,
/// frame 64). Each is owed once per profile, each points at a real thing on the screen,
/// and the bubble says what the voice says.
@MainActor
struct TourTests {

    @Test("A new profile owes the sheet's first tap, and the line names the big A")
    func firstTapOnTheSheet() {
        let profile = UserProfile(name: "Ada")
        #expect(!profile.practiceFirstTapSeen)
        #expect(Voice.Cue.practiceHowTapA.text == "Tap the big A and watch how it's written.")
        #expect(Voice.Cue.practiceHowTapA.clipID == "practice-how-tap-a")
        #expect(Voice.duration(of: .practiceHowTapA) > 1, "the line is a real recording")
        #expect(PracticeView.tourLetter == "A")
    }

    @Test("The spotlight finds the big A: the sheet's first glyph, top left, in the surface's space")
    func bigAOnTheSheet() throws {
        FontRegistry.registerBundledFonts()
        let scroll = PracticeScrollView(frame: CGRect(x: 0, y: 0, width: 834, height: 1050))
        scroll.canvas.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        scroll.canvas.text = PracticeSheet.text
        scroll.layoutIfNeeded()
        scroll.canvas.layoutIfNeeded()
        let controller = PracticeController()
        controller.attach(scroll.canvas)

        let a = try #require(controller.frame(of: "A"))
        #expect(a.minX < 120 && a.minY < 250, "the big A leads the first row: \(a)")
        #expect(a.width > 40 && a.height > 60)
        let littleA = try #require(controller.frame(of: "a"))
        #expect(littleA.minX >= a.maxX - 1, "the little a follows it")
        #expect(controller.frame(of: "§") == nil, "nothing to point at")

        // Under the A in portrait, stopped at the margin; its tail on the A.
        let p = TourPlacement.place(target: a, in: CGSize(width: 834, height: 1194), bubbleHeight: 160)
        #expect(p.tail == .top)
        #expect(p.bubble.minX == Tokens.Layout.screenMargin)
        #expect(abs(p.bubble.minX + p.tailCenter - a.midX) < 0.5)
        #expect(a.contains(p.fingerTip))
    }

    @Test("A new profile owes the first entry's tap; the microphone's hole is a circle under a bubble")
    func firstTapOnTheMicrophone() {
        let profile = UserProfile(name: "Ada")
        #expect(!profile.writeFirstTapSeen)
        #expect(Voice.Cue.startTalking.text == "Tap the microphone and start talking.")
        // The stage mic on an 11-inch iPad in portrait: 176 across, low on the page.
        let mic = CGRect(x: 329, y: 759, width: 176, height: 176)
        let p = TourPlacement.place(target: mic, in: CGSize(width: 834, height: 1210), bubbleHeight: 158)
        #expect(p.hole.width == 192 && p.hole.height == 192)
        #expect(mic.width / 2 + TourPlacement.holeInset == p.hole.width / 2, "the hole's radius makes it a circle")
        #expect(p.tail == .top)
        #expect(abs(p.bubble.midX - mic.midX) < 0.5)
        #expect(p.bubble.maxY <= 1210 - Tokens.Layout.screenMargin, "the bubble stays on the page")
        #expect(mic.contains(p.fingerTip))
        // Landscape: beside the microphone, over the rail.
        let wide = TourPlacement.place(target: CGRect(x: 329, y: 500, width: 176, height: 176), in: CGSize(width: 1194, height: 834), bubbleHeight: 158)
        #expect(wide.tail == .leading)
        #expect(wide.bubble.maxX <= 1194 - Tokens.Layout.screenMargin)
    }
}
