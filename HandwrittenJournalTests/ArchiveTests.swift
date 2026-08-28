import Testing
import CoreGraphics
import Foundation
@testable import HandwrittenJournal

struct StrokeArchiveTests {

    static func sampleStrokes(count: Int, pointsEach: Int) -> [TracingStroke] {
        (0..<count).map { s in
            var stroke = TracingStroke()
            for p in 0..<pointsEach {
                stroke.append(StrokePoint(location: CGPoint(x: Double(s) * 3 + Double(p) * 0.5,
                                                            y: Double(p) * 0.25),
                                          force: CGFloat(p % 100) / 100,
                                          isInside: p % 3 != 0,
                                          letterIndex: p % 7))
            }
            return stroke
        }
    }

    @Test("Round-trips geometry and the inside flag")
    func roundTrip() throws {
        let original = Self.sampleStrokes(count: 12, pointsEach: 60)
        let decoded = try StrokeArchive.decode(StrokeArchive.encode(original))
        #expect(decoded.count == original.count)
        for (a, b) in zip(original, decoded) {
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.location.x - q.location.x) < 0.01)
                #expect(abs(p.location.y - q.location.y) < 0.01)
                #expect(p.isInside == q.isInside)
                #expect(abs(p.force - q.force) < 0.01)
            }
        }
    }

    @Test("Six thousand points compress to well under the 60 KB raw size")
    func compressionExpectation() throws {
        let strokes = Self.sampleStrokes(count: 60, pointsEach: 100)   // 6,000 points
        #expect(strokes.pointCount == 6_000)
        let encoded = try StrokeArchive.encode(strokes)
        #expect(encoded.count < 60_000)
    }

    @Test("A corrupt blob throws rather than crashing")
    func corruptBlob() {
        #expect(throws: (any Error).self) { try StrokeArchive.decode(Data([1, 2, 3, 4, 5])) }
        #expect(throws: (any Error).self) { try StrokeArchive.decode(Data()) == [] }
    }

    @Test("An empty stroke set round-trips")
    func emptyRoundTrip() throws {
        #expect(try StrokeArchive.decode(StrokeArchive.encode([])).isEmpty)
    }
}
