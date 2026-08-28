import SwiftUI
import SwiftData

/// Drives the write loop: speak → check → write → done.
///
/// There is no splitter, no review list and no sentence queue. The child speaks, the
/// transcript is shown once for correction, and then it becomes one continuous page they
/// work down at their own pace.
///
/// Saying more does not start a new page. The words are appended to the entry already
/// open, the word total goes up, and the page scrolls to the first new word
/// (WIREFRAME_SPEC.md §11.11) — an entry is a day's page, however many times the child
/// spoke to fill it.
@Observable
@MainActor
final class WriteSessionViewModel {

    enum Stage: Equatable {
        case explainPermission
        case start
        case recording
        case cappedAtLimit
        case confirm
        case writing
        case results
        case unavailable(String)
    }

    var stage: Stage = .start
    var draftTranscript = ""
    var isEraserActive = false
    var lastResult: ScoreResult?
    var newBadges: [BadgeDefinition] = []

    let speech = SpeechRecognitionService()
    var controller = TracingController()

    /// The tracing already on this page. Restoring it is what makes resuming an entry, and
    /// "Keep writing", carry on rather than start again — without it the next Done would
    /// record an empty page over the child's work.
    private(set) var restoredStrokes: [TracingStroke] = []
    /// Where the page opens: the resume point, or the first word of a fresh dictation
    /// appended to a page already part-written.
    private(set) var startWord = 0

    private(set) var session: WritingSession?
    private let profile: UserProfile
    private let context: ModelContext
    private let isResuming: Bool

