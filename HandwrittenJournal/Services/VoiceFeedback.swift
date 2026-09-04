import AVFoundation

/// Whatever turns a cue into sound. The app plays the cue's bundled recording; the tests
/// record what would have been said.
@MainActor
protocol VoiceSpeaker: AnyObject {
    /// Says the cue — now if nothing is playing, otherwise once the current clip ends,
    /// in place of anything else that was waiting (v3.8). Never over the top of, and
    /// never cutting off, a clip: only `stop` does that.
    func speak(_ cue: Voice.Cue)
    /// Says the cue after whatever is playing *and* whatever is waiting, or now if
    /// nothing is.
    func enqueue(_ cue: Voice.Cue)
    func stop()
}

/// DESIGN_DOCUMENT.md §4.12 (v3.4, v3.7) — voice feedback. The iPad *speaks*, briefly, at
/// the moments a grown-up sitting beside the child would: whose turn it is, which letter
/// to trace, that a line is finished, how the entry went. It never reads the journal
/// aloud — the words on the page are the child's to read (§17) — and it never speaks
/// while the microphone is listening, or the recogniser would hear it.
///
/// Every cue is a recording that ships with the app (v3.7): one voice, cut once with a
/// Gemini voice by `Scripts/voice/build-clips.sh` from `Scripts/voice/lines.json` into
/// `Resources/Voice/<clipID>.m4a`. Nothing is synthesised on the iPad and nothing is
/// downloaded. A cue's `text` is what it says — for the tests, the manifest check and
/// whoever reads the catalog — and `clipID` is which file says it.
///
/// A per-profile switch (`UserProfile.soundEnabled`, *Voice feedback* under FEEDBACK),
/// seeded from the welcome's answer. Configured like `Haptics`: once per profile change.
@MainActor
enum Voice {

    enum Cue: Equatable {
        /// v3.2's *Your turn — write it!* callout, said as well as shown.
        case yourTurn
        /// A line settled — its words joined the record. Rotates through a few lines
        /// so it does not become a metronome.
        case lineDone(Int)
        /// The results headline. The child's name stays on the screen: the clip is
        /// recorded once, for everyone.
        case entryFinished(finishedEverything: Bool)
        /// The practice sheet's demo just ended — and the remediation modal's (§8.1b).
        case practiceYourTurn(Character)
        /// A practice letter flipped green — or was traced out of the arrow order.
        case practiceTraced(Character, followedOrder: Bool)
        /// The remediation modal (§8.1b, v3.7): a letter traced the right way with more
        /// to come, the last one, and a wrong-order attempt being wiped.
        case helpNext
        case helpFixed
        case helpAgain
        /// *Hear it* on the welcome.
        case preview
        /// The pencil check as it appears (frame 57, v3.7).
        case pencilIntro
        /// The pencil check's verdicts (frames 57 / 58).
        case pencilFound
        case thatWasAFinger
        /// Frame 59, *You'll need an Apple Pencil*, as it appears (v3.7).
        case whyPencil
        /// The empty profile picker (v3.7).
        case nobodyHere
        /// Journal Home as it appears from the picker (v3.7).
        case home
        /// *Voice feedback* switched on in Settings (v3.7).
        case voiceOn
        /// A badge, by `BadgeDefinition.id`: just earned (Results, and the card once it is
        /// earned), or what would earn it (the card while it is not) (v3.7).
        case badgeEarned(String)
        case badgeHint(String)
        /// The empty page of a new entry (v3.7): an invitation, alternating between two,
        /// then how to begin.
        case newEntry(Int)
        case startTalking
        /// The microphone explainer (frame 40), before iPadOS asks (v3.7).
        case micPermission
        /// *How to trace a letter* (frame 60, v3.8) — the practice sheet's tutorial, one
        /// line a step: as it appears, when the demo hands over (the blue dot), then how
        /// to trace, and when the letter is traced.
        case practiceHowWatch
        case practiceHowStart
        case practiceHowTrace
        case practiceHowDone

