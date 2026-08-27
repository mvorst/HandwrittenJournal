import XCTest
@testable import TraceRight

final class BadgeEngineTests: XCTestCase {

    private func makePlayer() -> PlayerProgress {
        PlayerProgress(firstName: "Test")
    }

    func testNoBadgesForNewPlayer() {
        let player = makePlayer()
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        XCTAssertTrue(newBadges.isEmpty)
    }

    func testFirstWordsBadgeOnFirstAttempt() {
        let player = makePlayer()
        player.totalAttempts = 1
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        let firstWords = newBadges.first { $0.id == "first_words" }
        XCTAssertNotNil(firstWords)
    }

    func testSharpShooterBadge() {
        let player = makePlayer()
        player.threeStarCount = 1
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        let badge = newBadges.first { $0.id == "sharp_shooter" }
        XCTAssertNotNil(badge)
    }

    func testExistingBadgesNotReturned() {
        let player = makePlayer()
        player.threeStarCount = 1
        player.totalAttempts = 1
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: ["sharp_shooter", "first_words"])

        XCTAssertFalse(newBadges.contains { $0.id == "sharp_shooter" })
        XCTAssertFalse(newBadges.contains { $0.id == "first_words" })
    }

    func testStreakBadges() {
        let player = makePlayer()
        player.currentStreak = 3
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        XCTAssertTrue(newBadges.contains { $0.id == "on_fire" })
    }

    func testLevelBadges() {
        let player = makePlayer()
        player.currentLevel = 6
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        XCTAssertTrue(newBadges.contains { $0.id == "getting_started" })
        XCTAssertTrue(newBadges.contains { $0.id == "warming_up" })
        XCTAssertTrue(newBadges.contains { $0.id == "skilled_writer" })
        XCTAssertFalse(newBadges.contains { $0.id == "expert" })
    }

    func testVolumeBadges() {
        let player = makePlayer()
        player.totalAttempts = 100
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        XCTAssertTrue(newBadges.contains { $0.id == "first_words" })
        XCTAssertTrue(newBadges.contains { $0.id == "sentence_builder" })
        XCTAssertTrue(newBadges.contains { $0.id == "paragraph_pro" })
    }

    func testPerfectionistBadge() {
        let player = makePlayer()
        player.perfectCount = 1
        let newBadges = BadgeEngine.checkNewBadges(player: player, existingBadgeIDs: [])

        XCTAssertTrue(newBadges.contains { $0.id == "perfectionist" })
    }
}
