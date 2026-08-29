import SwiftUI
import SwiftData

/// Drives the one-screen write flow (v2.5, DESIGN_DOCUMENT.md §4.4).
///
/// The page is the whole thing: the mic lives in the footer, dictation lands on the page
/// live as spoken text, fixing a misheard word happens in place, and writing commits the
/// words line by line. There are no separate capture, review or confirm screens — the
/// only stages left are the page, the results, and the two microphone edge cases.
///
/// **Text is spoken until it is written.** `basePageText` holds record + spoken buffer;
/// `recordLength` marks the boundary. The record is derived from the ink — the unbroken
/// run of fully-traced rows from the top of the page (`onRecordChange`) — and everything
/// downstream — journal, exports, counts — reads only the record.
@Observable
@MainActor
final class WriteSessionViewModel {

    enum Stage: Equatable {
        case explainPermission
        case writing
        case results
        case unavailable(String)
    }

    enum MicState: Equatable {
        case idle
        case listening
        /// Stopped itself at five minutes — a banner over the page, not a screen.
        case capped
    }

    /// A spoken word under the fix-a-word gesture (§11.13).
    struct EditingWord: Equatable {
        let range: ClosedRange<Int>
        let original: String
        var draft: String
    }

    var stage: Stage = .writing
    var mic: MicState = .idle
    var isEraserActive = false
    var editing: EditingWord?
    var lastResult: ScoreResult?
    var newBadges: [BadgeDefinition] = []

    let speech = SpeechRecognitionService()
    var controller = TracingController()

    /// Record + spoken buffer, paragraphs separated by newlines. The canonical page.
    private(set) var basePageText = ""
    /// Character count of the record prefix of `basePageText`.
    private(set) var recordLength = 0

    /// The record's ink, put back when the page reopens — without it the next Done would
    /// record an empty page over the child's work.
    private(set) var restoredStrokes: [TracingStroke] = []
    /// Where the page opens: the first unwritten word.
    private(set) var startWord = 0

