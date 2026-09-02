import Foundation
import SwiftData
import CryptoKit

/// DESIGN_DOCUMENT.md §5.1. Authored to CloudKit's constraints: every property has a
/// default, every relationship is optional, every blob is external storage.
@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    @Attribute(.externalStorage) var avatarImageData: Data?

    // PIN — a courtesy lock, not security (§10.3)
    var pinSalt: Data?
    var pinHash: Data?

    // Writing settings — these replace v1's level ladder
    var fontKey: String = "jua"
    var sizeKey: String = "l"
    var modeRaw: Int = WritingMode.trace.rawValue

    // Progress (no levels)
    var totalStars: Int = 0
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWroteOn: Date?
    var totalWordsWritten: Int = 0
    var earnedBadgeIDs: [String] = []
    /// §8.3 (v3.1) — practice points, one entry per character per calendar day, keyed
    /// `"yyyy-MM-dd|<character>"` (`PracticePoints.ledgerKey`). Bounded by the sheet
    /// itself: at most 62 entries a day, worth at most 124.
    var practiceLedger: [String: Int] = [:]

    // Preferences
    var isLeftHanded: Bool = false
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var guideLinesEnabled: Bool = true
    var allowFingerTracing: Bool = true
    var colorBlindMode: Bool = false
    /// §13.6 (v3.3) — which side of the page the landscape rail sits on (`RailSide`);
    /// Auto keeps it away from the writing hand.
    var railSideRaw: Int = RailSide.auto.rawValue

    @Relationship(deleteRule: .cascade, inverse: \WritingSession.author)
    var sessions: [WritingSession]?

    init(name: String = "") {
        self.name = name
    }

    // MARK: - Derived

    var hasPIN: Bool { pinHash != nil && pinSalt != nil }

    var setup: WritingSetup {
        get { WritingSetup(faceID: fontKey, sizeID: sizeKey, mode: WritingMode(rawValue: modeRaw) ?? .trace) }
        set { fontKey = newValue.face.id; sizeKey = newValue.size.id; modeRaw = newValue.mode.rawValue }
    }

    var initial: String { String(name.first ?? "?").uppercased() }

    var railSide: RailSide {
        get { RailSide(rawValue: railSideRaw) ?? .auto }
        set { railSideRaw = newValue.rawValue }
    }

    /// The landscape rail's side for this profile: the setting, with Auto resolved by
    /// handedness (v3.3).
    var resolvedRailSide: RailSide.Resolved { railSide.resolved(isLeftHanded: isLeftHanded) }

    var orderedSessions: [WritingSession] {
        (sessions ?? []).sorted { $0.startedAt > $1.startedAt }
    }

    /// The most recent entry with words still waiting. This is what the resume card on
    /// Journal Home offers (§4.3).
    var unfinishedSession: WritingSession? {
        orderedSessions.first { !$0.isComplete && $0.totalWords > 0 }
    }

    // MARK: - PIN

    func setPIN(_ pin: String) {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, base)
        }
        pinSalt = salt
        pinHash = Self.hash(pin: pin, salt: salt)
    }

    func clearPIN() {
        pinSalt = nil
        pinHash = nil
    }

    func verify(pin: String) -> Bool {
        guard let salt = pinSalt, let stored = pinHash else { return true }
        return Self.hash(pin: pin, salt: salt) == stored
    }

    private static func hash(pin: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(pin.utf8))
        return Data(SHA256.hash(data: input))
    }

    // MARK: - Streak

    /// Called when a sentence is written. Consecutive calendar days extend the streak.
    func registerActivity(on date: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: date)
        if let last = lastWroteOn.map({ calendar.startOfDay(for: $0) }) {
            if last == today { return }
            let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            currentStreak = gap == 1 ? currentStreak + 1 : 1
        } else {
            currentStreak = 1
        }
        lastWroteOn = today
        longestStreak = max(longestStreak, currentStreak)
    }
}
