import XCTest
@testable import TraceRight

final class MaskRendererTests: XCTestCase {

    func testMaskGeneratesNonEmptyData() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 500, height: 300)

        let info = renderer.generateMask(text: "Hello", levelConfig: config, canvasSize: size, screenScale: 2.0)

        XCTAssertGreaterThan(renderer.width, 0)
        XCTAssertGreaterThan(renderer.height, 0)
        XCTAssertEqual(renderer.width, 1000) // 500 * 2
        XCTAssertEqual(renderer.height, 600) // 300 * 2
        XCTAssertFalse(renderer.pixelData.isEmpty)
        XCTAssertFalse(info.lineOrigins.isEmpty)
    }

    func testMaskHasSomeWhitePixels() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1) // Largest font
        let size = CGSize(width: 800, height: 400)

        _ = renderer.generateMask(text: "A", levelConfig: config, canvasSize: size, screenScale: 1.0)

        let whiteCount = renderer.pixelData.filter { $0 > 127 }.count
        XCTAssertGreaterThan(whiteCount, 0, "Mask should contain letter pixels for 'A'")
    }

    func testEmptyTextProducesEmptyMask() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 500, height: 300)

        _ = renderer.generateMask(text: "", levelConfig: config, canvasSize: size, screenScale: 1.0)

        // Empty text should produce no line origins
        XCTAssertTrue(renderer.pixelData.allSatisfy { $0 <= 127 } || renderer.pixelData.isEmpty)
    }

    func testOutOfBoundsReturnsFalse() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 100, height: 100)

        _ = renderer.generateMask(text: "X", levelConfig: config, canvasSize: size, screenScale: 1.0)

        XCTAssertFalse(renderer.isLetterPixel(x: -1, y: 0))
        XCTAssertFalse(renderer.isLetterPixel(x: 0, y: -1))
        XCTAssertFalse(renderer.isLetterPixel(x: 10000, y: 0))
        XCTAssertFalse(renderer.isLetterPixel(x: 0, y: 10000))
    }

    func testZeroSizeCanvasHandled() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)

        let info = renderer.generateMask(text: "Test", levelConfig: config, canvasSize: .zero, screenScale: 2.0)

        XCTAssertTrue(renderer.pixelData.isEmpty)
        XCTAssertTrue(info.lineOrigins.isEmpty)
    }

    func testScaleFactorApplied() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 5)
        let size = CGSize(width: 200, height: 100)

        _ = renderer.generateMask(text: "Hi", levelConfig: config, canvasSize: size, screenScale: 3.0)

        XCTAssertEqual(renderer.width, 600) // 200 * 3
        XCTAssertEqual(renderer.height, 300) // 100 * 3
        XCTAssertEqual(renderer.scale, 3.0)
    }

    func testIsInsideLetterWithTolerance() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1) // Large font, tolerance 4
        let size = CGSize(width: 800, height: 400)

        _ = renderer.generateMask(text: "MMMMM", levelConfig: config, canvasSize: size, screenScale: 1.0)

        // Find a white pixel
        var foundWhite = false
        for y in 0..<renderer.height {
            for x in 0..<renderer.width {
                if renderer.isLetterPixel(x: x, y: y) {
                    // A pixel inside a letter should be detected with tolerance 0
                    XCTAssertTrue(renderer.isInsideLetter(point: CGPoint(x: x, y: y), tolerance: 0))
                    foundWhite = true
                    break
                }
            }
            if foundWhite { break }
        }
        XCTAssertTrue(foundWhite, "Should find at least one letter pixel in MMMMM")
    }
}
