import Testing
import Foundation
import UIKit
@testable import HandwrittenJournal

/// v3.4 — the welcome and voice feedback.
///
/// A fresh iPad owes the whole welcome; a finished one owes nothing until the terms
/// change, and then only the agreement. The pencil check is owed until an Apple Pencil
/// traces the letter — there is no way through without one (v3.6). The voice answer
/// seeds new profiles. Cues are
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
        #expect(!onboarding.hasChosenVoiceFeedback)
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
        #expect(onboarding.stepsDue == [.pencil], "the voice question is asked once")
        #expect(onboarding.needsWelcome, "the letter step is owed until a pencil traces it")
        onboarding.recordPencilCheck(.pencil)
        #expect(!onboarding.needsWelcome, "an Apple Pencil on the letter is what settles the check")
        onboarding.finish(on: agreed.addingTimeInterval(60))
        #expect(onboarding.isComplete)
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
        earlier.chooseVoiceFeedback(true)
        earlier.recordPencilCheck(.pencil)
        earlier.finish()
        // The terms were accepted under a version that is no longer current.
        defaults.set("2000-01-01", forKey: "welcome.termsVersion")

        let onboarding = Onboarding(defaults: defaults)
        #expect(onboarding.needsWelcome)
        #expect(onboarding.stepsDue == [.terms], "the pencil and the voice were settled already")
        #expect(onboarding.pencilCheck == .pencil)
        onboarding.acceptTerms()
        #expect(!onboarding.needsWelcome)
    }

    @Test("There is no way through the welcome without an Apple Pencil")
    func noPencilSettlesNothing() {
        let defaults = freshDefaults()
        let onboarding = Onboarding(defaults: defaults)
        onboarding.acceptTerms()
        onboarding.chooseVoiceFeedback(true)
        #expect(onboarding.stepsDue == [.pencil])
        // *I don't have an Apple Pencil* explains and records nothing (v3.6); even a
        // finish written without the pencil does not settle the check.
        onboarding.finish()
        #expect(onboarding.isComplete)
        #expect(onboarding.stepsDue == [.pencil], "the check is owed until a pencil traces the letter")
        #expect(Onboarding(defaults: defaults).stepsDue == [.pencil])
    }

    @Test("An iPad an earlier build let through without a pencil owes the check again")
    func letThroughByAnEarlierBuild() {
        let defaults = freshDefaults()
        let earlier = Onboarding(defaults: defaults)
        earlier.acceptTerms()
        earlier.chooseVoiceFeedback(false)
        earlier.finish()
        // What v3.4's *I don't have an Apple Pencil* wrote before it carried on.
        defaults.set("noPencil", forKey: "welcome.pencilCheck")

        let onboarding = Onboarding(defaults: defaults)
        #expect(onboarding.pencilCheck == .unchecked, "noPencil is not an answer any more")
        #expect(onboarding.stepsDue == [.pencil], "the agreement and the voice stand")
        #expect(!onboarding.voiceFeedbackDefault)
        onboarding.recordPencilCheck(.pencil)
        #expect(!onboarding.needsWelcome)
    }

    @Test("A welcome interrupted at the letter picks up at the letter")
    func interruptedAtTheLetter() {
        let defaults = freshDefaults()
        let onboarding = Onboarding(defaults: defaults)
        onboarding.acceptTerms()
        onboarding.chooseVoiceFeedback(false)
        // The grown-up put the iPad down to find the pencil, and the app was relaunched.
        let relaunched = Onboarding(defaults: defaults)
        #expect(relaunched.stepsDue == [.pencil], "the voice question is not asked twice")
        #expect(relaunched.hasChosenVoiceFeedback)
        #expect(!relaunched.voiceFeedbackDefault)
    }

    @Test("The why-a-pencil page has a screen name of its own")
    func noPencilScreen() {
        #expect(Telemetry.Screen.welcomeNoPencil.rawValue == "welcome_no_pencil")
        #expect(Telemetry.Event.welcomeFinished(voice: true).parameters["voice"] as? Int == 1)
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
        #expect(!onboarding.hasChosenVoiceFeedback)
        #expect(Onboarding(defaults: defaults).stepsDue == [.terms, .voice, .pencil])
    }

    @Test("The terms and the privacy policy live on the website")
    func urls() {
        #expect(Onboarding.termsURL.absoluteString == "https://handwrittenjournal.app/terms/")
        #expect(Onboarding.privacyURL.absoluteString == "https://handwrittenjournal.app/privacy/")
        #expect(Onboarding.pencilCompatibilityURL.absoluteString == "https://support.apple.com/en-us/HT211029")
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
