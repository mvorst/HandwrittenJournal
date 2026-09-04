import Foundation
import Testing
@testable import HandwrittenJournal

/// §4.12 (v3.7) — every cue is a recording that ships with the app. These keep the three
/// places that describe a line in step: `Voice.Cue`, the manifest the clips are cut from
/// (`Scripts/voice/lines.json`) and the clips in the bundle.
@MainActor
struct VoiceClipTests {

    @Test("Every cue has its clip in the bundle")
    func clipsAreBundled() {
        let cues = Voice.Cue.all
        #expect(Voice.characters.count == 62)
        #expect(cues.count == 26 + BadgeEngine.all.count * 2 + 62 * 3)
        // One line naming every clip still owed, rather than one failure per clip: the
        // set is cut in quota-sized runs, and this is the list a run has to finish.
        let missing = cues.filter { ClipSpeaker.url(for: $0) == nil }.map(\.clipID)
        #expect(missing.isEmpty, "\(missing.count) clips missing from Resources/Voice — run Scripts/voice/cut-batched.py: \(missing.joined(separator: " "))")
    }

    @Test("Clip ids are distinct, even on a disk that cannot tell A from a")
    func clipIDsAreDistinct() {
        let ids = Voice.Cue.all.map { $0.clipID.lowercased() }
        #expect(Set(ids).count == ids.count)
        #expect(Voice.Cue.practiceYourTurn("A").clipID == "trace-upper-A")
        #expect(Voice.Cue.practiceYourTurn("a").clipID == "trace-lower-a")
        #expect(Voice.Cue.practiceTraced("7", followedOrder: false).clipID == "traced-order-digit-7")
        #expect(Voice.Cue.lineDone(-1).clipID == "line-done-\(Voice.lineDoneLines.count - 1)")
        #expect(Voice.Cue.lineDone(Voice.lineDoneLines.count).clipID == "line-done-0")
        #expect(Voice.Cue.badgeHint("thousand_words").clipID == "badge-thousand_words-hint")
    }

    @Test("A cue waits for the clip that is playing, and the newest waiting cue wins")
    func cuesNeverTalkOverEachOther() {
        let speaker = ClipSpeaker()
        speaker.speak(.lineDone(0))
        // The test host may have no audio route; then there is nothing to wait for.
        guard speaker.isPlaying else { return }
        speaker.speak(.lineDone(1))
        #expect(speaker.isPlaying, "the first clip was not cut off")
        #expect(speaker.pending == [.lineDone(1)])
        speaker.speak(.lineDone(2))
        #expect(speaker.pending == [.lineDone(2)], "the newer cue supersedes the waiting one")
        speaker.enqueue(.startTalking)
        #expect(speaker.pending == [.lineDone(2), .startTalking], "enqueue adds behind")
        speaker.stop()
        #expect(!speaker.isPlaying && speaker.pending.isEmpty, "stop is the one interruption")
    }

    @Test("While the microphone listens the player says nothing, waiting or not")
    func nothingPlaysIntoTheMicrophone() {
        // `Voice.say` already refuses a cue while listening; this is the player itself,
        // which is what a cue *queued* before the take started reaches. Said into the
        // recogniser it would land on the page as the child's words.
        let speaker = ClipSpeaker()
        Voice.setListening(true)
        defer { Voice.setListening(false) }
        speaker.speak(.lineDone(0))
        #expect(!speaker.isPlaying)
        speaker.enqueue(.startTalking)
        #expect(!speaker.isPlaying && speaker.pending.isEmpty)
    }

    @Test("The manifest the clips were cut from says what the cues say")
    func manifestMatchesCues() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Scripts/voice/lines.json")
        // The checkout is not always beside the test bundle; then there is nothing to compare.
        guard let data = try? Data(contentsOf: url) else { return }
        struct Line: Decodable { let id: String; let text: String }
        let lines = try JSONDecoder().decode([Line].self, from: data)
        let byID = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0.text) })
        let cues = Voice.Cue.all
        #expect(lines.count == cues.count)
        for cue in cues {
            #expect(byID[cue.clipID] == cue.text, "\(cue.clipID): the manifest says \(byID[cue.clipID] ?? "nothing")")
        }
    }
}
