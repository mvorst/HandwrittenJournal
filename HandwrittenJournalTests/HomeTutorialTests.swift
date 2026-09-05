import Testing
import UIKit
@testable import HandwrittenJournal

/// §4.3 (v3.11) — Journal Home's first-visit tour.
///
/// A new profile is shown its two tiles one at a time, *Practice my letters* first; only
/// a tap on the tile in hand moves the tour on, each step has its line, and the bubble
/// and the finger sit on the tile wherever the layout puts it.
@MainActor
struct HomeTutorialTests {

    @Test("A new profile owes the tour from its first tile; a tap on the tile in hand moves it on")
    func stepsInOrder() {
        let profile = UserProfile(name: "Ada")
        #expect(profile.homeTutorialStep == .practice)
        #expect(HomeTutorialStep.practice.tile == .practice)
        #expect(HomeTutorialStep.practice.advanced(byTapping: .newEntry) == .practice, "the other tile is under the scrim")
        #expect(HomeTutorialStep.practice.advanced(byTapping: .practice) == .newEntry)
        #expect(HomeTutorialStep.newEntry.tile == .newEntry)
        #expect(HomeTutorialStep.newEntry.advanced(byTapping: .practice) == .newEntry)
        #expect(HomeTutorialStep.newEntry.advanced(byTapping: .newEntry) == .done)
        #expect(HomeTutorialStep.done.tile == nil)
        #expect(HomeTutorialStep.done.advanced(byTapping: .newEntry) == .done)
        profile.homeTutorialStep = .newEntry
        #expect(profile.homeTutorialStepRaw == 1)
        profile.homeTutorialStepRaw = 99
        #expect(profile.homeTutorialStep == .done, "a value no build knows never nags")
    }

    @Test("Each step says its line, the bubble shows the same words, and the greeting waits for the tour")
    func lines() {
        #expect(HomeTutorialStep.practice.cue == .homeHowPractice)
        #expect(HomeTutorialStep.newEntry.cue == .homeHowNewEntry)
        #expect(HomeTutorialStep.done.cue == nil)
        #expect(Voice.Cue.homeHowPractice.text == "Let's start with your letters. Tap Practice my letters.")
        #expect(Voice.Cue.homeHowNewEntry.text == "Now let's write in your journal. Tap New Entry and tell me about your day.")
        #expect(Voice.Cue.homeHowPractice.clipID == "home-how-practice")
        #expect(Voice.Cue.homeHowNewEntry.clipID == "home-how-new-entry")
        #expect(HomeTutorialStep.newEntry.text == Voice.Cue.homeHowNewEntry.text)
        #expect(HomeTutorialStep.done.text.isEmpty)
        // As Home appears: the greeting only once the tour is done — the tour's line
        // takes its place until then.
        #expect(HomeTutorialStep.practice.greeting == nil)
        #expect(HomeTutorialStep.newEntry.greeting == nil)
        #expect(HomeTutorialStep.done.greeting == .home)
        #expect(Voice.duration(of: .homeHowPractice) > 2, "the line is a real recording")
        #expect(Voice.duration(of: .homeHowNewEntry) > 2)
    }

    @Test("In portrait the bubble sits under the tile with its tail on the tile, inside the margin")
    func portraitPlacement() {
        let screen = CGSize(width: 834, height: 1194)
        // Frame 9's tiles (WIREFRAME_SPEC §13.2), in screen points.
        let newEntry = CGRect(x: 24, y: 136, width: 486, height: 128)
        let practice = CGRect(x: 526, y: 136, width: 284, height: 128)
        let margin = Tokens.Layout.screenMargin

        let p = TourPlacement.place(target: practice, in: screen, bubbleHeight: 160)
        #expect(p.tail == .top)
        #expect(p.hole == practice.insetBy(dx: -TourPlacement.holeInset, dy: -TourPlacement.holeInset))
        #expect(p.bubble.minY == p.hole.maxY + TourPlacement.gap)
        #expect(p.bubble.width == TourPlacement.bubbleWidth)
        #expect(p.bubble.maxX == screen.width - margin, "the bubble stops at the margin, not centred off the screen")
        #expect(abs(p.bubble.minX + p.tailCenter - practice.midX) < 0.5, "the tail still points at the tile")
        #expect(practice.contains(p.fingerTip))
        #expect(p.fingerTip.x > practice.midX, "the finger lands right of centre")

        let n = TourPlacement.place(target: newEntry, in: screen, bubbleHeight: 160)
        #expect(n.tail == .top)
        #expect(abs(n.bubble.midX - newEntry.midX) < 0.5, "room to centre it under the tile")
        #expect(abs(n.tailCenter - n.bubble.width / 2) < 0.5)
        #expect(newEntry.contains(n.fingerTip))
    }