        var text: String {
            switch self {
            case .yourTurn:
                return String(localized: "Your turn. Write it!")
            case .lineDone(let n):
                let lines = Voice.lineDoneLines
                return lines[Voice.wrapped(n, lines.count)]
            case .entryFinished(let finishedEverything):
                return finishedEverything
                    ? String(localized: "Outstanding work! You wrote everything you said.")
                    : String(localized: "Great writing!")
            case .practiceYourTurn(let char):
                return String(localized: "Your turn. Trace \(Voice.letterPhrase(char)).")
            case .practiceTraced(let char, let followedOrder):
                // A number is congratulated on its own — *Nice 3. Try another one.* — and
                // never as *Nice the 3*, which a voice turns into *nice try*.
                if followedOrder, char.isNumber {
                    return String(localized: "Nice \(String(char)). Try another one.")
                }
                return followedOrder
                    ? String(localized: "Nice \(Voice.letterName(char))! Pick another letter.")
                    : String(localized: "Good \(Voice.letterName(char)). Try the strokes in the arrow order.")
            case .helpNext:
                return String(localized: "That's how it's done! Next letter.")
            case .helpFixed:
                return String(localized: "That's the way! You fixed it.")
            case .helpAgain:
                return String(localized: "Almost! Watch the arrows again. Start where they start.")
            case .preview:
                return String(localized: "Hi! I'm your journal. I'll tell you when it's your turn to write.")
            case .pencilIntro:
                return String(localized: "Watch the arrows, then trace the big A with the Apple Pencil.")
            case .pencilFound:
                return String(localized: "That's an Apple Pencil. You're ready to write!")
            case .thatWasAFinger:
                return String(localized: "That was a finger. Try the Apple Pencil.")
            case .whyPencil:
                return String(localized: "This is a handwriting app. Your child writes with a pencil in their hand, just as they do on paper — the grip, the pressure, the hand resting on the page, every letter formed stroke by stroke. That is what the app teaches and what it grades, so it doesn't start without one.")
            case .nobodyHere:
                return String(localized: "Nobody is here yet. Make a profile for each person who writes. Everyone gets their own journal, font and size.")
            case .home:
                return String(localized: "Add a journal entry, or practice writing your letters.")
            case .voiceOn:
                return String(localized: "Voice feedback is on. I'll tell you when it's your turn to write.")
            case .badgeEarned(let id):
                guard let badge = BadgeEngine.definition(id: id) else { return "" }
                return String(localized: "You earned \(badge.name)! \(badge.detail)")
            case .badgeHint(let id):
                guard let badge = BadgeEngine.definition(id: id) else { return "" }
                return String(localized: "\(badge.name). \(badge.hint)")
            case .newEntry(let n):
                let lines = Voice.newEntryLines
                return lines[Voice.wrapped(n, lines.count)]
            case .startTalking:
                return String(localized: "Tap the microphone and start talking.")
            case .micPermission:
                return String(localized: "Can we use the microphone? It allows us to write down what you tell us so you can trace the words.")
            case .practiceHowWatch:
                return String(localized: "Here's how to practice a letter. Touch it, and watch how it's written.")
            case .practiceHowStart:
                return String(localized: "See the blue dot? That's where you start. Follow the arrows.")
            case .practiceHowTrace:
                return String(localized: "Now trace the letter with your pencil. Green ink is on the letter, red ink is off. Try it!")
            case .practiceHowDone:
                return String(localized: "That's it! Now pick any letter on the sheet and trace it.")
            }
        }

