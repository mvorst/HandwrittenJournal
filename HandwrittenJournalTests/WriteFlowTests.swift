import Testing
import UIKit
import SwiftData
@testable import HandwrittenJournal

/// v3.2 — the Write flow adopted from Penpot page `14 · Write`.
///
/// A hand set down on the page selects nothing; a finger picks a line only by its handle;
/// the first unwritten line comes up on its own when words land; doodles are kept but
/// never count; Back scores the page as it stands and never awards the same entry twice;
/// and the ABC tool adds words to the end of the page.
///
/// v3.10 — a full line waits for the pen to rest before the next comes up, so the *t*
/// that filled it can still be crossed; a pen landing just under it starts the next line.
@MainActor
struct WriteFlowTests {

    nonisolated static let page = "Today we went to the park and I saw a big dog. The dog wanted to "
        + "play with me and we threw a ball for it until it got tired."
    nonisolated static let width: CGFloat = 834

    // MARK: - Helpers

    private func makeCanvas(_ text: String = WriteFlowTests.page) -> TracingCanvasView {
        FontRegistry.registerBundledFonts()
        let canvas = TracingCanvasView()
        canvas.setup = .default
        canvas.text = text
        let height = MaskRenderer.contentHeight(text: text, setup: .default,
                                                width: Self.width - Tokens.Layout.surfaceInset * 2)
        canvas.frame = CGRect(x: 0, y: 0, width: Self.width, height: max(400, height))
        canvas.layoutIfNeeded()
        return canvas
    }

    /// Ink that covers every letter of `row`.
    private func ink(row: Int, on canvas: TracingCanvasView) -> [TracingStroke] {
        (canvas.layout.scorableByLine[row] ?? []).map { index in
            let box = canvas.layout.glyphBoxes[index]
            var stroke = TracingStroke()
            for step in 0...10 {
                let t = CGFloat(step) / 10
                stroke.append(StrokePoint(location: CGPoint(x: box.rect.minX + box.rect.width * t,
                                                            y: box.rect.midY),
                                          force: 0.6, isInside: true, letterIndex: -1))
            }
            return stroke
        }
    }

