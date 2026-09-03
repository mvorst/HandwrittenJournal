import AVFoundation

/// Whatever turns a cue into sound. The app uses the system synthesiser; the tests
/// record what would have been said.
@MainActor
protocol VoiceSpeaker: AnyObject {
    func speak(_ text: String)
    func stop()
}

/// DESIGN_DOCUMENT.md §4.12 (v3.4) — voice feedback. The iPad *speaks*, briefly, at the
/// moments a grown-up sitting beside the child would: whose turn it is, which letter to
/// trace, that a line is finished, how the entry went. It never reads the journal aloud
/// — the words on the page are the child's to read (§17) — and it never speaks while
/// the microphone is listening, or the recogniser would hear it.
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
        /// The results headline.
        case entryFinished(name: String, finishedEverything: Bool)
        /// The practice sheet's demo just ended.
        case practiceYourTurn(Character)
        /// A practice letter flipped green — or was traced out of the arrow order.
        case practiceTraced(Character, followedOrder: Bool)
        /// *Hear it* on the welcome.
        case preview
        /// The pencil check (frame 57 / 58).
        case pencilFound
        case thatWasAFinger

        var text: String {
            switch self {
            case .yourTurn:
                return "Your turn. Write it!"
            case .lineDone(let n):
                let lines = Voice.lineDoneLines
                return lines[((n % lines.count) + lines.count) % lines.count]
            case .entryFinished(let name, let finishedEverything):
                return finishedEverything ? "You wrote everything you said!" : "Great writing, \(name)!"
            case .practiceYourTurn(let char):
                return "Your turn. Trace \(Voice.letterName(char))."
            case .practiceTraced(let char, let followedOrder):
                return followedOrder
                    ? "Nice \(Voice.letterName(char))! Pick another letter."
                    : "Good \(Voice.letterName(char)). Try the strokes in the arrow order."
            case .preview:
                return "Hi! I'm your journal. I'll tell you when it's your turn to write."
            case .pencilFound:
                return "That's an Apple Pencil. You're ready to write!"
            case .thatWasAFinger:
                return "That was a finger. Try the Apple Pencil."
            }
        }
    }

    /// The finished-line cues, in the order they rotate.
    static let lineDoneLines = [
        "Nice line.",
        "Lovely writing.",
        "That line is yours now.",
        "Keep going.",
    ]

    /// How the practice sheet names a character, spoken: *big G*, *little g*, *the 7*.
    nonisolated static func letterName(_ char: Character) -> String {
        if char.isNumber { return "the \(char)" }
        return char.isUppercase ? "big \(char)" : "little \(char)"
    }

    private(set) static var enabled = false
    private(set) static var isListening = false
    private static var lineDoneIndex = 0
    static var speaker: VoiceSpeaker = SynthesizerSpeaker()

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
        speaker.speak(cue.text)
    }

    /// The next finished-line cue in rotation.
    static func sayLineDone() {
        defer { lineDoneIndex += 1 }
        say(.lineDone(lineDoneIndex))
    }

    static func stop() { speaker.stop() }
}

/// `AVSpeechSynthesizer` with a session of its own, so speaking never has to fight the
/// microphone's `.record` category and never leaves it changed.
final class SynthesizerSpeaker: VoiceSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        synthesizer.usesApplicationAudioSession = false
    }

    func speak(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // A shade slower than the default: the listener is five.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