    /// `startingOver` opens the entry with a blank page: DESIGN_DOCUMENT.md §4.7's
    /// "Write This Again", which replaces the stored tracing rather than adding to it.
    /// Resuming without it keeps the ink and carries on where the child stopped.
    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, startingOver: Bool = false) {
        self.profile = profile
        self.context = context
        self.session = session
        self.isResuming = session != nil
        if let session {
            // Set up before the first render — the writing page is built from these, and
            // `prepare()` runs a beat too late to be the place for it.
            stage = .writing
            startWord = startingOver ? 0 : session.wordsWritten
            restoredStrokes = startingOver ? [] : Self.decode(session.strokeArchive)
        }
    }

    // MARK: - Derived

    var setup: WritingSetup { session?.setup ?? profile.setup }
    var transcript: String { session?.transcript ?? draftTranscript }
    var totalWords: Int { session?.totalWords ?? WritingSession.wordCount(draftTranscript) }
    var wordsWritten: Int { max(controller.wordsWritten, session?.wordsWritten ?? 0) }

    private static func decode(_ archive: Data?) -> [TracingStroke] {
        guard let archive else { return [] }
        return (try? StrokeArchive.decode(archive)) ?? []
    }

    // MARK: - Permission

    func prepare() async {
        // Resuming goes straight to the pen — the child already spoke these words.
        if isResuming { stage = .writing; return }
        switch speech.currentStatusWithoutPrompting() {
        case .ready: stage = .start
        case .unknown: stage = .explainPermission
        case .microphoneDenied, .speechDenied: stage = .unavailable("The microphone is switched off")
        case .unavailable(let message): stage = .unavailable(message)
        }
    }

    func requestPermission() async {
        await speech.refreshAvailability()
        switch speech.availability {
        case .ready: stage = .start
        case .unavailable(let message): stage = .unavailable(message)
        default: stage = .unavailable("The microphone is switched off")
        }
    }

    // MARK: - Speaking

    func startRecording() {
        do {
            try speech.start()
            stage = .recording
            Haptics.tap()
        } catch {
            stage = .unavailable("The microphone could not start")
        }
    }

    func stopRecording() {
        speech.stop()
        Haptics.tap()
        draftTranscript = Self.tidy(speech.transcript)
        stage = speech.didReachCap ? .cappedAtLimit : .confirm
    }

    func useTyped(_ text: String) {
        speech.reset()
        draftTranscript = Self.tidy(text)
        stage = .confirm
    }

    /// Speech recognition drops capitals and full stops on young voices often enough that
    /// tidying once here saves the child an edit they should not have to make.
    static func tidy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var out = trimmed
        out.replace(#/\s+/#, with: " ")
        let first = out.removeFirst()
        return String(first).uppercased() + out
    }

    // MARK: - Writing

    func beginWriting() {
        let text = draftTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let open = session, !open.transcript.isEmpty {
            append(text, to: open)
        } else {
            let created = session ?? WritingSession(setup: profile.setup, transcript: text)
            created.updateTranscript(text)
            created.author = profile
            created.rawTranscript = speech.transcript.isEmpty ? text : speech.transcript
            created.spokenDuration = speech.elapsed
            if session == nil { context.insert(created) }
            session = created
            startWord = 0
            restoredStrokes = []
            attachAudio(to: created)
        }
        stage = .writing
    }

    /// Saying more adds to the page the child is on. Their writing stays exactly where it
    /// is — greedy word wrap cannot move a word that is already laid out — and the page
    /// opens at the first word they have not seen before.
    private func append(_ addition: String, to session: WritingSession) {
        let existing = session.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        startWord = WritingSession.wordCount(existing)
        session.updateTranscript(existing + " " + addition)
        session.rawTranscript += " " + (speech.transcript.isEmpty ? addition : speech.transcript)
        session.spokenDuration += speech.elapsed
        restoredStrokes = Self.decode(session.strokeArchive)
        lastResult = nil
        newBadges = []
        attachAudio(to: session)
    }

    /// One recording per entry: a second take is joined onto the end of the first rather
    /// than replacing it or being kept as a separate clip (DESIGN_DOCUMENT.md §10.4).
    private func attachAudio(to session: WritingSession) {
        guard let url = speech.recordingURL, speech.elapsed > 0 else { return }
        let take = 0...max(0.2, speech.elapsed)
        Task { [weak self] in
            let existing = session.audioData
            let joined = await AudioSlicer.append(existing, recording: url, range: take)
            await MainActor.run {
                if let joined { session.audioData = joined }
                AudioSlicer.discardMaster(at: url)
                self?.speech.reset()
            }
        }
    }

    /// Stopping part-way is ordinary, so this is the same action whether the child wrote
    /// three words or all of them.
    func finishWriting() {
        guard let session, let result = controller.finish(streak: profile.currentStreak) else {
            stage = .results
            return
        }
        // Never write an empty page over work that is already saved. Clearing the page and
        // finishing is a real thing to do, but a restore that silently failed looks exactly
        // the same from here, and losing the child's handwriting is the worse mistake.
        guard controller.hasInk || !session.hasWriting else {
            stage = .results
            return
        }
        session.record(result,
                       strokes: controller.archive(),
                       thumbnail: controller.thumbnail(),
                       canvas: controller.canvasSize)
        session.endedAt = .now
        lastResult = result
        applyProgress(result: result)
        Haptics.success()
        stage = .results
    }

    private func applyProgress(result: ScoreResult) {
        guard result.wordsWritten > 0 else { return }
        profile.totalPoints += result.totalPoints
        profile.totalStars += result.stars
        profile.registerActivity()

        let sessions = profile.orderedSessions.filter(\.hasWriting)
        let recent = sessions.sorted { ($0.tracedAt ?? .distantPast) > ($1.tracedAt ?? .distantPast) }
        // Counted from the entries themselves, so re-tracing a line or finishing an entry
        // in a second sitting cannot inflate the total.
        profile.totalWordsWritten = sessions.reduce(0) { $0 + $1.wordsWritten }
        let snapshot = BadgeEngine.Snapshot(
            wordsWritten: profile.totalWordsWritten,
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            sessionCount: sessions.count,
            bestAccuracy: recent.map(\.accuracy).max() ?? result.accuracy,
            facesUsed: Set(sessions.map(\.fontKey)),
            lastFiveAccuracies: recent.prefix(5).map(\.accuracy).reversed()
        )
        let earned = BadgeEngine.newlyEarned(from: snapshot, existing: profile.earnedBadgeIDs)
        newBadges = earned
        profile.earnedBadgeIDs.append(contentsOf: earned.map(\.id))
    }

    /// Back to the page, with what is already written put back on it.
    func writeMore() {
        lastResult = nil
        newBadges = []
        startWord = session?.wordsWritten ?? 0
        restoredStrokes = Self.decode(session?.strokeArchive)
        stage = .writing
    }

    /// More to say about the same day — the words will join the page this entry already has.
    func sayMore() {
        lastResult = nil
        newBadges = []
        draftTranscript = ""
        speech.reset()
        stage = .start
    }

    /// A session with nothing in it should not clutter the journal.
    func discardIfEmpty() {
        guard let session, !session.hasWriting, session.transcript.isEmpty || !isResuming && session.wordsWritten == 0,
              session.tracedAt == nil else { return }
        if session.transcript.isEmpty {
            context.delete(session)
            self.session = nil
        }
    }
}
