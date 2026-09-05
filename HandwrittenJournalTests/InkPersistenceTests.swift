import Testing
import UIKit
import SwiftData
@testable import HandwrittenJournal

/// §6 — the child's ink is never lost.
///
/// These drive the real chain — canvas → controller → view model → session → store —
/// the way the page does, minus SwiftUI, and assert the two rules the persistence
/// rests on: **every stroke is saved the moment it lands**, and **a surface that has
/// not put the entry's ink back can never overwrite it or shorten the record**. The
/// first test reproduces the bug that lost whole pages: finishing an entry, reading it,
/// and tapping *Write on this page* built a surface with no ink and let it write an
/// empty archive over the child's work.
@MainActor
struct InkPersistenceTests {

    nonisolated static let page = "Today we went to the park and I saw a big dog. The dog wanted to "
        + "play with me and we threw a ball for it until it got tired."
    nonisolated static let width: CGFloat = 834

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserProfile.self, WritingSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false   // the view model must save on its own
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
        let model = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        return (profile, model)
    }

    /// The writing surface as `TracingSurface.makeUIView` builds it, wired straight
    /// through (no main-actor hop) so every report lands before the test moves on.
    private func makeSurface(for model: WriteSessionViewModel, width: CGFloat = InkPersistenceTests.width)
        -> ScrollingCanvas {
        let view = ScrollingCanvas()
        let controller = model.controller
        view.layoutWidth = model.restoredWidth
        if !model.restoredStrokes.isEmpty {
            view.canvas.restore(model.restoredStrokes, capturedWidth: model.restoredWidth,
                                attributed: model.restoredAttributed)
        }
        if !model.restoredRemediated.isEmpty {
            view.canvas.restoreRemediated(charIndices: model.restoredRemediated)
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
        view.canvas.onRecordChange = { length in MainActor.assumeIsolated { controller.onRecordChange?(length) } }
        view.canvas.onInkChange = { MainActor.assumeIsolated { controller.onInkChange?() } }
        view.canvas.onFormationHelpNeeded = { request in MainActor.assumeIsolated { controller.onFormationHelp?(request) } }
        view.frame = CGRect(x: 0, y: 0, width: width, height: 900)
        view.layoutIfNeeded()
        return view
    }

    /// Each letter's fitted formation, including separate dots and crossbars.
    private func ink(row: Int, on canvas: TracingCanvasView) -> [TracingStroke] {
        TestTraceFixtures.ink(row: row, on: canvas)
    }

    private func firstLineLength(_ canvas: TracingCanvasView) -> Int {
        canvas.layout.endCharIndex(ofLine: 0) ?? 0
    }

    // MARK: - Saved as it lands

    @Test("Every stroke writes the archive and saves the store")
    func everyStrokeIsSaved() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped(Self.page)
        let view = makeSurface(for: model)
        let canvas = view.canvas
        guard let session = model.session else { Issue.record("no session"); return }

        canvas.selectRow(0)
        let strokes = ink(row: 0, on: canvas)
        canvas.addInk([strokes[0]])
        #expect(session.strokeArchive != nil, "the first stroke is already in the entry")
        #expect(!context.hasChanges, "…and the store was saved, not left to autosave")
        #expect(abs(session.canvasWidth - Double(Self.width)) < 0.001,
                "the width the page laid out at travels with the ink")
        #expect(try StrokeArchive.decode(session.strokeArchive!).count == 1)

        canvas.addInk(Array(strokes.dropFirst()))
        #expect(try StrokeArchive.decode(session.strokeArchive!).count == strokes.count)
        #expect(session.transcript.count == firstLineLength(canvas), "the record followed the finished row")
        #expect(!context.hasChanges)

        // Undo is an ink change too. Go back to this row and erase every part of its
        // final glyph; removing a crossbar alone must not discard the inked record.
        canvas.selectRow(0)
        guard let last = canvas.layout.scorableByLine[0]?.last else {
            Issue.record("No last glyph on the first row")
            return
        }
        let lastGlyphStrokeCount = TestTraceFixtures.ink(for: last, on: canvas).count
        guard lastGlyphStrokeCount > 0 else {
            Issue.record("No strokes for the final glyph")
            return
        }
        for undone in 1...lastGlyphStrokeCount {
            canvas.undo()
            #expect(try StrokeArchive.decode(session.strokeArchive!).count == strokes.count - undone)
        }
        #expect(session.transcript.isEmpty, "a row with a letter missing is no longer written")
        #expect(!context.hasChanges)
    }

    @Test("Undoing only a crossbar makes the letter incomplete while preserving its ink and record")
    func partialLetterRemainsInTheRecord() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped("cat")
        let view = makeSurface(for: model)
        let canvas = view.canvas
        guard let session = model.session else { Issue.record("no session"); return }
        canvas.selectRow(0)
        canvas.addInk(ink(row: 0, on: canvas))
        let record = session.transcript
        let count = canvas.strokes.count
        #expect(canvas.rowFullyInked(0))
        #expect(!record.isEmpty)

        canvas.selectRow(0)
        canvas.undo()
        #expect(!canvas.rowFullyInked(0))
        #expect(canvas.rowHasAnyInk(0))
        #expect(session.transcript == record, "the t still has its stem; the child's words stay recorded")
        #expect(try StrokeArchive.decode(session.strokeArchive!).count == count - 1)
        #expect(canvas.finishEntry(streak: 0).completedWords == 0)
    }

    // MARK: - The bug

    @Test("Finishing, reading, then writing again rebuilds the page from the entry — the ink survives")
    func writingAgainAfterFinishingKeepsTheInk() throws {
        let context = try makeContext()
        let (_, model) = makeModel(in: context)
        model.useTyped(Self.page)
        var view: ScrollingCanvas? = makeSurface(for: model)
        guard let session = model.session, let canvas = view?.canvas else { Issue.record("no session"); return }

        canvas.selectRow(0)
        let strokes = ink(row: 0, on: canvas)
        canvas.addInk(strokes)
        let record = session.transcript
        #expect(record.count == firstLineLength(canvas))

        // "I'm finished": the results replace the surface, which is torn down.
        model.finishWriting()
        #expect(model.stage == .results)
        #expect(session.wordsWritten > 0)
        view = nil
        #expect(!model.controller.isAttached, "the surface really is gone")

        // "See my page" then "Write on this page": the page hands over to Edit, and
        // the surface it builds must carry the child's ink — this is where a page with
        // no ink on it used to report an empty record and write it to the entry.
        model.setAsideInk()
        #expect(model.restoredStrokes.count == strokes.count, "the surface is staged from the entry")
        #expect(abs(model.restoredWidth - Self.width) < 0.001)

        let again = makeSurface(for: model)
        #expect(again.canvas.accountsForArchive)
        #expect(again.canvas.strokes.count == strokes.count, "the ink is back on the page")
        #expect(again.canvas.recordEnd == record.count, "the record re-derives to what it was")
        #expect(session.transcript == record, "the entry's record was not touched")
        #expect(try StrokeArchive.decode(session.strokeArchive!).count == strokes.count)
    }

    @Test("Reopening an entry from the journal restores exactly the record it closed with")
    func reopenedEntryKeepsItsRecord() throws {
        let context = try makeContext()
        let (profile, first) = makeModel(in: context)
        first.useTyped(Self.page)
        let view = makeSurface(for: first)
        view.canvas.selectRow(0)
        view.canvas.addInk(ink(row: 0, on: view.canvas))
        guard let session = first.session else { Issue.record("no session"); return }
        let record = session.transcript
        let archive = session.strokeArchive
        first.setAsideInk()

        // A later sitting.
        let second = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        #expect(second.restoredAttributed, "the archive carries each point's letter")
        let reopened = makeSurface(for: second)
        #expect(reopened.canvas.recordEnd == record.count)
        #expect(session.transcript == record)
        let before = try StrokeArchive.decode(archive!).count
        let after = try StrokeArchive.decode(session.strokeArchive!).count
        #expect(before == after, "the restore re-wrote the same ink, nothing more and nothing less")
    }

    // MARK: - Never clobbered

    @Test("A surface that could not put the ink back neither overwrites the archive nor shortens the record")
    func unrestorableSurfaceCannotClobber() throws {
        let context = try makeContext()
        let (profile, first) = makeModel(in: context)
        first.useTyped(Self.page)
        let view = makeSurface(for: first)
        view.canvas.selectRow(0)
        view.canvas.addInk(ink(row: 0, on: view.canvas))
        guard let session = first.session else { Issue.record("no session"); return }
        let record = session.transcript
        let archive = session.strokeArchive
        first.setAsideInk()

        // A surface whose restore cannot land: the archive claims a width this page
        // does not have. (The page lays out at the archive's width precisely so this
        // never happens; the guard is what makes it safe if it ever does.)
        let second = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        let broken = ScrollingCanvas()
        broken.canvas.restore(second.restoredStrokes, capturedWidth: 500, attributed: true)
        broken.apply(text: second.pageText, setup: second.setup)
        second.controller.attach(broken)
        let controller = second.controller
        broken.canvas.onRecordChange = { length in MainActor.assumeIsolated { controller.onRecordChange?(length) } }
        broken.canvas.onInkChange = { MainActor.assumeIsolated { controller.onInkChange?() } }
        broken.frame = CGRect(x: 0, y: 0, width: Self.width, height: 900)
        broken.layoutIfNeeded()

        #expect(broken.canvas.provenance == .lost)
        #expect(broken.canvas.strokes.isEmpty, "the ink is honestly absent from this page")
        #expect(session.transcript == record, "…but the entry keeps its record")
        #expect(session.strokeArchive == archive, "…and its ink")

        // Whatever is drawn on that page is not allowed to become the entry's ink.
        broken.canvas.selectRow(1)
        broken.canvas.addInk(ink(row: 1, on: broken.canvas))
        #expect(session.strokeArchive == archive)
        #expect(session.transcript == record)

        // Nor does Done record a score for ink that is not the entry's.
        let stars = session.stars
        second.finishWriting()
        #expect(session.strokeArchive == archive)
        #expect(session.stars == stars)
    }

    @Test("A v1 archive, without attribution, still restores and re-derives its record")
    func legacyArchiveRestores() throws {
        let context = try makeContext()
        let (profile, first) = makeModel(in: context)
        first.useTyped(Self.page)
        let view = makeSurface(for: first)
        view.canvas.selectRow(0)
        view.canvas.addInk(ink(row: 0, on: view.canvas))
        guard let session = first.session else { Issue.record("no session"); return }
        let record = session.transcript
        first.setAsideInk()

        // Strip the attribution, as an archive written before v2 would be.
        let stripped = try StrokeArchive.decode(session.strokeArchive!).map { stroke -> TracingStroke in
            var copy = stroke
            for i in copy.points.indices { copy.points[i].letterIndex = -1 }
            return copy
        }
        let second = WriteSessionViewModel(profile: profile, context: context, resuming: session)
        let reopened = ScrollingCanvas()
        reopened.canvas.restore(stripped, capturedWidth: session.canvasWidth, attributed: false)
        reopened.apply(text: second.pageText, setup: second.setup)
        reopened.frame = CGRect(x: 0, y: 0, width: Self.width, height: 900)
        reopened.layoutIfNeeded()
        #expect(reopened.canvas.provenance == .restored)
        #expect(reopened.canvas.recordEnd == record.count, "re-attribution against the mask finds the same row")
    }

    // MARK: - One width for life

    @Test("The page lays out at the width its ink was drawn at and scales to the window")
    func pageKeepsItsWidth() throws {
        FontRegistry.registerBundledFonts()
        let view = ScrollingCanvas()
        view.layoutWidth = Self.width
        view.apply(text: Self.page, setup: .default)
        view.frame = CGRect(x: 0, y: 0, width: 600, height: 800)
        view.layoutIfNeeded()

        #expect(view.canvas.bounds.width == Self.width, "the canvas is laid out at the captured width")
        #expect(abs(view.scale - 600 / Self.width) < 0.0001)
        #expect(abs(view.contentSize.width - 600) < 0.5, "…and shown at the window's")
        #expect(abs(view.canvas.frame.width - 600) < 0.5)
        #expect(view.canvas.frame.minX == 0 && view.canvas.frame.minY == 0)

        // A wider window grows the same page rather than re-wrapping it.
        view.frame = CGRect(x: 0, y: 0, width: 1024, height: 800)
        view.layoutIfNeeded()
        #expect(view.canvas.bounds.width == Self.width)
        #expect(abs(view.contentSize.width - 1024) < 0.5)
        #expect(view.canvas.layout.lineCount == MaskRenderer.lineCount(text: Self.page, setup: .default,
                                                                        width: Self.width - Tokens.Layout.surfaceInset * 2))
    }
}
