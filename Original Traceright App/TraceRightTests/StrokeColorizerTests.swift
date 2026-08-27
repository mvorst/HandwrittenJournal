import XCTest
@testable import TraceRight

final class StrokeColorizerTests: XCTestCase {

    func testClassifiesInsidePoint() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 800, height: 400)

        _ = renderer.generateMask(text: "MMMMM", levelConfig: config, canvasSize: size, screenScale: 1.0)
        let colorizer = StrokeColorizer(maskRenderer: renderer, tolerance: 0)

        // Find a point that's inside
        var foundInside = false
        for y in 0..<renderer.height {
            for x in 0..<renderer.width {
                if renderer.isLetterPixel(x: x, y: y) {
                    let result = colorizer.classify(point: CGPoint(x: x, y: y))
                    XCTAssertTrue(result)
                    foundInside = true
                    break
                }
            }
            if foundInside { break }
        }
        XCTAssertTrue(foundInside)
    }

    func testClassifiesOutsidePoint() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 800, height: 400)

        _ = renderer.generateMask(text: "I", levelConfig: config, canvasSize: size, screenScale: 1.0)
        let colorizer = StrokeColorizer(maskRenderer: renderer, tolerance: 0)

        // Point at (0,0) should be outside (margins + unlikely letter position)
        let result = colorizer.classify(point: CGPoint(x: 0, y: 0))
        XCTAssertFalse(result)
    }

    func testToleranceExpandsInside() {
        let renderer = MaskRenderer()
        let config = LevelDefinitions.config(for: 1)
        let size = CGSize(width: 800, height: 400)

        _ = renderer.generateMask(text: "MMMMM", levelConfig: config, canvasSize: size, screenScale: 1.0)

        // Find an edge pixel (a pixel just outside a letter pixel)
        var edgePoint: CGPoint?
        for y in 1..<(renderer.height - 1) {
            for x in 1..<(renderer.width - 1) {
                if !renderer.isLetterPixel(x: x, y: y) {
                    // Check if any neighbor is inside
                    let neighbors = [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]
                    for (nx, ny) in neighbors {
                        if renderer.isLetterPixel(x: nx, y: ny) {
                            edgePoint = CGPoint(x: x, y: y)
                            break
                        }
                    }
                }
                if edgePoint != nil { break }
            }
            if edgePoint != nil { break }
        }

        guard let edge = edgePoint else {
            XCTFail("Could not find edge point")
            return
        }

        // Without tolerance, should be outside
        let colorizerNoTolerance = StrokeColorizer(maskRenderer: renderer, tolerance: 0)
        XCTAssertFalse(colorizerNoTolerance.classify(point: edge))

        // With tolerance, should be inside (adjacent to letter pixel)
        let colorizerWithTolerance = StrokeColorizer(maskRenderer: renderer, tolerance: 2)
        XCTAssertTrue(colorizerWithTolerance.classify(point: edge))
    }
}
