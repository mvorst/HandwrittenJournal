import AVFoundation

/// Whatever turns a cue into sound. The app plays the cue's bundled recording; the tests
/// record what would have been said.
@MainActor
protocol VoiceSpeaker: AnyObject {
    func speak(_ cue: Voice.Cue)
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

        var text: String {
            switch self {
            case .yourTurn:
                return String(localized: "Your turn. Write it!")
            case .lineDone(let n):
                let lines = Voice.lineDoneLines
                return lines[Voice.wrapped(n, lines.count)]
            case .entryFinished(let finishedEverything):
                return finishedEverything
                    ? String(localized: "You wrote everything you said!")
                    : String(localized: "Great writing!")
            case .practiceYourTurn(let char):
                return String(localized: "Your turn. Trace \(Voice.letterName(char)).")
            case .practiceTraced(let char, let followedOrder):
                return followedOrder
                    ? String(localized: "Nice \(Voice.letterName(char))! Pick another letter.")
                    : String(localized: "Good \(Voice.letterName(char)). Try the strokes in the arrow order.")
            case .helpNext:
                return String(localized: "That's the way! Next letter.")
            case .helpFixed:
                return String(localized: "That's the way! Your word is fixed.")
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
            }
        }

        /// Every cue the app can say — one clip each in the bundle.
        static var all: [Cue] {
            var cues: [Cue] = [.preview, .pencilIntro, .pencilFound, .thatWasAFinger, .yourTurn]
            cues += Voice.lineDoneLines.indices.map(Cue.lineDone)
            cues += [.entryFinished(finishedEverything: true), .entryFinished(finishedEverything: false),
                     .helpNext, .helpFixed, .helpAgain]
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
        String(localized: "That line is yours now."),
        String(localized: "Keep going."),
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

    /// The character's part of a clip's file name.
    nonisolated static func clipCode(_ char: Character) -> String {
        if char.isNumber { return "digit-\(char)" }
        return char.isUppercase ? "upper-\(char)" : "lower-\(char)"
    }

    nonisolated static func wrapped(_ n: Int, _ count: Int) -> Int { ((n % count) + count) % count }

    private(set) static var enabled = false
    private(set) static var isListening = false
    private static var lineDoneIndex = 0
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
    /// hear it.
    static func say(_ cue: Cue, always: Bool = false) {
        guard always || enabled, !isListening else { return }
        speaker.speak(cue)
    }

    /// The next finished-line cue in rotation.
    static func sayLineDone() {
        defer { lineDoneIndex += 1 }
        say(.lineDone(lineDoneIndex))
    }

    static func stop() { speaker.stop() }
}

/// Plays a cue's bundled clip with `AVAudioPlayer`. The shared audio session becomes a
/// `.playback` one for as long as the clip lasts — ducking whatever else is on, handing
/// it back when the clip ends — and the microphone sets its own `.record` session each
/// time a take starts, so the two never fight (§4.12). A missing clip is silence: there
/// is no synthesiser to fall back on, by design.
@MainActor
final class ClipSpeaker: NSObject, VoiceSpeaker, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    /// Where a cue's recording lives in the bundle.
    nonisolated static func url(for cue: Voice.Cue, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: cue.clipID, withExtension: "m4a", subdirectory: "Voice")
    }

    func speak(_ cue: Voice.Cue) {
        stop()
        guard let url = Self.url(for: cue) else { return }
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
        guard let player else { return }
        player.stop()
        self.player = nil
        release()
    }

    private func release() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.release()
        }
    }
}