        /// The recording that says it: `Resources/Voice/<clipID>.m4a`. Letter clips carry
        /// the case in the name (`upper-A`, `lower-a`, `digit-7`) so that `A` and `a` are
        /// two files on a disk that cannot tell them apart.
        var clipID: String {
            switch self {
            case .yourTurn:                          return "your-turn"
            case .lineDone(let n):                   return "line-done-\(Voice.wrapped(n, Voice.lineDoneLines.count))"
            case .entryFinished(let all):            return all ? "finished-all" : "finished-some"
            case .practiceYourTurn(let char):        return "trace-\(Voice.clipCode(char))"
            case .practiceTraced(let char, let ok):  return (ok ? "traced-good-" : "traced-order-") + Voice.clipCode(char)
            case .helpNext:                          return "help-next"
            case .helpFixed:                         return "help-fixed"
            case .helpAgain:                         return "help-again"
            case .preview:                           return "preview"
            case .pencilIntro:                       return "pencil-intro"
            case .pencilFound:                       return "pencil-found"
            case .thatWasAFinger:                    return "finger"
            case .whyPencil:                         return "why-pencil"
            case .nobodyHere:                        return "nobody-here"
            case .home:                              return "home"
            case .voiceOn:                           return "voice-on"
            case .badgeEarned(let id):               return "badge-\(id)-earned"
            case .badgeHint(let id):                 return "badge-\(id)-hint"
            case .newEntry(let n):                   return "new-entry-\(Voice.wrapped(n, Voice.newEntryLines.count))"
            case .startTalking:                      return "start-talking"
            case .micPermission:                     return "mic-permission"
            case .practiceHowWatch:                  return "practice-how-watch"
            case .practiceHowStart:                  return "practice-how-start"
            case .practiceHowTrace:                  return "practice-how-trace"
            case .practiceHowDone:                   return "practice-how-done"
            }
        }

        /// Every cue the app can say — one clip each in the bundle.
        static var all: [Cue] {
            var cues: [Cue] = [.preview, .pencilIntro, .pencilFound, .thatWasAFinger, .yourTurn]
            cues += Voice.lineDoneLines.indices.map(Cue.lineDone)
            cues += [.entryFinished(finishedEverything: true), .entryFinished(finishedEverything: false),
                     .helpNext, .helpFixed, .helpAgain, .voiceOn, .whyPencil, .nobodyHere, .home]
            cues += Voice.newEntryLines.indices.map(Cue.newEntry) + [.startTalking, .micPermission]
            cues += [.practiceHowWatch, .practiceHowStart, .practiceHowTrace, .practiceHowDone]
            for badge in BadgeEngine.all { cues += [.badgeEarned(badge.id), .badgeHint(badge.id)] }
            for char in Voice.characters {
                cues += [.practiceYourTurn(char),
                         .practiceTraced(char, followedOrder: true),
                         .practiceTraced(char, followedOrder: false)]
            }
            return cues
        }
    }

    /// The finished-line cues, in the order they rotate.
    nonisolated static let lineDoneLines: [String] = [
        String(localized: "Nice line."),
        String(localized: "Lovely writing."),
        String(localized: "That line looks great."),
        String(localized: "Keep going."),
    ]

    /// The empty page's invitations, in the order they alternate.
    nonisolated static let newEntryLines: [String] = [
        String(localized: "Tell me about your day."),
        String(localized: "Tell me a story."),
    ]

    /// The practice sheet's characters (§4.11) — each has its three letter clips.
    nonisolated static let characters: [Character] = PracticeSheet.text.filter { !$0.isWhitespace }

    /// How a character is named, spoken and on the practice sheet: *big G*, *little g*,
    /// *the 7*.
    nonisolated static func letterName(_ char: Character) -> String {
        let c = String(char)
        if char.isNumber { return String(localized: "the \(c)") }
        return char.isUppercase ? String(localized: "big \(c)") : String(localized: "little \(c)")
    }

    /// The trace line names the letter with an article: *the big A*, *a little a*, *the 7*.
    nonisolated static func letterPhrase(_ char: Character) -> String {
        let c = String(char)
        if char.isNumber { return String(localized: "the \(c)") }
        return char.isUppercase ? String(localized: "the big \(c)") : String(localized: "a little \(c)")
    }

    /// The character's part of a clip's file name.
    nonisolated static func clipCode(_ char: Character) -> String {
        if char.isNumber { return "digit-\(char)" }
        return char.isUppercase ? "upper-\(char)" : "lower-\(char)"
    }

    nonisolated static func wrapped(_ n: Int, _ count: Int) -> Int { ((n % count) + count) % count }

