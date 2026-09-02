import Testing
import Foundation
import SwiftData
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §8.3 (v3.1) — practice letters earn points, once per letter a day.
struct PracticePointsTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("A green letter in the arrow order earns two points; out of order earns one")
    func awards() {
        let profile = UserProfile(name: "Milo")
        let day = date(2026, 3, 4)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar) == 2)
        #expect(profile.awardPractice(character: "g", followedOrder: false, on: day, calendar: calendar) == 1)
        #expect(profile.totalPoints == 3)
        #expect(profile.practicePoints(on: day, calendar: calendar) == 3)
    }

    @Test("Each letter earns once a day — a second green G is worth nothing")
    func oncePerDay() {
        let profile = UserProfile(name: "Milo")
        let day = date(2026, 3, 4)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar) == 2)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar) == 0)
        #expect(profile.awardPractice(character: "G", followedOrder: false, on: day, calendar: calendar) == 0)
        #expect(profile.totalPoints == 2)
        // Big G and little g are different letters on the sheet.
        #expect(profile.awardPractice(character: "g", followedOrder: true, on: day, calendar: calendar) == 2)
    }

    @Test("A one-point trace tops up to two when the letter is traced in order later")
    func topUp() {
        let profile = UserProfile(name: "Milo")
        let day = date(2026, 3, 4)
        #expect(profile.awardPractice(character: "G", followedOrder: false, on: day, calendar: calendar) == 1)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar) == 1)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: day, calendar: calendar) == 0)
        #expect(profile.totalPoints == 2)
    }

    @Test("A new day starts every letter over")
    func newDay() {
        let profile = UserProfile(name: "Milo")
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: date(2026, 3, 4, hour: 23), calendar: calendar) == 2)
        #expect(profile.awardPractice(character: "G", followedOrder: true, on: date(2026, 3, 5, hour: 0), calendar: calendar) == 2)
        #expect(profile.totalPoints == 4)
        #expect(profile.practicePoints(on: date(2026, 3, 4), calendar: calendar) == 2)
        #expect(profile.practicePoints(on: date(2026, 3, 5), calendar: calendar) == 2)
        #expect(profile.practicePoints(on: date(2026, 3, 6), calendar: calendar) == 0)
    }

    @Test("A full sheet is worth 124 and nothing more")
    func fullSheet() {
        let profile = UserProfile(name: "Milo")
        let day = date(2026, 3, 4)
        let letters = PracticeSheet.text.filter { !$0.isWhitespace }
        #expect(letters.count == 62)
        var first = 0, second = 0
        for letter in letters { first += profile.awardPractice(character: letter, followedOrder: true, on: day, calendar: calendar) }
        for letter in letters { second += profile.awardPractice(character: letter, followedOrder: true, on: day, calendar: calendar) }
        #expect(first == 124)
        #expect(second == 0)
        #expect(profile.totalPoints == 124)
        #expect(profile.practiceLedger.count == 62)
    }

    @Test("Practice never touches the streak or the badges")
    func noStreakOrBadges() {
        let profile = UserProfile(name: "Milo")
        profile.awardPractice(character: "G", followedOrder: true, on: date(2026, 3, 4), calendar: calendar)
        #expect(profile.currentStreak == 0)
        #expect(profile.lastWroteOn == nil)
        #expect(profile.earnedBadgeIDs.isEmpty)
    }
}

/// §4.3 — the points card: total, today, and one bar per day for the last week.
struct PointsSummaryTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("Seven days ending today; entries count on the day they were started; practice is added in")
    func buildsWeek() {
        let now = date(2026, 3, 4, hour: 16)
        let entries: [(date: Date, points: Int)] = [
            (date(2026, 3, 4, hour: 9), 224),
            (date(2026, 3, 3), 186),
            (date(2026, 2, 26), 99),     // six days ago — the first bar
            (date(2026, 2, 25), 50),     // a week ago — off the card
            (date(2026, 3, 4), 0),       // a page with no tracing yet contributes nothing
        ]
        let practice = ["2026-03-04|G": 2, "2026-03-02|a": 1, "2026-01-01|z": 2, "garbage": 7]
        let summary = PointsSummary.build(total: 1_240, entries: entries, practice: practice,
                                          now: now, calendar: calendar)
        #expect(summary.total == 1_240)
        #expect(summary.today == 226)
        #expect(summary.days.count == 7)
        #expect(summary.days.map(\.points) == [99, 0, 0, 0, 1, 186, 226])
        #expect(summary.days.map(\.isToday) == [false, false, false, false, false, false, true])
        #expect(summary.days.first?.date == calendar.startOfDay(for: date(2026, 2, 26)))
        #expect(summary.days.last?.date == calendar.startOfDay(for: now))
    }

    @Test("A brand-new profile shows zero everywhere")
    func empty() {
        let summary = PointsSummary.build(total: 0, entries: [], practice: [:],
                                          now: date(2026, 3, 4), calendar: calendar)
        #expect(summary.total == 0)
        #expect(summary.today == 0)
        #expect(summary.days.allSatisfy { $0.points == 0 })
    }

    @Test("The profile assembles the summary from its sessions and its ledger")
    @MainActor func fromProfile() throws {
        let container = try ModelContainer(for: UserProfile.self, WritingSession.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let profile = UserProfile(name: "Milo")
        context.insert(profile)
        let now = date(2026, 3, 4, hour: 16)
        let session = WritingSession(setup: .default, startedAt: date(2026, 3, 4, hour: 9), transcript: "a dog")
        session.author = profile
        session.points = 224
        context.insert(session)
        profile.totalPoints = 224
        profile.awardPractice(character: "G", followedOrder: true, on: now, calendar: calendar)
        try context.save()

        let summary = profile.pointsSummary(now: now, calendar: calendar)
        #expect(summary.total == 226)
        #expect(summary.today == 226)
        #expect(summary.days.last?.points == 226)
    }

    @Test("The practice ledger survives a save and a fetch")
    @MainActor func ledgerRoundTrip() throws {
        let container = try ModelContainer(for: UserProfile.self, WritingSession.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let profile = UserProfile(name: "Milo")
        context.insert(profile)
        profile.awardPractice(character: "G", followedOrder: true, on: date(2026, 3, 4), calendar: calendar)
        profile.awardPractice(character: "g", followedOrder: false, on: date(2026, 3, 4), calendar: calendar)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.practiceLedger == ["2026-03-04|G": 2, "2026-03-04|g": 1])
        #expect(fetched.first?.totalPoints == 3)
    }
}
