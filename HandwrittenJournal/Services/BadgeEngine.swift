import Foundation

/// DESIGN_DOCUMENT.md §8.5. None of these reference levels — there are none.
struct BadgeDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    /// What the child did — Results, and the badge card once it is earned (§4.3).
    let detail: String
    /// What to do — the badge card while it is not earned yet.
    let hint: String
}

enum BadgeEngine {

    static let all: [BadgeDefinition] = [
        .init(id: "first_entry", name: String(localized: "First Entry"), systemImage: "pencil.line",
              detail: String(localized: "You wrote your first entry."),
              hint: String(localized: "Write your first entry.")),
        .init(id: "sharp_shooter", name: String(localized: "Sharp Shooter"), systemImage: "star.fill",
              detail: String(localized: "A tracing at 90% or better."),
              hint: String(localized: "Trace an entry at 90% or better.")),
        .init(id: "streak_5", name: String(localized: "5-Day Streak"), systemImage: "flame.fill",
              detail: String(localized: "You wrote five days in a row."),
              hint: String(localized: "Write five days in a row.")),
        .init(id: "ten_entries", name: String(localized: "Ten Entries"), systemImage: "calendar",
              detail: String(localized: "Ten entries in the journal."),
              hint: String(localized: "Write ten entries.")),
        .init(id: "perfect_week", name: String(localized: "Perfect Week"), systemImage: "star.circle",
              detail: String(localized: "Seven days in a row."),
              hint: String(localized: "Write seven days in a row.")),
        .init(id: "thousand_words", name: String(localized: "1,000 Words"), systemImage: "checkmark.seal",
              detail: String(localized: "A thousand words in your own hand."),
              hint: String(localized: "Write a thousand words in your own hand.")),
        .init(id: "every_font", name: String(localized: "Every Font"), systemImage: "textformat",
              detail: String(localized: "You tried every handwriting style."),
              hint: String(localized: "Try every handwriting style — pick a new one in Settings.")),
        .init(id: "neat_writer", name: String(localized: "Neat Writer"), systemImage: "hand.thumbsup",
              detail: String(localized: "Five entries in a row at 85% or better."),
              hint: String(localized: "Write five entries in a row at 85% or better.")),
    ]

    static func definition(id: String) -> BadgeDefinition? { all.first { $0.id == id } }

    struct Snapshot {
        var wordsWritten: Int
        var currentStreak: Int
        var longestStreak: Int
        var sessionCount: Int
        var bestAccuracy: Double
        var facesUsed: Set<String>
        var lastFiveAccuracies: [Double]
    }

    static func newlyEarned(from snapshot: Snapshot, existing: [String]) -> [BadgeDefinition] {
        var earned: [String] = []

        if snapshot.wordsWritten >= 1 { earned.append("first_entry") }
        if snapshot.bestAccuracy >= 0.90 { earned.append("sharp_shooter") }
        if snapshot.currentStreak >= 5 { earned.append("streak_5") }
        if snapshot.sessionCount >= 10 { earned.append("ten_entries") }
        if snapshot.longestStreak >= 7 { earned.append("perfect_week") }
        if snapshot.wordsWritten >= 1000 { earned.append("thousand_words") }
        if snapshot.facesUsed.count >= JournalFace.available.count, JournalFace.available.count > 1 {
            earned.append("every_font")
        }
        if snapshot.lastFiveAccuracies.count >= 5,
           snapshot.lastFiveAccuracies.suffix(5).allSatisfy({ $0 >= 0.85 }) {
            earned.append("neat_writer")
        }

        let known = Set(existing)
        return earned.filter { !known.contains($0) }.compactMap(definition(id:))
    }
}