    private(set) var session: WritingSession?
    private let profile: UserProfile
    private let context: ModelContext

    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, startingOver: Bool = false) {
        self.profile = profile
        self.context = context
        self.session = session
        if let session {
            if startingOver {
                // §4.7 "Write This Again": the words stay, the tracing is replaced. The
                // whole entry returns to spoken and the record regrows as they write.
                let everything = session.pageText
                session.setPage(record: "", buffer: everything)
                session.strokeArchive = nil
                session.thumbnailData = nil
            }
            basePageText = session.pageText
            recordLength = session.transcript.count
            startWord = session.wordsWritten
            restoredStrokes = Self.decode(session.strokeArchive)
        }
        wireController()
    }

    private func wireController() {
        controller.onRecordChange = { [weak self] newLength in self?.recordChanged(newLength) }
        controller.onSelectRow = { [weak self] _ in self?.rowSelected() }
        controller.onEditWord = { [weak self] range, word in self?.wordHeld(range, word) }
    }

    private static func decode(_ archive: Data?) -> [TracingStroke] {
        guard let archive else { return [] }
        return (try? StrokeArchive.decode(archive)) ?? []
    }

    // MARK: - Derived

    var setup: WritingSetup { session?.setup ?? profile.setup }

    /// What the canvas lays out. While listening, the live partial rides after the base —
    /// tidied here, so folding it in at the end changes nothing the child is looking at.
    var pageText: String {
        guard mic == .listening else { return basePageText }
        let live = Self.tidy(speech.transcript)
        guard !live.isEmpty else { return basePageText }
        return basePageText.isEmpty ? live : basePageText + "\n" + live
    }

    var totalWords: Int { WritingSession.wordCount(basePageText) }
    var wordsWritten: Int { max(controller.wordsWritten, session?.wordsWritten ?? 0) }
    var hasSpokenText: Bool { recordLength < basePageText.count }

    // MARK: - Permission

    func prepare() async {
        // The page needs no permission — only the mic does, and it asks when tapped.
    }

    /// The footer mic (or the big one on an empty page).
    func micTapped() {
        guard mic == .idle, editing == nil else { return }
        switch speech.currentStatusWithoutPrompting() {
        case .ready: startListening()
        case .unknown: stage = .explainPermission
        case .microphoneDenied, .speechDenied: stage = .unavailable("The microphone is switched off")
        case .unavailable(let message): stage = .unavailable(message)
        }
    }

    func requestPermission() async {
        await speech.refreshAvailability()
        switch speech.availability {
        case .ready:
            stage = .writing
            startListening()
        case .unavailable(let message): stage = .unavailable(message)
        default: stage = .unavailable("The microphone is switched off")
        }
    }

    /// Back to the page from the permission or unavailable screens.
    func backToPage() { stage = .writing }

    // MARK: - Speaking

    private func startListening() {
        do {
            try speech.start()
            mic = .listening
            Haptics.tap()
        } catch {
            stage = .unavailable("The microphone could not start")
        }
    }

    /// "I'm done talking", the five-minute cap, or a line being taken in hand.
    func dictationEnded() {
        guard mic == .listening else { return }
        speech.stop()
        mic = speech.didReachCap ? .capped : .idle
        appendDictation(Self.tidy(speech.transcript))
        attachAudio()
        Haptics.tap()
    }

    func dismissCapBanner() {
        if mic == .capped { mic = .idle }
    }

    /// Typing is the same path as speaking with the mic removed — the words land as
    /// spoken text and are no more real until they are written.
    func useTyped(_ text: String) {
        appendDictation(Self.tidy(text))
        stage = .writing
    }

    private func appendDictation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // A new telling always starts its own paragraph, so committed lines can never
        // absorb later words (§5.2).
        basePageText = basePageText.isEmpty ? trimmed : basePageText + "\n" + trimmed
        persist()
        if let session {
            session.rawTranscript += (session.rawTranscript.isEmpty ? "" : "\n") + trimmed
        }
    }

    /// Speech recognition drops capitals and doubles spaces on young voices often enough
    /// that tidying once here saves the child an edit they should not have to make.
    static func tidy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var out = trimmed
        out.replace(#/[ \t]+/#, with: " ")
        let first = out.removeFirst()
        return String(first).uppercased() + out
    }

    private func attachAudio() {
        guard let url = speech.recordingURL, speech.elapsed > 0 else { return }
        let take = 0...max(0.2, speech.elapsed)
        guard let session else { return }
        let duration = speech.elapsed
        Task { [weak self] in
            let existing = session.audioData
            let joined = await AudioSlicer.append(existing, recording: url, range: take)
            await MainActor.run {
                if let joined { session.audioData = joined }
                session.spokenDuration += duration
                AudioSlicer.discardMaster(at: url)
                self?.speech.reset()
            }
        }
    }

    // MARK: - The page

    /// The unbroken run of fully-traced rows grew or shrank — the record follows the ink.
    private func recordChanged(_ newLength: Int) {
        recordLength = min(newLength, basePageText.count)
        persist()
        // The record's ink is worth keeping every time it changes, not only at Done.
        if let session, let archive = controller.archive() { session.strokeArchive = archive }
    }

    /// A row was selected: the mic stops, the cap banner clears, and the word under edit
    /// (if any) is dropped.
    private func rowSelected() {
        if mic == .listening { dictationEnded() }
        if mic == .capped { mic = .idle }
        editing = nil
    }

    private func wordHeld(_ range: ClosedRange<Int>, _ word: String) {
        guard mic == .idle, !word.isEmpty else { return }
        editing = EditingWord(range: range, original: word, draft: word)
        Haptics.tap()
    }

    /// §11.13 — the fix lands in place. Only the spoken tier can change, so nothing the
    /// child has written ever reflows.
    func commitEdit() {
        guard let editing else { return }
        self.editing = nil
        let replacement = editing.draft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(#/\s+/#, with: " ")
        guard !replacement.isEmpty, replacement != editing.original else { return }
        let characters = Array(basePageText)
        guard editing.range.lowerBound >= recordLength,
              editing.range.upperBound < characters.count else { return }
        var out = characters
        out.replaceSubrange(editing.range.lowerBound...editing.range.upperBound,
                            with: Array(replacement))
        basePageText = String(out)
        persist()
        Haptics.tap()
    }

    func cancelEdit() { editing = nil }

    /// Splits the page at the record boundary and writes both sides to the session.
    private func persist() {
        ensureSession()
        guard let session else { return }
        let characters = Array(basePageText)
        let record = String(characters.prefix(recordLength))
        let rest = String(characters.dropFirst(recordLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        session.setPage(record: record, buffer: rest)
    }

    private func ensureSession() {
        guard session == nil, !basePageText.isEmpty else { return }
        let created = WritingSession(setup: profile.setup)
        created.author = profile
        context.insert(created)
        session = created
    }

    // MARK: - Finishing

    /// Stopping part-way is ordinary, so this is the same action whether the child wrote
    /// three words or all of them. Every row with any ink counts — they traced it — and
    /// its untouched letters score zero.
    func finishWriting() {
        if mic == .listening { dictationEnded() }
        editing = nil
        guard let result = controller.finishEntry(streak: profile.currentStreak) else {
            stage = .results
            return
        }
        persist()
        guard let session else {
            stage = .results
            return
        }
        // Never write an empty archive over ink that is already saved — a restore that
        // silently failed looks the same as a cleared page from here.
        let strokes = controller.strokeCount > 0 ? controller.archive() : session.strokeArchive
        session.record(result,
                       strokes: strokes,
                       thumbnail: controller.thumbnail() ?? session.thumbnailData,
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

    /// More to say about the same day. The new words will join this page as spoken text.
    func sayMore() {
        lastResult = nil
        newBadges = []
        reloadFromSession()
        stage = .writing
        micTapped()
    }

    private func reloadFromSession() {
        guard let session else { return }
        basePageText = session.pageText
        recordLength = session.transcript.count
        startWord = session.wordsWritten
        restoredStrokes = Self.decode(session.strokeArchive)
    }

    /// An entry with nothing in it should not clutter the journal.
    func discardIfEmpty() {
        guard let session, session.transcript.isEmpty, session.spokenBuffer.isEmpty,
              session.audioData == nil else { return }
        context.delete(session)
        self.session = nil
    }
}
