import Foundation

/// DESIGN_DOCUMENT.md §8.3 (v3.1) — practice letters earn points too.
///
/// A letter that flips green on the practice sheet is worth two points when its strokes
/// followed the arrows and one when they did not. Each character earns at most once a
/// calendar day — a second green G tops up to two if the first was worth one, and
/// otherwise earns nothing — so a full sheet is worth 124 and no explicit cap is needed.
/// Practice points add to the running total only: they never extend a streak, unlock a
/// badge or appear in the journal list. The journal stays the point.
enum PracticePoints {
    /// Traced green, strokes in the arrow order.
    static let full = 2
    /// Traced green, but not the way the arrows showed (§8.1a).
    static let partial = 1

    static func worth(followedOrder: Bool) -> Int { followedOrder ? full : partial }

    /// "2026-03-04" — the ledger's day, in the calendar the child lives in.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "2026-03-04|G" — one entry per character per day.
    static func ledgerKey(day: String, character: Character) -> String { "\(day)|\(character)" }

    /// The day a ledger key belongs to, or nil for a key this build does not understand.
    static func day(of ledgerKey: String, calendar: Calendar = .current) -> Date? {
        guard let bar = ledgerKey.firstIndex(of: "|") else { return nil }
        let parts = ledgerKey[..<bar].split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// What `ledger` says one day has earned so far.
    static func points(in ledger: [String: Int], on date: Date, calendar: Calendar = .current) -> Int {
        let prefix = dayKey(date, calendar: calendar) + "|"
        return ledger.reduce(0) { $0 + ($1.key.hasPrefix(prefix) ? $1.value : 0) }
    }
}

/// What the points card on Journal Home shows (§4.3): the running total, today's gain,
/// and one bar per day for the last week — entry points by the day the entry was
/// started, plus that day's practice.
struct PointsSummary: Equatable {
    struct Day: Equatable {
        let date: Date
        let points: Int
        let isToday: Bool
    }

    let total: Int
    let today: Int
    /// Oldest first, ending today.
    let days: [Day]

    static func build(total: Int,
                      entries: [(date: Date, points: Int)],
                      practice: [String: Int],
                      now: Date = .now,
                      calendar: Calendar = .current,
                      dayCount: Int = 7) -> PointsSummary {
        let todayStart = calendar.startOfDay(for: now)
        var byDay: [Date: Int] = [:]
        for entry in entries where entry.points > 0 {
            byDay[calendar.startOfDay(for: entry.date), default: 0] += entry.points
        }
        for (key, value) in practice {
            guard let day = PracticePoints.day(of: key, calendar: calendar) else { continue }
            byDay[calendar.startOfDay(for: day), default: 0] += value
        }
        let days: [Day] = (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return Day(date: date, points: byDay[date] ?? 0, isToday: offset == 0)
        }
        return PointsSummary(total: total, today: byDay[todayStart] ?? 0, days: days)
    }
}

extension UserProfile {

    /// A practice letter flipped green (§8.3). Returns what it just earned — zero when
    /// the letter has already earned as much today — and adds that to the total.
    @discardableResult
    func awardPractice(character: Character, followedOrder: Bool,
                       on date: Date = .now, calendar: Calendar = .current) -> Int {
        let key = PracticePoints.ledgerKey(day: PracticePoints.dayKey(date, calendar: calendar),
                                          character: character)
        let earned = practiceLedger[key] ?? 0
        let gained = max(0, PracticePoints.worth(followedOrder: followedOrder) - earned)
        guard gained > 0 else { return 0 }
        practiceLedger[key] = earned + gained
        totalPoints += gained
        return gained
    }

    /// Practice points earned on one day — the "+18 today" pill on the sheet.
    func practicePoints(on date: Date = .now, calendar: Calendar = .current) -> Int {
        PracticePoints.points(in: practiceLedger, on: date, calendar: calendar)
    }

    /// The letters that have already earned today and what each earned — the practice
    /// sheet colours them (§4.11).
    func practiceLetters(on date: Date = .now, calendar: Calendar = .current) -> [Character: Int] {
        let prefix = PracticePoints.dayKey(date, calendar: calendar) + "|"
        var out: [Character: Int] = [:]
        for (key, value) in practiceLedger where key.hasPrefix(prefix) {
            let rest = key.dropFirst(prefix.count)
            if rest.count == 1, let character = rest.first { out[character] = value }
        }
        return out
    }

    /// What the points card shows (§4.3).
    func pointsSummary(now: Date = .now, calendar: Calendar = .current) -> PointsSummary {
        PointsSummary.build(total: totalPoints,
                            entries: (sessions ?? []).map { (date: $0.startedAt, points: $0.points) },
                            practice: practiceLedger,
                            now: now,
                            calendar: calendar)
    }
}