    private(set) static var enabled = false
    private(set) static var isListening = false
    private static var lineDoneIndex = 0
    private static var newEntryIndex = 0
    static var speaker: VoiceSpeaker = ClipSpeaker()

    /// Once per profile change and whenever the profile's switch moves (§4.10).
    static func configure(enabled: Bool) {
        self.enabled = enabled
        if !enabled { speaker.stop() }
    }

    /// While the microphone listens nothing is said — a cue spoken into the
    /// recogniser would land on the page as the child's words.
    static func setListening(_ listening: Bool) {
        isListening = listening
        if listening { speaker.stop() }
    }

    /// Says the cue if the profile allows it and the mic is not listening. `always`
    /// is for the welcome, where there is no profile yet and the grown-up asked to
    /// hear it. A cue never talks over or cuts off the one playing (v3.8): it waits for
    /// the clip to end, and it takes the place of any other cue that was waiting — the
    /// newest is the one that matters. `stop` is the only thing that cuts a clip short.
    static func say(_ cue: Cue, always: Bool = false) {
        guard always || enabled, !isListening else { return }
        speaker.speak(cue)
    }

    /// Says the cue once whatever is playing *and* waiting has finished — a badge after
    /// the results headline, *Tap the microphone* after the invitation. The same guards
    /// as `say`.
    static func sayNext(_ cue: Cue, always: Bool = false) {
        guard always || enabled, !isListening else { return }
        speaker.enqueue(cue)
    }

    /// The next finished-line cue in rotation.
    static func sayLineDone() {
        defer { lineDoneIndex += 1 }
        say(.lineDone(lineDoneIndex))
    }

    /// A new entry's empty page: the next invitation in turn, then how to begin.
    static func sayNewEntry() {
        defer { newEntryIndex += 1 }
        say(.newEntry(newEntryIndex))
        sayNext(.startTalking)
    }

    static func stop() { speaker.stop() }

    /// How long a cue's clip runs — for a screen that times something to a line, as the
    /// tutorial times its demo to follow its first (frame 60, v3.8). Zero without a clip.
    static func duration(of cue: Cue) -> TimeInterval {
        guard let url = ClipSpeaker.url(for: cue), let player = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        return player.duration
    }
}

/// Plays a cue's bundled clip with `AVAudioPlayer`. The shared audio session becomes a
/// `.playback` one for as long as the clip lasts — ducking whatever else is on, handing
/// it back when the clip ends — and the microphone sets its own `.record` session each
/// time a take starts, so the two never fight (§4.12). A missing clip is silence: there
/// is no synthesiser to fall back on, by design.
@MainActor
final class ClipSpeaker: NSObject, VoiceSpeaker, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    /// Cues waiting for the current clip to end: `speak` replaces them, `enqueue` adds.
    private var queue: [Voice.Cue] = []
    /// For the tests: what is waiting, and whether a clip is playing.
    var pending: [Voice.Cue] { queue }
    var isPlaying: Bool { player != nil }

    /// Where a cue's recording lives in the bundle.
    nonisolated static func url(for cue: Voice.Cue, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: cue.clipID, withExtension: "m4a", subdirectory: "Voice")
    }

    func speak(_ cue: Voice.Cue) {
        // Whatever is playing finishes; whatever was waiting is superseded (v3.8).
        if player == nil { play(cue) } else { queue = [cue] }
    }

    func enqueue(_ cue: Voice.Cue) {
        if player == nil { play(cue) } else { queue.append(cue) }
    }

    private func play(_ cue: Voice.Cue) {
        guard let url = Self.url(for: cue) else { playNext(); return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            self.player = player
            player.play()
        } catch {
            player = nil
            release()
        }
    }

    func stop() {
        queue.removeAll()
        guard let player else { return }
        player.stop()
        self.player = nil
        release()
    }

    private func playNext() {
        if queue.isEmpty { release() } else { play(queue.removeFirst()) }
    }

    private func release() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.playNext()
        }
    }
}