    @Test("In landscape the bubble sits beside the tile, in the journal column")
    func landscapePlacement() {
        let screen = CGSize(width: 1194, height: 834)
        let margin = Tokens.Layout.screenMargin
        // The deck is a column in the 560 pt dashboard (§4.3, v3.3).
        let practice = CGRect(x: 24, y: 280, width: 560, height: 128)
        let p = TourPlacement.place(target: practice, in: screen, bubbleHeight: 160)
        #expect(p.tail == .leading)
        #expect(p.bubble.minX == p.hole.maxX + TourPlacement.gap)
        #expect(p.bubble.width == TourPlacement.bubbleWidth)
        #expect(p.bubble.maxX <= screen.width - margin)
        #expect(abs(p.bubble.midY - practice.midY) < 0.5, "centred on the tile")
        #expect(abs(p.bubble.minY + p.tailCenter - practice.midY) < 0.5)

        // A tile near the top: the bubble stays inside the margin and the tail follows.
        let high = CGRect(x: 24, y: 30, width: 560, height: 128)
        let h = TourPlacement.place(target: high, in: screen, bubbleHeight: 160)
        #expect(h.bubble.minY == margin)
        #expect(abs(h.bubble.minY + h.tailCenter - high.midY) < 0.5)

        // No room beside it: under it, as in portrait.
        let wide = CGRect(x: 24, y: 280, width: 1000, height: 128)
        let w = TourPlacement.place(target: wide, in: screen, bubbleHeight: 160)
        #expect(w.tail == .top)
        #expect(w.bubble.maxX <= screen.width - margin)
    }

    @Test("A narrow screen narrows the bubble rather than losing its edge")
    func narrowScreen() {
        // An iPad mini in portrait: 744 pt across.
        let screen = CGSize(width: 744, height: 1133)
        let practice = CGRect(x: 436, y: 136, width: 284, height: 128)
        let p = TourPlacement.place(target: practice, in: screen, bubbleHeight: 160)
        #expect(p.bubble.minX >= Tokens.Layout.screenMargin)
        #expect(p.bubble.maxX <= screen.width - Tokens.Layout.screenMargin)
        #expect(p.bubble.width == TourPlacement.bubbleWidth)
        let tiny = TourPlacement.place(target: practice, in: CGSize(width: 400, height: 800), bubbleHeight: 160)
        #expect(tiny.bubble.width == 400 - 2 * Tokens.Layout.screenMargin)
    }

    @Test("The scrim's hole is where the tile is, and the bubble's tail stays on its card")
    func shapes() {
        // `CGPath.contains(using:)` honours the fill rule; SwiftUI's `Path.contains` does
        // not, and the scrim is drawn and hit-tested even-odd.
        let hole = CGRect(x: 100, y: 100, width: 200, height: 100)
        let scrim = CutOutShape(hole: hole, radius: 20).path(in: CGRect(x: 0, y: 0, width: 800, height: 600)).cgPath
        #expect(scrim.contains(CGPoint(x: 50, y: 50), using: .evenOdd), "the scrim")
        #expect(!scrim.contains(CGPoint(x: 200, y: 150), using: .evenOdd), "the hole — the tile's own tap")
        #expect(!scrim.contains(CGPoint(x: 102, y: 150), using: .evenOdd), "just inside the hole's edge")
        #expect(scrim.contains(CGPoint(x: 98, y: 150), using: .evenOdd), "just outside it")

        let frame = CGRect(x: 0, y: 0, width: 400, height: 160)
        let centred = SpeechBubbleShape(radius: 20, tail: .top, tailCenter: 300, tailLength: 14, tailWidth: 28)
            .path(in: frame).cgPath
        #expect(centred.contains(CGPoint(x: 200, y: 100), using: .winding), "the card")
        #expect(!centred.contains(CGPoint(x: 200, y: 4), using: .winding), "above the card, away from the tail")
        #expect(centred.contains(CGPoint(x: 300, y: 4), using: .winding), "the tail, where it was asked for")
        // A tail asked for beyond the corner is pulled back onto the straight edge.
        let cornered = SpeechBubbleShape(radius: 20, tail: .top, tailCenter: 395, tailLength: 14, tailWidth: 28)
            .path(in: frame).cgPath
        #expect(cornered.contains(CGPoint(x: 366, y: 4), using: .winding), "clamped inside the corner radius")
        #expect(!cornered.contains(CGPoint(x: 395, y: 4), using: .winding))
        // Beside the tile: the tail on the leading edge, at the tile's centre line.
        let beside = SpeechBubbleShape(radius: 20, tail: .leading, tailCenter: 64, tailLength: 14, tailWidth: 28)
            .path(in: frame).cgPath
        #expect(beside.contains(CGPoint(x: 4, y: 64), using: .winding), "the tail")
        #expect(!beside.contains(CGPoint(x: 4, y: 120), using: .winding))
        #expect(beside.contains(CGPoint(x: 200, y: 80), using: .winding))
    }
}
