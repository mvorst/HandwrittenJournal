import Testing
@testable import HandwrittenJournal

/// DESIGN_DOCUMENT.md §8.5 — the eight badges, in the documented order, each carrying
/// the two lines its card shows (§4.3, v3.2).
struct BadgeEngineTests {

    @Test("Exactly the eight badges, in the documented order")
    func theEight() {
        #expect(BadgeEngine.all.map(\.id) == [
            "first_entry", "sharp_shooter", "streak_5", "ten_entries",
            "perfect_week", "thousand_words", "every_font", "neat_writer",
        ])
        #expect(Set(BadgeEngine.all.map(\.id)).count == BadgeEngine.all.count)
    }

    @Test("Every badge says what earned it and what will")
    func copy() {
        for badge in BadgeEngine.all {
            #expect(!badge.name.isEmpty)
            #expect(!badge.systemImage.isEmpty)
            #expect(badge.detail.hasSuffix("."), "\(badge.id) detail: \(badge.detail)")
            #expect(badge.hint.hasSuffix("."), "\(badge.id) hint: \(badge.hint)")
            #expect(badge.hint != badge.detail, "\(badge.id) needs a hint for the unearned card")
        }
    }

    @Test("A hint tells the child what to do; a detail tells them what they did")
    func tense() {
        let streak = BadgeEngine.definition(id: "streak_5")
        #expect(streak?.hint == "Write five days in a row.")
        #expect(streak?.detail == "You wrote five days in a row.")
        #expect(BadgeEngine.definition(id: "nope") == nil)
    }
}
