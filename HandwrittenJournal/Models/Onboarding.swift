import Foundation
import Observation

/// DESIGN_DOCUMENT.md §4.0 (v3.4) — the welcome. Three things the app settles once per
/// iPad, before anyone has a profile: a grown-up has agreed to the terms of use and the
/// privacy policy, whether the iPad should talk, and whether there is an Apple Pencil.
///
/// Kept in `UserDefaults`, not the store: it belongs to the iPad and the grown-up who
/// set it up, not to any one child, and it must be there before the first profile is.
@Observable
@MainActor
final class Onboarding {

    /// The "Last updated" date at the top of the terms and the privacy policy. Bump it
    /// when either changes and the agreement step comes back on its own — nothing else
    /// of the welcome repeats (§4.0).
    static let termsVersion = "2026-09-02"
    static let termsURL = URL(string: "https://handwrittenjournal.app/terms/")!
    static let privacyURL = URL(string: "https://handwrittenjournal.app/privacy/")!

    enum PencilCheck: String {
        case unchecked
        /// An Apple Pencil traced the letter.
        case pencil
        /// *I don't have an Apple Pencil* — a finger traced it, or nothing did.
        case noPencil
    }

    private enum Key {
        static let acceptedAt = "welcome.termsAcceptedAt"
        static let acceptedVersion = "welcome.termsVersion"
        static let pencil = "welcome.pencilCheck"
        static let voice = "welcome.voiceFeedbackDefault"
        static let completedAt = "welcome.completedAt"
    }

    static let shared = Onboarding()

    private let defaults: UserDefaults
    private(set) var termsAcceptedAt: Date?
    private(set) var acceptedTermsVersion: String?
    private(set) var pencilCheck: PencilCheck
    /// The answer to *Should the iPad talk?* — what every new profile's **Voice
    /// feedback** starts as. Each profile keeps its own switch after that (§4.10).
    private(set) var voiceFeedbackDefault: Bool
    private(set) var completedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        termsAcceptedAt = defaults.object(forKey: Key.acceptedAt) as? Date
        acceptedTermsVersion = defaults.string(forKey: Key.acceptedVersion)
        pencilCheck = PencilCheck(rawValue: defaults.string(forKey: Key.pencil) ?? "") ?? .unchecked
        voiceFeedbackDefault = defaults.object(forKey: Key.voice) as? Bool ?? true
        completedAt = defaults.object(forKey: Key.completedAt) as? Date
    }

    // MARK: - What is owed

    var hasAcceptedCurrentTerms: Bool { acceptedTermsVersion == Self.termsVersion }
    var isComplete: Bool { completedAt != nil }

    /// The steps still owed, in the order they are shown: the whole welcome on a fresh
    /// iPad; only the agreement again when the terms have changed since it was given.
    var stepsDue: [WelcomeStep] {
        var due: [WelcomeStep] = []
        if !hasAcceptedCurrentTerms { due.append(.terms) }
        if !isComplete { due += [.voice, .pencil] }
        return due
    }

    var needsWelcome: Bool { !stepsDue.isEmpty }

    // MARK: - Answers

    func acceptTerms(on date: Date = .now) {
        termsAcceptedAt = date
        acceptedTermsVersion = Self.termsVersion
        defaults.set(date, forKey: Key.acceptedAt)
        defaults.set(Self.termsVersion, forKey: Key.acceptedVersion)
    }

    func chooseVoiceFeedback(_ on: Bool) {
        voiceFeedbackDefault = on
        defaults.set(on, forKey: Key.voice)
    }

    func recordPencilCheck(_ result: PencilCheck) {
        pencilCheck = result
        defaults.set(result.rawValue, forKey: Key.pencil)
    }

    /// The last step is done. Only the agreement can be owed again after this.
    func finish(on date: Date = .now) {
        completedAt = date
        defaults.set(date, forKey: Key.completedAt)
    }

    /// Back to a fresh iPad — the DEBUG harness's `-screen welcome`, and the tests.
    func reset() {
        termsAcceptedAt = nil
        acceptedTermsVersion = nil
        pencilCheck = .unchecked
        voiceFeedbackDefault = true
        completedAt = nil
        for key in [Key.acceptedAt, Key.acceptedVersion, Key.pencil, Key.voice, Key.completedAt] {
            defaults.removeObject(forKey: key)
        }
    }
}

/// The welcome's three screens, in order (frames 55–58). A grown-up holds the iPad for
/// the first two; the third is the child's, and it leads straight into *Add someone*.
enum WelcomeStep: Int, CaseIterable, Identifiable, Hashable {
    case terms
    case voice
    case pencil

    var id: Int { rawValue }
}
