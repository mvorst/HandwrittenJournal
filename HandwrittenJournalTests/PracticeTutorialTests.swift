import Testing
import UIKit
@testable import HandwrittenJournal

/// §4.11 (v3.8) — *How to trace a letter* and the blue dot.
///
/// The tutorial is owed once per profile, its steps follow the sheet's own loop, and
/// each step has its line. The dot sits exactly where the letter's first stroke begins,
/// appears with the demo, and leaves when the letter is traced.
@MainActor
struct PracticeTutorialTests {

    @Test("A new profile owes the tutorial; a visit settles it")
    func owedOncePerProfile() {
        let profile = UserProfile(name: "Milo")
        #expect(!profile.practiceTutorialSeen)
        profile.practiceTutorialSeen = true
        #expect(profile.practiceTutorialSeen)
    }

    @Test("The steps follow the sheet's loop: watch, start at the dot, trace, done")
    func stepsFollowTheLoop() {
        #expect(PracticeTutorialStep.current(phase: .idle) == .watch)
        #expect(PracticeTutorialStep.current(phase: .watching("a")) == .start)
        #expect(PracticeTutorialStep.current(phase: .yourTurn("a")) == .trace)
        #expect(PracticeTutorialStep.current(phase: .traced("a")) == .done)
        // The arrows wait for the first line to be said, or a beat when the voice is off.
        #expect(abs(PracticeTutorialOverlay.introDelay(voiceOn: true, line: 4.2) - 4.6) < 0.001)
        #expect(PracticeTutorialOverlay.introDelay(voiceOn: false, line: 4.2) == 0.9)
        #expect(PracticeTutorialOverlay.introDelay(voiceOn: true, line: 0) == 0.9, "no clip, no wait")
        #expect(Voice.duration(of: .practiceHowWatch) > 2, "the first line is a real recording")
        #expect(PracticeTutorialStep.taught == [.watch, .start, .trace])
        #expect(PracticeTutorialStep.watch.state(now: .trace) == .done)
        #expect(PracticeTutorialStep.trace.state(now: .trace) == .current)
        #expect(PracticeTutorialStep.trace.state(now: .start) == .waiting)
    }

    @Test("Each step is said aloud, in the sheet's words")
    func lines() {
        #expect(Voice.Cue.practiceHowWatch.text == "Here's how to practice a letter. Touch it, and watch how it's written.")
        #expect(Voice.Cue.practiceHowStart.text == "See the blue dot? That's where you start. Follow the arrows.")
        #expect(Voice.Cue.practiceHowTrace.text == "Now trace the letter with your pencil. Green ink is on the letter, red ink is off. Try it!")
        #expect(Voice.Cue.practiceHowDone.text == "That's it! Now pick any letter on the sheet and trace it.")
        #expect(Voice.Cue.practiceHowStart.clipID == "practice-how-start")
        #expect(PracticeTutorialStep.start.text.contains("blue dot"))
    }

    @Test("The blue dot sits where the first stroke begins, on the letter")
    func dotMarksTheFirstStroke() {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        view.centred = true
        view.text = PracticeTutorialOverlay.letter
        view.layoutIfNeeded()

        let dot = try! #require(view.startPoint(forGlyph: 0))
        let taught = try! #require(view.formationPaths(forGlyph: 0).first?.first)
        #expect(abs(dot.x - taught.x) < 0.5 && abs(dot.y - taught.y) < 0.5,
                "the dot \(dot) is not where the taught path starts \(taught)")
        #expect(view.layout.glyphBoxes[0].rect.insetBy(dx: -4, dy: -4).contains(dot))
        // A little a begins its bowl on the right-hand side, not the left (§4.11).
        #expect(dot.x > view.layout.glyphBoxes[0].rect.midX)
    }

    @Test("No ink until the arrows have finished: the sheet watches first, then writes")
    func arrowsFirst() async throws {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        view.centred = true
        #expect(!view.acceptsInk, "nothing chosen, nothing to ink")
        view.autoSelectSoleGlyph = true
        view.text = "l"   // one short stroke — the quickest demo on the sheet
        view.layoutIfNeeded()
        #expect(view.phase == .watching("l"))
        #expect(!view.acceptsInk, "the arrows are drawing — the pen is a spectator")
        // The demo ends on the main queue when its last stroke has drawn.
        for _ in 0..<50 where !view.acceptsInk {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(view.phase == .yourTurn("l"))
        #expect(view.acceptsInk, "the demo handed over — now the pen writes")
    }

    @Test("Watch again replays the arrows: the demo draws itself a second time")
    func watchAgainReplays() async throws {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        view.centred = true
        view.text = "l"
        view.layoutIfNeeded()
        #expect(view.phase == .idle, "the tutorial's sheet waits for its cue")
        view.startOverWithDemo()
        #expect(view.phase == .watching("l"), "on cue, the first letter is chosen and shown")
        for _ in 0..<50 where !view.acceptsInk { try await Task.sleep(for: .milliseconds(100)) }
        #expect(view.phase == .yourTurn("l"))

        view.startOverWithDemo()
        #expect(view.phase == .watching("l"), "the arrows are playing again")
        #expect(!view.acceptsInk)
        let strokes = (view.layer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.name == "stroke" }
        #expect(!strokes.isEmpty)
        #expect(strokes.allSatisfy { $0.animation(forKey: "draw") != nil }, "each stroke draws itself")
        for _ in 0..<50 where !view.acceptsInk { try await Task.sleep(for: .milliseconds(100)) }
        #expect(view.phase == .yourTurn("l"), "and hands over again when done")
    }

    @Test("The controller drives the newest sheet still alive, not the last one made")
    func controllerFollowsTheLiveSheet() {
        FontRegistry.registerBundledFonts()
        let controller = PracticeController()
        func sheet() -> PracticeCanvasView {
            let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
            view.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
            view.centred = true
            view.text = "l"
            view.layoutIfNeeded()
            view.onStateChange = { [weak controller] in controller?.sync() }
            return view
        }
        let shown = sheet()
        controller.attach(shown)
        // SwiftUI tries a second layout branch and throws it away (landscape, v3.8).
        var discarded: PracticeCanvasView? = sheet()
        controller.attach(discarded!)
        controller.detach(discarded!)
        discarded = nil
        controller.startOverWithDemo()
        #expect(shown.phase == .watching("l"), "the sheet on screen got the demo")
        #expect(controller.phase == .watching("l"))
    }

    @Test("The dot appears with the demo and leaves when the letter is traced")
    func dotComesAndGoes() {
        FontRegistry.registerBundledFonts()
        let view = PracticeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.setup = WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
        view.centred = true
        view.autoSelectSoleGlyph = true
        view.text = PracticeTutorialOverlay.letter
        view.layoutIfNeeded()
        #expect(view.isShowingStartDot, "a chosen letter shows where to begin")

        // Trace the taught path exactly: enough good ink flips the letter.
        let strokes = view.formationPaths(forGlyph: 0).map { path in
            var stroke = TracingStroke()
            for point in path { stroke.append(StrokePoint(location: point, force: 0.5, isInside: true, letterIndex: 0)) }
            return stroke
        }
        view.addInk(strokes)
        #expect(view.phase == .traced("a"))
        #expect(!view.isShowingStartDot, "a traced letter needs no dot")

        view.clearInk()
        #expect(view.phase == .yourTurn("a"))
        #expect(view.isShowingStartDot, "wiped, the letter is to be begun again")
    }
}
