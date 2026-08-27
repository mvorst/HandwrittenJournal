import XCTest
@testable import TraceRight

final class ScoringEngineTests: XCTestCase {

    private func makeSession(insideCount: Int, outsideCount: Int, level: Int = 1) -> TracingSession {
        var points: [TracingPoint] = []
        for _ in 0..<insideCount {
            points.append(TracingPoint(location: .zero, timestamp: 0, force: 0.5, isInsideLetter: true))
        }
        for _ in 0..<outsideCount {
            points.append(TracingPoint(location: .zero, timestamp: 0, force: 0.5, isInsideLetter: false))
        }
        let stroke = TracingStroke(points: points)
        return TracingSession(text: "test", level: level, strokes: [stroke])
    }

    private func makePlayer() -> PlayerProgress {
        PlayerProgress(firstName: "Test")
    }

    func testPerfectAccuracyGivesThreeStars() {
        let session = makeSession(insideCount: 100, outsideCount: 0)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.stars, 3)
        XCTAssertGreaterThanOrEqual(result.accuracy, 0.9)
    }

    func testHighAccuracyGivesTwoStars() {
        let session = makeSession(insideCount: 80, outsideCount: 20)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.stars, 2)
        XCTAssertEqual(result.accuracy, 0.8, accuracy: 0.001)
    }

    func testMediumAccuracyGivesOneStar() {
        let session = makeSession(insideCount: 60, outsideCount: 40)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.stars, 1)
    }

    func testLowAccuracyGivesZeroStars() {
        let session = makeSession(insideCount: 30, outsideCount: 70)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.stars, 0)
    }

    func testPointsFormula() {
        // 85% accuracy at level 4 with 3-day streak
        let session = makeSession(insideCount: 85, outsideCount: 15, level: 4)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 3, playerName: "Test", existingBadgeIDs: [], player: player)

        // base = 85, star bonus = 2*25 = 50, streak = 3*5 = 15, level = 4*10 = 40
        // total = 85 + 50 + 15 + 40 = 190
        XCTAssertEqual(result.basePoints, 85)
        XCTAssertEqual(result.starBonus, 50)
        XCTAssertEqual(result.streakBonus, 15)
        XCTAssertEqual(result.levelBonus, 40)
        XCTAssertEqual(result.totalPoints, 190)
    }

    func testZeroPointsOnEmpty() {
        let session = TracingSession(text: "test", level: 1, strokes: [])
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.stars, 0)
        XCTAssertEqual(result.accuracy, 0)
    }

    func testMessageContainsPlayerName() {
        let session = makeSession(insideCount: 95, outsideCount: 5)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Emma", existingBadgeIDs: [], player: player)

        XCTAssertTrue(result.message.contains("Emma"))
    }

    func testThreeStarMessage() {
        let session = makeSession(insideCount: 95, outsideCount: 5)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 0, playerName: "Emma", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.message, "Perfect, Emma!")
    }

    func testStreakBonusApplied() {
        let session = makeSession(insideCount: 50, outsideCount: 50, level: 1)
        let player = makePlayer()
        let result = ScoringEngine.calculate(session: session, streak: 10, playerName: "Test", existingBadgeIDs: [], player: player)

        XCTAssertEqual(result.streakBonus, 50)
    }
}
