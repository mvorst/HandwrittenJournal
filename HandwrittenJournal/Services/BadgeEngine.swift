import Foundation

/// DESIGN_DOCUMENT.md §8.5. None of these reference levels — there are none.
struct BadgeDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let detail: String
}

enum BadgeEngine {

    static let all: [BadgeDefinition] = [
        .init(id: "first_entry", name: "First Entry", systemImage: "pencil.line",
              detail: "You wrote your first entry."),
        .init(id: "sharp_shooter", name: "Sharp Shooter", systemImage: "star.fill",
              detail: "A tracing at 90% or better."),
        .init(id: "streak_5", name: "5-Day Streak", systemImage: "flame.fill",
              detail: "You wrote five days in a row."),
        .init(id: "ten_entries", name: "Ten Entries", systemImage: "calendar",
              detail: "Ten entries in the journal."),
        .init(id: "perfect_week", name: "Perfect Week", systemImage: "star.circle",
              detail: "Seven days in a row."),
        .init(id: "thousand_words", name: "1,000 Words", systemImage: "checkmark.seal",
              detail: "A thousand words in your own hand."),
        .init(id: "every_font", name: "Every Font", systemImage: "textformat",
              detail: "You tried every handwriting style."),
        .init(id: "neat_writer", name: "Neat Writer", systemImage: "hand.thumbsup",
              detail: "Five entries in a row at 85% or better."),
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