    /// A squiggle right across the letters of `row` — where a doodle would do the most
    /// damage if it counted.
    private func squiggle(over row: Int, on canvas: TracingCanvasView) -> TracingStroke {
        guard let band = canvas.layout.rect(forLine: row) else { return TracingStroke() }
        var stroke = TracingStroke()
        for step in 0...40 {
            let t = CGFloat(step) / 40
            stroke.append(StrokePoint(location: CGPoint(x: band.minX + band.width * t,
                                                        y: band.midY + sin(t * 12) * band.height * 0.3),
                                      force: 0.7, isInside: true, letterIndex: 3))
        }
        return stroke
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserProfile.self, WritingSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func makeModel(in context: ModelContext, resuming session: WritingSession? = nil)
        -> (UserProfile, WriteSessionViewModel) {
        FontRegistry.registerBundledFonts()
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()).first) ?? {
            let created = UserProfile(name: "Milo")
            context.insert(created)
            return created
        }()
        return (profile, WriteSessionViewModel(profile: profile, context: context, resuming: session))
    }

    /// The writing surface as `TracingSurface.makeUIView` builds it, wired straight through.
    private func makeSurface(for model: WriteSessionViewModel) -> ScrollingCanvas {
        let view = ScrollingCanvas()
        let controller = model.controller
        view.layoutWidth = model.restoredWidth
        if !model.restoredStrokes.isEmpty {
            view.canvas.restore(model.restoredStrokes, capturedWidth: model.restoredWidth,
                                attributed: model.restoredAttributed)
        }
        view.apply(text: model.pageText, setup: model.setup)
        controller.attach(view)
        view.canvas.onProgress = { accuracy, words, hasInk in
            MainActor.assumeIsolated {
                controller.liveAccuracy = accuracy
                controller.wordsWritten = words
                controller.hasInk = hasInk
                controller.refresh()
            }
        }
        view.canvas.onPageState = { hasAnyInk, hasDoodles in
            MainActor.assumeIsolated {
                controller.pageHasInk = hasAnyInk
                controller.hasDoodles = hasDoodles
            }
        }
        view.canvas.onRecordChange = { length in MainActor.assumeIsolated { controller.onRecordChange?(length) } }
        view.canvas.onInkChange = { MainActor.assumeIsolated { controller.onInkChange?() } }
        view.canvas.onSelectRow = { row in MainActor.assumeIsolated { controller.onSelectRow?(row) } }
        view.frame = CGRect(x: 0, y: 0, width: Self.width, height: 900)
        view.layoutIfNeeded()
        return view
    }

    // MARK: - A resting hand does nothing

    @Test("A hand on the page is a wide touch, and wide touches are ignored — the pencil never is")
    func handTouchesAreIgnored() {
        #expect(TracingCanvasView.isHand(radius: TracingCanvasView.handRadius + 1, type: .direct))
        #expect(TracingCanvasView.isHand(radius: 90, type: .direct))
        #expect(!TracingCanvasView.isHand(radius: 24, type: .direct), "a fingertip is a finger")
        #expect(!TracingCanvasView.isHand(radius: 90, type: .pencil), "a pencil is never a hand")
        #expect(!TracingCanvasView.isHand(radius: 90, type: .indirectPointer))
    }

    @Test("A finger picks a line by its handle in the margin gutter, and nowhere else")
    func handlePicksARow() {
        let canvas = makeCanvas()
        guard let band = canvas.layout.rect(forLine: 1) else { Issue.record("no band"); return }
        #expect(canvas.handleRow(at: CGPoint(x: Tokens.Layout.surfaceInset / 2, y: band.midY)) == 1)
        #expect(canvas.handleRow(at: CGPoint(x: band.midX, y: band.midY)) == nil, "the words are not a handle")
        #expect(canvas.handleRow(at: CGPoint(x: Self.width - 20, y: band.midY)) == nil)

        // Left-handed: the handles move to the gutter the hand is not resting on.
        canvas.handlesOnRight = true
        #expect(canvas.handleRow(at: CGPoint(x: 20, y: band.midY)) == nil)
        #expect(canvas.handleRow(at: CGPoint(x: Self.width - 20, y: band.midY)) == 1)

        // Far below the text there is no line to pick.
        let far = (canvas.layout.baselines.last ?? 0) + canvas.layout.lineSpacing * 3
        #expect(canvas.handleRow(at: CGPoint(x: Self.width - 20, y: far)) == nil)
    }

    @Test("The space after the last word is where the ABC tool adds more")
    func afterTextIsRecognised() {
        let canvas = makeCanvas()
        guard let last = canvas.layout.glyphBoxes.last, let first = canvas.layout.glyphBoxes.first else {
            Issue.record("no glyphs"); return
        }
        #expect(canvas.pointIsAfterText(CGPoint(x: last.rect.maxX + 30, y: last.rect.midY)))
        #expect(canvas.pointIsAfterText(CGPoint(x: 100, y: last.rect.maxY + 60)))
        #expect(!canvas.pointIsAfterText(first.center), "the first word is a word, not the end")
    }

    // MARK: - The first line comes up on its own

    @Test("The first unwritten row comes up when asked — once the layout exists, and never mid-take")
    func firstRowComesUpWhenAsked() {
        FontRegistry.registerBundledFonts()
        let canvas = TracingCanvasView()
        canvas.setup = .default
        canvas.selectFirstUnwrittenRow()
        #expect(canvas.selectedRow == nil, "nothing to select yet")

        canvas.text = Self.page
        canvas.frame = CGRect(x: 0, y: 0, width: Self.width, height: 900)
        canvas.layoutIfNeeded()
        #expect(canvas.selectedRow == 0, "the request waited for the layout")

        // With the first row already written, the first *unwritten* row is the one.
        let resumed = makeCanvas()
        resumed.restore(ink(row: 0, on: resumed))
        resumed.layoutIfNeeded()
        #expect(resumed.rowFullyInked(0))
        #expect(resumed.selectedRow == nil, "a restore on its own selects nothing")
        resumed.selectFirstUnwrittenRow()
        #expect(resumed.selectedRow == 1)

        // While the child is still talking nothing is selected; the take ending is the cue.
        let talking = makeCanvas()
        talking.isDictating = true
        talking.selectFirstUnwrittenRow()
        #expect(talking.selectedRow == nil)
        talking.isDictating = false
        #expect(talking.selectedRow == 0)
    }

    // MARK: - The next line waits for the pen to rest (v3.10)

    @Test("A full row stays in hand until the pen has rested; then the next untraced row comes up")
    func fullRowWaitsForThePenToRest() async throws {
        let canvas = makeCanvas()
        canvas.advancePause = 0.05
        canvas.selectRow(0)
        canvas.addInk(ink(row: 0, on: canvas))
        #expect(canvas.rowFullyInked(0))
        #expect(canvas.selectedRow == 0, "the row that just filled is still in hand — its t may need crossing")
        #expect(canvas.isWaitingToAdvance)

        try await Task.sleep(for: .milliseconds(300))
        #expect(canvas.selectedRow == 1, "the pen rested, so the next row came up")
        #expect(!canvas.isWaitingToAdvance)
    }

    @Test("Ink landing on the full row starts the wait again; a row undone below full stops waiting")
    func inkOnTheFullRowRestartsTheWait() async throws {
        let canvas = makeCanvas()
        canvas.advancePause = 0.2
        canvas.selectRow(0)
        let strokes = ink(row: 0, on: canvas)
        canvas.addInk(strokes)
        #expect(canvas.isWaitingToAdvance)

        // The crossbar, 120 ms in: still in hand, and the clock starts over.
        try await Task.sleep(for: .milliseconds(120))
        canvas.addInk([strokes[strokes.count - 1]])
        #expect(canvas.selectedRow == 0 && canvas.isWaitingToAdvance)
        try await Task.sleep(for: .milliseconds(120))
        #expect(canvas.selectedRow == 0, "240 ms after the first pen-up, but only 120 after the last")
        try await Task.sleep(for: .milliseconds(250))
        #expect(canvas.selectedRow == 1)

        // A row undone below full has nothing to wait for.
        let undone = makeCanvas()
        undone.advancePause = 0.05
        undone.selectRow(0)
        undone.addInk(ink(row: 0, on: undone))
        #expect(undone.isWaitingToAdvance)
        undone.undo()
        #expect(!undone.rowFullyInked(0))
        #expect(!undone.isWaitingToAdvance, "a row with a letter missing is not finished")
        try await Task.sleep(for: .milliseconds(150))
        #expect(undone.selectedRow == 0)

        // A tap on another row ends the wait — the child chose.
        let tapped = makeCanvas()
        tapped.advancePause = 0.05
        tapped.selectRow(0)
        tapped.addInk(ink(row: 0, on: tapped))
        tapped.selectRow(3)
        #expect(!tapped.isWaitingToAdvance)
        try await Task.sleep(for: .milliseconds(150))
        #expect(tapped.selectedRow == 3)
    }

    @Test("With no pause the next row comes up at pen-up — the programmatic path")
    func zeroPauseAdvancesAtOnce() {
        let canvas = makeCanvas()
        canvas.advancePause = 0
        canvas.selectRow(0)
        canvas.addInk(ink(row: 0, on: canvas))
        #expect(canvas.selectedRow == 1)
        #expect(!canvas.isWaitingToAdvance)
    }

    @Test("A pen landing just under a full row is starting the next row, not fixing a tail")
    func penUnderAFullRowStartsTheNextRow() {
        let canvas = makeCanvas()
        canvas.selectRow(0)
        guard let band = canvas.layout.rect(forLine: 0) else { Issue.record("no band"); return }
        let onTheRow = CGPoint(x: band.midX, y: band.midY)
        let crossbar = CGPoint(x: band.midX, y: band.minY - 6)       // an overshoot above the row
        let underneath = CGPoint(x: band.midX, y: band.maxY + 6)     // the top of an l on the next row
        let farBelow = CGPoint(x: band.midX, y: band.maxY + canvas.layout.lineSpacing)

        // Half-written, the row owns everything near it — a descender's tail crosses the line.
        canvas.addInk([ink(row: 0, on: canvas)[0]])
        #expect(canvas.rowForInk(at: onTheRow) == 0)
        #expect(canvas.rowForInk(at: crossbar) == 0)
        #expect(canvas.rowForInk(at: underneath) == 0)
        #expect(canvas.rowForInk(at: farBelow) == nil, "two rows down is nobody's without a move")

        // Full and waiting, the strip under it belongs to the next row.
        canvas.addInk(ink(row: 0, on: canvas))
        #expect(canvas.rowFullyInked(0) && canvas.selectedRow == 0)
        #expect(canvas.rowForInk(at: onTheRow) == 0, "the row itself is still in hand")
        #expect(canvas.rowForInk(at: crossbar) == 0, "so the t can be crossed")
        #expect(canvas.rowForInk(at: underneath) == 1, "the next line has started")
        #expect(canvas.rowForInk(at: farBelow) == nil)
    }

    // MARK: - Doodles

    @Test("A doodle across the words scores nothing, selects nothing, and travels with the archive")
    func doodlesAreKeptButNeverCount() throws {
        let canvas = makeCanvas()
        canvas.addDoodle([squiggle(over: 2, on: canvas)], crayon: 1)

        #expect(canvas.doodles.count == 1)
        #expect(canvas.strokes.isEmpty, "a doodle is not handwriting")
        #expect(canvas.tally.startedCount == 0, "no letter has ink")
        #expect(canvas.recordEnd == 0)
        #expect(canvas.selectedRow == nil)
        #expect(!canvas.rowHasAnyInk(2))
        #expect(canvas.doodles[0].points.allSatisfy { $0.letterIndex == -1 && !$0.isInside })

        // The archive carries it as a doodle, in its crayon.
        let decoded = try StrokeArchive.decodeArchive(canvas.archive())
        #expect(decoded.strokes.count == 1)
        #expect(decoded.strokes[0].isDoodle)
        #expect(decoded.strokes[0].crayon == 1)

        // Put back on a fresh page it is a doodle again, and the record is still empty.
        let reopened = makeCanvas()
        reopened.restore(decoded.strokes, capturedWidth: Self.width, attributed: decoded.attributed)
        reopened.layoutIfNeeded()
        #expect(reopened.provenance == .restored)
        #expect(reopened.doodles.count == 1)
        #expect(reopened.strokes.isEmpty)
        #expect(reopened.recordEnd == 0)
        #expect(reopened.thumbnail() != nil, "the thumbnail shows the doodle — it is part of the page")
    }

    @Test("Undo and clear reach the doodles only while the crayon is in hand, and the ink only when it is not")
    func toolsFollowTheLayer() {
        let canvas = makeCanvas()
        canvas.selectRow(0)
        canvas.addInk(ink(row: 0, on: canvas))
        let inkCount = canvas.strokes.count
        canvas.addDoodle([squiggle(over: 3, on: canvas), squiggle(over: 4, on: canvas)], crayon: 2)
        #expect(canvas.doodles.count == 2)

        canvas.isDoodleActive = true
        canvas.undo()
        #expect(canvas.doodles.count == 1 && canvas.strokes.count == inkCount)
        canvas.clearSelected()
        #expect(canvas.doodles.isEmpty && canvas.strokes.count == inkCount)

        canvas.isDoodleActive = false
        canvas.selectRow(0)
        canvas.undo()
        #expect(canvas.strokes.count == inkCount - 1, "with the crayon down, undo is the ink's again")
    }

    @Test("A doodle survives leaving the page and coming back, and a wiped page cannot overwrite it")
    func doodleSurvivesLeavingAndReturning() throws {
        let context = try makeContext()
        let (profile, model) = makeModel(in: context)
        model.useTyped(Self.page)
        let view = makeSurface(for: model)
        view.canvas.addDoodle([squiggle(over: 3, on: view.canvas)], crayon: 2)
        guard let session = model.session else { Issue.record("no session"); return }
        #expect(try StrokeArchive.decode(session.strokeArchive!).doodles.count == 1, "saved as it landed")

        // Back: score, set the ink aside, leave.
        model.saveScore()
        model.setAsideInk()
        #expect(try StrokeArchive.decode(session.strokeArchive!).doodles.count == 1, "kept through Back")

        // A later sitting: the entry stages it, and the surface puts it back.
        let second = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        #expect(second.restoredStrokes.doodles.count == 1)
        let reopened = makeSurface(for: second)
        #expect(reopened.canvas.doodles.count == 1)
        #expect(reopened.canvas.provenance == .restored)

        // A relayout that wipes the page — here a size change — must not let the empty
        // page overwrite the doodle in the entry.
        reopened.canvas.setup = WritingSetup(face: .default, size: JournalSize.all[0], mode: .trace)
        reopened.canvas.layoutIfNeeded()
        #expect(reopened.canvas.doodles.isEmpty)
        #expect(!reopened.canvas.accountsForArchive, "a page that lost its doodles cannot speak for the archive")
        second.setAsideInk()
        #expect(try StrokeArchive.decode(session.strokeArchive!).doodles.count == 1, "the doodle is still in the entry")
    }

    // MARK: - Back scores, once

    @Test("Back scores the page as it stands; scoring again awards the difference, never a second helping")
    func backScoresOnce() throws {
        let context = try makeContext()
        let (profile, model) = makeModel(in: context)
        model.useTyped(Self.page)
        let view = makeSurface(for: model)
        let canvas = view.canvas
        guard let session = model.session else { Issue.record("no session"); return }

        canvas.selectRow(0)
        canvas.addInk(ink(row: 0, on: canvas))
        #expect(model.controller.pageHasInk)

        // Today already counts towards the streak, so the two scorings below compare like
        // with like — the first score of a day would otherwise start the streak and the
        // second would pick up its bonus, which is the score changing, not a double award.
        profile.registerActivity()
        model.saveScore()
        #expect(model.stage == .writing, "Back leaves without the results")
        let first = session.points
        #expect(first > 0)
        #expect(session.stars > 0)
        #expect(profile.totalPoints == first)
        #expect(profile.totalStars == session.stars)
        #expect(!context.hasChanges, "the score was saved, not left to autosave")

        // Leaving and coming back to the same page scores the same page: nothing is added.
        model.saveScore()
        #expect(session.points == first)
        #expect(profile.totalPoints == first)

        // Writing another row and finishing replaces the entry's score and moves the
        // profile by the difference.
        canvas.selectRow(1)
        canvas.addInk(ink(row: 1, on: canvas))
        model.finishWriting()
        #expect(model.stage == .results)
        #expect(session.points >= first)
        #expect(profile.totalPoints == session.points)
        #expect(profile.totalStars == session.stars)
    }

    @Test("A page left again with nothing changed keeps the score it has — even one from an older formula")
    func unchangedPageKeepsItsScore() throws {
        let context = try makeContext()
        let (profile, model) = makeModel(in: context)
        model.useTyped(Self.page)
        let view = makeSurface(for: model)
        guard let session = model.session else { Issue.record("no session"); return }

        view.canvas.selectRow(0)
        view.canvas.addInk(ink(row: 0, on: view.canvas))
        profile.registerActivity()
        model.saveScore()
        let scored = session.points
        #expect(scored > 0)

        // Pretend an earlier build scored the entry: a number today's formula would never
        // produce for this page.
        session.points = 999
        profile.totalPoints = 999
        model.saveScore()
        #expect(session.points == 999, "nothing changed, so nothing is re-scored")
        #expect(profile.totalPoints == 999)

        // A later sitting on the same entry, still unchanged: the same rule, judged
        // against the entry's own archive.
        let later = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        let reopened = makeSurface(for: later)
        #expect(reopened.canvas.provenance == .restored)
        later.finishWriting()
        #expect(session.points == 999)
        #expect(profile.totalPoints == 999)
        #expect(later.lastResult?.totalPoints == 999, "the results show the score that stands")
        #expect(later.lastResult.flatMap { ScoringEngine.breakdown(for: $0) } == nil,
                "a carried-over score has no breakdown to show")

        // New ink is a new page: scored afresh, and the profile moves by the difference.
        reopened.canvas.selectRow(1)
        reopened.canvas.addInk(ink(row: 1, on: reopened.canvas))
        later.finishWriting()
        #expect(session.points != 999)
        #expect(session.points > scored)
        #expect(profile.totalPoints == session.points)
        #expect(later.lastResult.flatMap { ScoringEngine.breakdown(for: $0) } != nil)
    }

    // MARK: - Whose turn it is

    @Test("Typed words land with the first line in hand and the page saying whose turn it is")
    func typedWordsTakeTheFirstLine() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped(Self.page)
        #expect(model.showYourTurn, "nothing on the page has ink yet")

        // The request was made before any surface existed; the surface honours it.
        let view = makeSurface(for: model)
        #expect(view.canvas.selectedRow == 0)

        // The first stroke is the child taking their turn: the callout goes.
        view.canvas.addInk([ink(row: 0, on: view.canvas)[0]])
        #expect(!model.showYourTurn)

        // Saying more onto a page that has ink is not a first telling.
        model.useTyped("And then we went home.")
        #expect(!model.showYourTurn)
    }

    @Test("Reopening an entry to write on takes its first unwritten line in hand")
    func reopenedEntryTakesTheFirstUnwrittenLine() throws {
        let context = try makeContext()
        let (profile, first) = makeModel(in: context)
        first.useTyped(Self.page)
        let view = makeSurface(for: first)
        view.canvas.selectRow(0)
        view.canvas.addInk(ink(row: 0, on: view.canvas))
        guard let session = first.session else { Issue.record("no session"); return }
        first.setAsideInk()

        let second = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        let reopened = makeSurface(for: second)
        #expect(reopened.canvas.rowFullyInked(0))
        #expect(reopened.canvas.selectedRow == 1, "row 0 is written; row 1 is where to start")
        #expect(!second.showYourTurn, "the page has ink — no callout on a reopen")
    }

    // MARK: - The ABC tool

    @Test("The ABC tool adds words to the end of the page and puts itself down")
    func abcToolAddsWords() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped(Self.page)
        let before = model.totalWords

        model.toggleWordsTool()
        #expect(model.tool == .words)
        #expect(model.appending == "", "the add field is up from the start")

        model.appending = "then we went home"
        model.commitAppend()
        #expect(model.pageText.hasSuffix("\nThen we went home"), "tidied, on its own paragraph")
        #expect(model.totalWords == before + 4)
        #expect(model.tool == .pen)
        #expect(model.appending == nil)
        #expect(model.session?.spokenBuffer.hasSuffix("Then we went home") == true, "spoken until written")

        // Never mind puts the tool down without touching the page.
        model.toggleWordsTool()
        model.appending = "nothing"
        model.cancelEdit()
        #expect(model.tool == .pen && model.appending == nil)
        #expect(model.totalWords == before + 4)
    }

    @Test("The eraser rubs out whichever layer the pen was drawing")
    func eraserFollowsTheLayer() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped(Self.page)

        model.toggleEraser()
        #expect(model.tool == .eraser && model.isEraserActive)
        model.isEraserActive = false
        #expect(model.tool == .pen)

        model.toggleCrayon()
        #expect(model.tool == .crayon && model.tool.drawsDoodles)
        model.toggleEraser()
        #expect(model.tool == .crayonEraser && model.isEraserActive && model.tool.drawsDoodles)
        model.isEraserActive = false
        #expect(model.tool == .crayon, "putting the eraser down leaves the crayon in hand")
        model.toggleCrayon()
        #expect(model.tool == .pen)
    }
}
