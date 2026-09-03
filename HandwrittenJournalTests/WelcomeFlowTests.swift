import Testing
import Foundation
import UIKit
@testable import HandwrittenJournal

/// v3.4 — the welcome and voice feedback.
///
/// A fresh iPad owes the whole welcome; a finished one owes nothing until the terms
/// change, and then only the agreement. The voice answer seeds new profiles. Cues are
/// short, never read the page, and are never spoken while the profile says no or the
/// microphone is listening.
@MainActor
@Suite(.serialized)
struct WelcomeFlowTests {

    private func freshDefaults() -> UserDefaults {
        let name = "welcome-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - What is owed

    @Test("A fresh iPad owes every step, grown-up first and the letter last")
    func freshIPad() {
        let onboarding = Onboarding(defaults: freshDefaults())
        #expect(onboarding.needsWelcome)
        #expect(onboarding.stepsDue == [.terms, .voice, .pencil])
        #expect(!onboarding.hasAcceptedCurrentTerms)
        #expect(onboarding.pencilCheck == .unchecked)
        #expect(onboarding.voiceFeedbackDefault, "the iPad talks unless a grown-up says otherwise")
    }

    @Test("Answering every step ends the welcome, and the answers survive a relaunch")
    func finishing() {
        let defaults = freshDefaults()
        let onboarding = Onboarding(defaults: defaults)
        let agreed = Date(timeIntervalSince1970: 1_800_000_000)
        onboarding.acceptTerms(on: agreed)
        #expect(onboarding.stepsDue == [.voice, .pencil], "agreeing is not the whole welcome")
        onboarding.chooseVoiceFeedback(false)
        onboarding.recordPencilCheck(.pencil)
        #expect(onboarding.needsWelcome, "the letter step is owed until it is finished")
        onboarding.finish(on: agreed.addingTimeInterval(60))
        #expect(!onboarding.needsWelcome)
        #expect(onboarding.stepsDue.isEmpty)

        let relaunched = Onboarding(defaults: defaults)
        #expect(!relaunched.needsWelcome)
        #expect(relaunched.termsAcceptedAt == agreed)
        #expect(relaunched.acceptedTermsVersion == Onboarding.termsVersion)
        #expect(relaunched.pencilCheck == .pencil)
        #expect(!relaunched.voiceFeedbackDefault)
    }

    @Test("Changed terms bring back the agreement alone")
    func newTerms() {
        let defaults = freshDefaults()
        let earlier = Onboarding(defaults: defaults)
        earlier.acceptTerms()
        earlier.recordPencilCheck(.noPencil)
        earlier.finish()
        // The terms were accepted under a version that is no longer current.
        defaults.set("2000-01-01", forKey: "welcome.termsVersion")

        let onboarding = Onboarding(defaults: defaults)
        #expect(onboarding.needsWelcome)
        #expect(onboarding.stepsDue == [.terms], "the pencil and the voice were settled already")
        #expect(onboarding.pencilCheck == .noPencil)
        onboarding.acceptTerms()
        #expect(!onboarding.needsWelcome)
    }

    @Test("Reset returns the iPad to fresh")
    func reset() {
        let defaults = freshDefaults()
        let onboarding = Onboarding(defaults: defaults)
        onboarding.acceptTerms()
        onboarding.chooseVoiceFeedback(false)
        onboarding.recordPencilCheck(.pencil)
        onboarding.finish()
        onboarding.reset()
        #expect(onboarding.stepsDue == [.terms, .voice, .pencil])
        #expect(onboarding.voiceFeedbackDefault)
        #expect(Onboarding(defaults: defaults).stepsDue == [.terms, .voice, .pencil])
    }

    @Test("The terms and the privacy policy live on the website")
    func urls() {
        #expect(Onboarding.termsURL.absoluteString == "https://handwrittenjournal.app/terms/")
        #expect(Onboarding.privacyURL.absoluteString == "https://handwrittenjournal.app/privacy/")
    }

    // MARK: - Voice feedback

    final class RecordingSpeaker: VoiceSpeaker {
        var spoken: [String] = []
        var stops = 0
        func speak(_ text: String) { spoken.append(text) }
        func stop() { stops += 1 }
    }

    private func withRecorder(_ body: (RecordingSpeaker) -> Void) {
        let recorder = RecordingSpeaker()
        let previous = Voice.speaker
        Voice.speaker = recorder
        defer {
            Voice.speaker = previous
            Voice.configure(enabled: false)
            Voice.setListening(false)
        }
        body(recorder)
    }

    @Test("Cues say whose turn it is and name the letter, and never read the page")
    func cueCopy() {
        #expect(Voice.Cue.yourTurn.text == "Your turn. Write it!")
        #expect(Voice.Cue.practiceYourTurn("G").text == "Your turn. Trace big G.")
        #expect(Voice.Cue.practiceTraced("g", followedOrder: true).text == "Nice little g! Pick another letter.")
        #expect(Voice.Cue.practiceTraced("7", followedOrder: false).text == "Good the 7. Try the strokes in the arrow order.")
        #expect(Voice.Cue.entryFinished(name: "Milo", finishedEverything: true).text == "You wrote everything you said!")
        #expect(Voice.Cue.entryFinished(name: "Milo", finishedEverything: false).text == "Great writing, Milo!")
        // §17 — the journal is never read aloud: no cue takes the page's words.
        for cue in [Voice.Cue.yourTurn, .lineDone(0), .lineDone(1), .preview, .pencilFound, .thatWasAFinger] {
            #expect(!cue.text.isEmpty && cue.text.count < 80, "\(cue) is a cue, not a reading")
        }
    }

    @Test("Finished-line cues rotate and wrap")
    func lineDoneRotation() {
        let lines = Voice.lineDoneLines
        #expect(lines.count >= 3)
        for i in 0..<(lines.count * 2) {
            #expect(Voice.Cue.lineDone(i).text == lines[i % lines.count])
        }
        #expect(Voice.Cue.lineDone(-1).text == lines[lines.count - 1])
    }

    @Test("Nothing is said while the profile says no")
    func silentWhenOff() {
        withRecorder { recorder in
            Voice.configure(enabled: false)
            Voice.say(.yourTurn)
            Voice.sayLineDone()
            #expect(recorder.spoken.isEmpty)
            Voice.configure(enabled: true)
            Voice.say(.yourTurn)
            #expect(recorder.spoken == ["Your turn. Write it!"])
        }
    }

    @Test("Nothing is said into the microphone")
    func silentWhileListening() {
        withRecorder { recorder in
            Voice.configure(enabled: true)
            Voice.setListening(true)
            #expect(recorder.stops == 1, "starting to listen silences whatever was playing")
            Voice.say(.yourTurn)
            Voice.say(.practiceYourTurn("A"))
            #expect(recorder.spoken.isEmpty)
            Voice.setListening(false)
            Voice.say(.yourTurn)
            #expect(recorder.spoken.count == 1)
        }
    }

    @Test("The welcome can speak before there is a profile, and only when asked")
    func welcomePreview() {
        withRecorder { recorder in
            Voice.configure(enabled: false)
            Voice.say(.preview)
            #expect(recorder.spoken.isEmpty)
            Voice.say(.preview, always: true)
            #expect(recorder.spoken == [Voice.Cue.preview.text])
            Voice.configure(enabled: false)
            #expect(recorder.stops >= 1, "switching the voice off stops it mid-sentence")
        }
    }

    @Test("Switching the voice on and off follows the profile")
    func profileSwitch() {
        withRecorder { recorder in
            let profile = UserProfile(name: "Ada")
            profile.soundEnabled = false
            Voice.configure(enabled: profile.soundEnabled)
            Voice.say(.pencilFound)
            profile.soundEnabled = true
            Voice.configure(enabled: profile.soundEnabled)
            Voice.say(.pencilFound)
            #expect(recorder.spoken == [Voice.Cue.pencilFound.text])
        }
    }
}
