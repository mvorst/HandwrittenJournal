import Foundation
import FirebaseCore
import FirebaseAnalytics

/// Google Analytics for Firebase — the anonymous usage statistics decided in
/// `DESIGN_DOCUMENT.md` §10.5 and described to grown-ups by the privacy policy.
///
/// Every event here is a count, a duration, a setting or a screen name. Never the words on
/// the page, ink, a name, a photo, a voice or a location — a parameter that could carry
/// any of those does not exist on this API, on purpose. The identifier Firebase keeps is
/// its random per-install app-instance ID; `Info.plist` turns off IDFV collection and
/// every advertising signal, and the package is `FirebaseAnalyticsCore`, so
/// no advertising identifier is ever read (COPPA internal operations; App Review 1.3).
///
/// **Nothing is sent until a grown-up has agreed to the terms.** `Info.plist` starts
/// collection off (`FIREBASE_ANALYTICS_COLLECTION_ENABLED`); `start` and `termsAccepted`
/// turn it on once `Onboarding` says the current terms were accepted on this iPad. Unit
/// tests and previews never configure Firebase at all, and a DEBUG build only sends when
/// launched with Firebase's own `-FIRDebugEnabled` argument, so simulator runs and the
/// harness stay out of the production property (they show in DebugView instead).
@MainActor
enum Telemetry {

    private static var started = false

    // MARK: - Lifecycle

    /// Once, before the first view — `HandwrittenJournalApp.init`.
    static func start(onboarding: Onboarding) {
        guard !started, !isTestOrPreview else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            assertionFailure("GoogleService-Info.plist is not in the app bundle")
            return
        }
        FirebaseApp.configure()
        started = true
        applyCollection(onboarding)
    }

    /// The welcome's *I agree* (frame 55) — collection can begin.
    static func termsAccepted(_ onboarding: Onboarding) {
        applyCollection(onboarding)
    }

    private static func applyCollection(_ onboarding: Onboarding) {
        guard started else { return }
        var enabled = onboarding.hasAcceptedCurrentTerms
        #if DEBUG
        enabled = enabled && CommandLine.arguments.contains("-FIRDebugEnabled")
        #endif
        // Persists across launches; set explicitly every launch so a change of mind in
        // either direction takes effect on the next run.
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    private static var isTestOrPreview: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Screens

    /// The app's screens, named by hand — automatic screen reporting is off because in
    /// SwiftUI it would only ever see `UIHostingController`.
    enum Screen: String {
        case welcome
        case profilePicker  = "profile_picker"
        case profileEditor  = "profile_editor"
        case journal
        case write
        case read
        case results
        case practice
        case progress
        case profileSettings = "profile_settings"
        case appSettings     = "app_settings"
        case export
    }

    static func screen(_ screen: Screen) {
        guard started else { return }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screen.rawValue,
        ])
    }

    // MARK: - Events

    /// The event list from `Go_To_Market/GO_TO_MARKET_PLAN.md` §5.6. Faces and sizes are
    /// the setting IDs (`jua`, `l`), never a name; words are counts, never text.
    enum Event {
        case welcomeFinished(pencil: Onboarding.PencilCheck, voice: Bool)
        case profileCreated(setup: WritingSetup)
        case typefaceChanged(setup: WritingSetup)
        case dictationEnded(seconds: Int, words: Int, reachedCap: Bool)
        case wordsTyped(words: Int)
        case formationHelpShown(letters: Int)
        case entryFinished(result: ScoreResult, setup: WritingSetup, minutes: Int)
        case badgeEarned(id: String)
        case practiceTraced(followedOrder: Bool)
        case exportShared(scope: String, entries: Int)

        var name: String {
            switch self {
            case .welcomeFinished:    "welcome_finished"
            case .profileCreated:     "profile_created"
            case .typefaceChanged:    "typeface_changed"
            case .dictationEnded:     "dictation_ended"
            case .wordsTyped:         "words_typed"
            case .formationHelpShown: "formation_help_shown"
            case .entryFinished:      "entry_finished"
            case .badgeEarned:        "badge_earned"
            case .practiceTraced:     "practice_traced"
            case .exportShared:       "export_shared"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .welcomeFinished(let pencil, let voice):
                ["pencil": pencil.rawValue, "voice": voice ? 1 : 0]
            case .profileCreated(let setup), .typefaceChanged(let setup):
                ["face": setup.face.id, "size": setup.size.id]
            case .dictationEnded(let seconds, let words, let reachedCap):
                ["seconds": seconds, "words": words, "reached_cap": reachedCap ? 1 : 0]
            case .wordsTyped(let words):
                ["words": words]
            case .formationHelpShown(let letters):
                ["letters": letters]
            case .entryFinished(let result, let setup, let minutes):
                ["words_written": result.wordsWritten,
                 "total_words": result.totalWords,
                 "finished": result.finishedEverything ? 1 : 0,
                 "accuracy_pct": result.accuracyPercent,
                 "stars": result.stars,
                 "points": result.totalPoints,
                 "out_of_order": result.outOfOrderLetters,
                 "minutes": minutes,
                 "face": setup.face.id,
                 "size": setup.size.id]
            case .badgeEarned(let id):
                ["badge": id]
            case .practiceTraced(let followedOrder):
                ["followed_order": followedOrder ? 1 : 0]
            case .exportShared(let scope, let entries):
                ["scope": scope, "entries": entries]
            }
        }
    }

    static func log(_ event: Event) {
        guard started else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}
