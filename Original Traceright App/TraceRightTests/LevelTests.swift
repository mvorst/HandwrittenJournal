import XCTest
@testable import TraceRight

final class LevelTests: XCTestCase {

    func testAllLevelsExist() {
        XCTAssertEqual(LevelDefinitions.all.count, 10)
    }

    func testLevel1IsDefault() {
        let config = LevelDefinitions.config(for: 1)
        XCTAssertEqual(config.level, 1)
        XCTAssertEqual(config.fontSize, 96)
        XCTAssertEqual(config.starsRequired, 0)
    }

    func testLevel10IsSmallest() {
        let config = LevelDefinitions.config(for: 10)
        XCTAssertEqual(config.fontSize, 24)
        XCTAssertEqual(config.fontWeight, .thin)
        XCTAssertEqual(config.starsRequired, 172)
    }

    func testLevelClampingLow() {
        let config = LevelDefinitions.config(for: 0)
        XCTAssertEqual(config.level, 1)
    }

    func testLevelClampingHigh() {
        let config = LevelDefinitions.config(for: 99)
        XCTAssertEqual(config.level, 10)
    }

    func testLevelForStars() {
        XCTAssertEqual(LevelDefinitions.levelForStars(0), 1)
        XCTAssertEqual(LevelDefinitions.levelForStars(5), 1)
        XCTAssertEqual(LevelDefinitions.levelForStars(6), 2)
        XCTAssertEqual(LevelDefinitions.levelForStars(14), 2)
        XCTAssertEqual(LevelDefinitions.levelForStars(15), 3)
        XCTAssertEqual(LevelDefinitions.levelForStars(172), 10)
        XCTAssertEqual(LevelDefinitions.levelForStars(1000), 10)
    }

    func testStarsForNextLevel() {
        XCTAssertEqual(LevelDefinitions.starsForNextLevel(currentLevel: 1), 6)
        XCTAssertEqual(LevelDefinitions.starsForNextLevel(currentLevel: 9), 172)
        XCTAssertNil(LevelDefinitions.starsForNextLevel(currentLevel: 10))
    }

    func testEdgeToleranceDecreases() {
        let level1 = LevelDefinitions.config(for: 1)
        let level5 = LevelDefinitions.config(for: 5)
        let level10 = LevelDefinitions.config(for: 10)

        XCTAssertGreaterThan(level1.edgeTolerance, level5.edgeTolerance)
        XCTAssertGreaterThanOrEqual(level5.edgeTolerance, level10.edgeTolerance)
        XCTAssertEqual(level10.edgeTolerance, 0)
    }

    func testFontSizeDecreases() {
        for i in 1..<10 {
            let current = LevelDefinitions.config(for: i)
            let next = LevelDefinitions.config(for: i + 1)
            XCTAssertGreaterThan(current.fontSize, next.fontSize, "Level \(i) should have larger font than level \(i+1)")
        }
    }

    func testStarsRequiredIncreases() {
        for i in 1..<10 {
            let current = LevelDefinitions.config(for: i)
            let next = LevelDefinitions.config(for: i + 1)
            XCTAssertLessThan(current.starsRequired, next.starsRequired, "Level \(i) should require fewer stars than level \(i+1)")
        }
    }

    func testFontCreation() {
        for config in LevelDefinitions.all {
            let font = config.font
            XCTAssertEqual(font.pointSize, config.fontSize)
        }
    }
}
