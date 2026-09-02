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
///
/// **The ink is saved as it lands.** Every stroke, undo and erase writes the archive to
/// the entry and saves the store (§6); Done adds the score, nothing more. A crash, a
/// jettison or a lost surface costs at most the stroke in hand. And the surface that
/// writes the archive must first have put the archive back: a surface that could not —
/// or that never got the chance — is not allowed to overwrite it, and the record the
/// entry already holds is never shortened on its word.
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

    /// The spoken words under the fix-a-word gesture (§11.13) — one word from a tap, a run
    /// of them from a drag.
    struct EditingWord: Equatable {
        let range: ClosedRange<Int>
        let original: String
        var draft: String

        var isRun: Bool { original.contains(" ") }
    }

    /// §8.1b — the remediation modal: the finished word with its wrong-order letters,
    /// and the lessons the child must trace correctly, one by one, to go on.
    struct FormationHelp: Hashable {
        /// One distinct wrong character and every occurrence of it in the word —
        /// tracing the character once lifts the discount on all of them.
        struct Lesson: Hashable {
            let character: Character
            let letters: [FormationHelpRequest.Letter]

            var offsets: Set<Int> { Set(letters.map(\.offset)) }
        }

        let wordText: String
        let wrongOffsets: Set<Int>
        /// The lessons in reading order — every one must be traced to close the modal.
        let lessons: [Lesson]

        /// A request's wrong letters as lessons: one per distinct character, in
        /// reading order, so the same character wrong twice is taught once.
        static func lessons(for letters: [FormationHelpRequest.Letter]) -> [Lesson] {
            var lessons: [Lesson] = []
            for letter in letters {
                if let i = lessons.firstIndex(where: { $0.character == letter.character }) {
                    lessons[i] = Lesson(character: letter.character,
                                        letters: lessons[i].letters + [letter])
                } else {
                    lessons.append(Lesson(character: letter.character, letters: [letter]))
                }
            }
            return lessons
        }
    }

    var stage: Stage = .writing
    var mic: MicState = .idle
    var isEraserActive = false
    var editing: EditingWord?
    var lastResult: ScoreResult?
    var newBadges: [BadgeDefinition] = []
    /// The remediation modal on screen, if any. Set only from the canvas's help
    /// request; cleared only by `completeFormationHelp` — there is no other way out.
    private(set) var formationHelp: FormationHelp?
    private var helpQueue: [FormationHelpRequest] = []

    let speech = SpeechRecognitionService()
    var controller = TracingController()

    /// Record + spoken buffer, paragraphs separated by newlines. The canonical page.
    private(set) var basePageText = ""
    /// Character count of the record prefix of `basePageText`.
    private(set) var recordLength = 0

    /// What the next writing surface is built from: the entry's ink, put back so the
    /// child carries on rather than starting again. **Staged from the session, never
    /// cached across a surface's life** — the surface is torn down for the results and
    /// for reading, and the one built after it must see everything the entry holds.
    private(set) var restoredStrokes: [TracingStroke] = []
    /// Whether that archive carries each point's letter (HJST v2).
    private(set) var restoredAttributed = false
    /// The canvas width the ink was drawn at — the width the page lays out at for life.
    private(set) var restoredWidth: CGFloat = 0
    /// Letters remediated in earlier sittings (§8.1b), by character position — the
    /// surface keeps their order discount lifted when the ink comes back.
    private(set) var restoredRemediated: [Int] = []
    /// Where the page opens: the first unwritten word.
    private(set) var startWord = 0
    /// Bumped when the page has to be rebuilt from nothing. The writing surface restores
    /// its archive once, when it is made, so replacing a tracing means making a new one.
    private(set) var surface = 0

    /// A span the next dictation replaces instead of appending to the page. Set by
    /// *Say it again*: the child picks words and speaks over them (§11.13).
    private(set) var replacing: ClosedRange<Int>?

    private(set) var session: WritingSession?
    private let profile: UserProfile
    private let context: ModelContext

    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, startingOver: Bool = false) {
        self.profile = profile
        self.context = context
        self.session = session
        if let session {
            if startingOver { Self.clearTracing(of: session) }
            adopt(session)
        }
        wireController()
    }

    /// Everything the page needs from the entry it is opening.
    private func adopt(_ session: WritingSession) {
        basePageText = session.pageText
        recordLength = session.transcript.count
        stageSurface()
    }

    /// Stages what the next writing surface is built from, straight from the session.
    /// Called wherever a surface may be built next: opening, leaving Edit, finishing,
    /// saying more, starting over.
    private func stageSurface() {
        guard let session else {
            restoredStrokes = []
            restoredAttributed = false
            restoredWidth = 0
            restoredRemediated = []
            startWord = 0
            return
        }
        let decoded = Self.decode(session.strokeArchive)
        restoredStrokes = decoded.strokes
        restoredAttributed = decoded.attributed
        restoredWidth = session.canvasWidth
        restoredRemediated = session.remediatedCharIndices
        startWord = session.wordsWritten
    }

    /// §4.7 "Write This Again": the words stay, the tracing is replaced. The whole entry
    /// returns to spoken and the record regrows as the child writes it.
    private static func clearTracing(of session: WritingSession) {
        let everything = session.pageText
        session.setPage(record: "", buffer: everything)
        session.strokeArchive = nil
        session.thumbnailData = nil
        // Remediations excuse ink that no longer exists (§8.1b).
        session.remediatedCharIndices = []
    }

    /// The same thing, asked for from the page the child is already looking at.
    func writeItAllAgain() {
        guard let session else { return }
        Self.clearTracing(of: session)
        editing = nil
        replacing = nil
        lastResult = nil
        newBadges = []
        formationHelp = nil
        helpQueue = []
        reloadFromSession()
        surface += 1
        stage = .writing
    }

    private func wireController() {
        controller.onRecordChange = { [weak self] newLength in self?.recordChanged(newLength) }
        controller.onInkChange = { [weak self] in self?.inkChanged() }
        controller.onSelectRow = { [weak self] _ in self?.rowSelected() }
        controller.onEditWord = { [weak self] range, word in self?.wordHeld(range, word) }
        controller.onFormationHelp = { [weak self] request in self?.formationHelpNeeded(request) }
    }

    // MARK: - Formation help (§8.1b)

    /// A word was finished with letters drawn in the wrong order. One modal at a time;
    /// a stroke that finishes two such words queues the second behind the first.
    private func formationHelpNeeded(_ request: FormationHelpRequest) {
        helpQueue.append(request)
        presentNextFormationHelp()
    }

    private func presentNextFormationHelp() {
        guard formationHelp == nil, !helpQueue.isEmpty else { return }
        let request = helpQueue.removeFirst()
        let lessons = FormationHelp.lessons(for: request.letters)
        guard !lessons.isEmpty else { return }
        formationHelp = FormationHelp(wordText: request.wordText,
                                      wrongOffsets: request.wrongOffsets,
                                      lessons: lessons)
        Haptics.tap()
    }

    /// The child traced a lesson's letter correctly. The order discount is lifted —
    /// for good, on this entry — on every wrong occurrence of that character in the
    /// word, and the score re-derives. (The canvas already sounded the success haptic
    /// at the trace itself.)
    func completeFormationLesson(_ lesson: FormationHelp.Lesson) {
        guard formationHelp != nil else { return }
        for letter in lesson.letters {
            controller.markRemediated(letter: letter.glyph)
            session?.remediatedCharIndices.append(letter.charIndex)
        }
        save()
    }

    /// Every lesson traced and the child tapped through — the modal closes and any
    /// queued word takes its place.
    func completeFormationHelp() {
        guard formationHelp != nil else { return }
        formationHelp = nil
        Haptics.success()
        presentNextFormationHelp()
    }

    private static func decode(_ archive: Data?) -> StrokeArchive.Decoded {
        guard let archive, let decoded = try? StrokeArchive.decodeArchive(archive) else {
            return StrokeArchive.Decoded(strokes: [], attributed: false)
        }
        return decoded
    }

    // MARK: - Derived

    var setup: WritingSetup { session?.setup ?? profile.setup }

    /// What the canvas lays out. While listening, the live partial rides after the base —
    /// tidied here, so folding it in at the end changes nothing the child is looking at.
    var pageText: String {
        guard mic == .listening else { return basePageText }
        let live = Self.tidy(speech.transcript)
        guard !live.isEmpty else { return basePageText }
        // Speaking over a selection lands the words where the old ones were, so the child
        // watches the fix happen in place rather than at the foot of the page.
        if let range = replacing { return substituting(range, with: live) ?? basePageText }
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
        case .unknown: leaveSurface(for: .explainPermission)
        case .microphoneDenied, .speechDenied: leaveSurface(for: .unavailable("The microphone is switched off"))
        case .unavailable(let message): leaveSurface(for: .unavailable(message))
        }
    }

    func requestPermission() async {
        await speech.refreshAvailability()
        switch speech.availability {
        case .ready:
            stage = .writing
            startListening()
        case .unavailable(let message): leaveSurface(for: .unavailable(message))
        default: leaveSurface(for: .unavailable("The microphone is switched off"))
        }
    }

    /// Any stage but the page tears the writing surface down, and the one built when
    /// the page returns must start from the entry as it stands now — not from what was
    /// staged when the page opened.
    private func leaveSurface(for next: Stage) {
        setAsideInk()
        stage = next
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
            leaveSurface(for: .unavailable("The microphone could not start"))
        }
    }

    /// "I'm done talking", the five-minute cap, or a line being taken in hand.
    func dictationEnded() {
        guard mic == .listening else { return }
        speech.stop()
        mic = speech.didReachCap ? .capped : .idle
        let heard = Self.tidy(speech.transcript)
        if let range = replacing {
            replacing = nil
            substitute(range, with: heard)
        } else {
            appendDictation(heard)
        }
        speech.reset()
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
        save()
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

    // MARK: - The page

    /// The unbroken run of fully-traced rows grew or shrank — the record follows the ink.
    private func recordChanged(_ newLength: Int) {
        // Only a surface whose ink is the entry's ink can move the record. One that has
        // not put the archive back — or could not — reports an empty page, and that is
        // the restore failing, not the child changing their mind.
        guard controller.accountsForArchive else { return }
        recordLength = min(newLength, basePageText.count)
        persist()
        save()
    }

    /// A stroke landed, or was undone, erased or cleared: the archive follows the ink
    /// at once (§6). The score waits for Done; the ink does not.
    private func inkChanged() {
        guard controller.accountsForArchive else { return }
        ensureSession()
        guard let session else { return }
        if let archive = controller.archive() { session.strokeArchive = archive }
        let canvas = controller.canvasSize
        if canvas.width > 0 {
            session.canvasWidth = canvas.width
            session.canvasHeight = canvas.height
        }
        session.thumbnailData = controller.thumbnail()
        save()
    }

    /// Writes the store now. SwiftData would get round to it — usually — but a child's
    /// page is not something to lose to a crash between two autosaves.
    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Saving the journal failed: \(error)")
        }
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
        guard replacement != editing.original else { return }
        substitute(editing.range, with: replacement)
    }

    /// *Say it again* — the mic aimed at the words the child picked. What they say next
    /// takes the place of what they picked, rather than joining the end of the page.
    func speakOverSelection() {
        guard let editing, mic == .idle else { return }
        self.editing = nil
        replacing = editing.range
        micTapped()
        // The mic may have gone to the explainer or the unavailable page instead. The
        // target survives either way, because the child comes back to the same words.
    }

    func cancelEdit() {
        editing = nil
        replacing = nil
    }

    /// Puts `text` where `range` was. Refuses anything that would move written words: the
    /// record is the child's hand, and it never reflows under their ink.
    @discardableResult
    private func substitute(_ range: ClosedRange<Int>, with text: String) -> Bool {
        let replacement = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty, let out = substituting(range, with: replacement) else { return false }
        basePageText = out
        persist()
        save()
        Haptics.tap()
        return true
    }

    /// The page as it would read with `range` replaced, or nil if the span is not one the
    /// child is allowed to change.
    private func substituting(_ range: ClosedRange<Int>, with text: String) -> String? {
        let characters = Array(basePageText)
        guard range.lowerBound >= recordLength, range.upperBound < characters.count else { return nil }
        var out = characters
        out.replaceSubrange(range, with: Array(text))
        return String(out)
    }

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
    ///
    /// The ink is already saved — every stroke saw to that — so what Done adds is the
    /// score. A surface that does not stand for the entry's ink (a restore that could
    /// not land) has nothing honest to score and records nothing.
    func finishWriting() {
        if mic == .listening { dictationEnded() }
        editing = nil
        guard controller.accountsForArchive,
              let result = controller.finishEntry(streak: profile.currentStreak) else {
            stageSurface()
            stage = .results
            return
        }
        persist()
        guard let session else {
            stage = .results
            return
        }
        let canvas = controller.canvasSize
        session.record(result,
                       strokes: controller.archive() ?? session.strokeArchive,
                       thumbnail: controller.thumbnail() ?? session.thumbnailData,
                       canvas: canvas.width > 0 ? canvas
                                                : CGSize(width: session.canvasWidth, height: session.canvasHeight))
        session.endedAt = .now
        lastResult = result
        applyProgress(result: result)
        save()
        // The surface is torn down for the results; whatever is built next starts
        // from the entry as it now stands.
        stageSurface()
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

    /// Leaving the writing surface — switching to reading, the page closing — or about
    /// to build one. Whatever the surface on screen holds is written to the entry (if
    /// it stands for the entry's ink), and the next surface is staged from the entry.
    func setAsideInk() {
        if let session, controller.isAttached, controller.accountsForArchive {
            if let archive = controller.archive() { session.strokeArchive = archive }
            if let thumbnail = controller.thumbnail() { session.thumbnailData = thumbnail }
            let canvas = controller.canvasSize
            if canvas.width > 0 {
                session.canvasWidth = canvas.width
                session.canvasHeight = canvas.height
            }
            save()
        }
        stageSurface()
    }

    private func reloadFromSession() {
        guard let session else { return }
        adopt(session)
    }

    /// The entry was deleted out from under the page.
    func forgetSession() { session = nil }

    /// An entry with nothing in it should not clutter the journal.
    func discardIfEmpty() {
        guard let session, session.transcript.isEmpty, session.spokenBuffer.isEmpty else { return }
        context.delete(session)
        self.session = nil
        save()
    }
}
