import Testing
import CoreGraphics
import Compression
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

    @Test("Round-trips geometry, the inside flag and each point's letter")
    func roundTrip() throws {
        let original = Self.sampleStrokes(count: 12, pointsEach: 60)
        let archive = try StrokeArchive.decodeArchive(StrokeArchive.encode(original))
        #expect(archive.attributed, "v2 carries the attribution")
        let decoded = archive.strokes
        #expect(decoded.count == original.count)
        for (a, b) in zip(original, decoded) {
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.location.x - q.location.x) < 0.01)
                #expect(abs(p.location.y - q.location.y) < 0.01)
                #expect(p.isInside == q.isInside)
                #expect(abs(p.force - q.force) < 0.01)
                #expect(p.letterIndex == q.letterIndex)
            }
        }
    }

    @Test("Points off any letter keep their -1 through the archive")
    func unattributedPointsSurvive() throws {
        var stroke = TracingStroke()
        stroke.append(StrokePoint(location: CGPoint(x: 1, y: 2), force: 0.5, isInside: false, letterIndex: -1))
        stroke.append(StrokePoint(location: CGPoint(x: 3, y: 4), force: 0.5, isInside: true, letterIndex: 70_000))
        let decoded = try StrokeArchive.decode(StrokeArchive.encode([stroke]))
        #expect(decoded[0].points.map(\.letterIndex) == [-1, 70_000])
    }

    /// A v1 blob, built by hand: the format every entry written before v2 holds.
    private func legacyArchive(_ strokes: [TracingStroke]) -> Data {
        var raw = Data()
        raw.append(contentsOf: StrokeArchive.magic)
        raw.append(1)
        raw.append(0)
        func le<T>(_ value: T) { var v = value; withUnsafeBytes(of: &v) { raw.append(contentsOf: $0) } }
        le(UInt16(strokes.count))
        for stroke in strokes {
            le(UInt16(stroke.points.count))
            for p in stroke.points {
                le(Float32(p.location.x)); le(Float32(p.location.y))
                raw.append(UInt8(clamping: Int((p.force * 255).rounded())))
                raw.append(p.isInside ? 1 : 0)
            }
        }
        let capacity = raw.count + 64
        var out = Data(count: capacity)
        let written = out.withUnsafeMutableBytes { dst -> Int in
            raw.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          src.bindMemory(to: UInt8.self).baseAddress!, raw.count,
                                          nil, COMPRESSION_LZFSE)
            }
        }
        return out.prefix(written)
    }

    @Test("A v1 archive still decodes — unattributed, so the canvas attributes it afresh")
    func legacyArchiveDecodes() throws {
        let original = Self.sampleStrokes(count: 3, pointsEach: 20)
        let archive = try StrokeArchive.decodeArchive(legacyArchive(original))
        #expect(!archive.attributed)
        #expect(archive.strokes.count == original.count)
        for (a, b) in zip(original, archive.strokes) {
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.location.x - q.location.x) < 0.01)
                #expect(p.isInside == q.isInside)
                #expect(q.letterIndex == -1)
            }
        }
    }

    @Test("v3 carries each stroke's layer and crayon, and the helpers split them")
    func layersRoundTrip() throws {
        var ink = Self.sampleStrokes(count: 1, pointsEach: 12)[0]
        ink.layer = .ink
        var doodle = Self.sampleStrokes(count: 1, pointsEach: 9)[0]
        doodle.layer = .doodle
        doodle.crayon = 2
        let archive = try StrokeArchive.decodeArchive(StrokeArchive.encode([ink, doodle]))
        #expect(archive.attributed)
        #expect(archive.strokes.count == 2)
        #expect(!archive.strokes[0].isDoodle)
        #expect(archive.strokes[1].isDoodle)
        #expect(archive.strokes[1].crayon == 2)
        #expect(archive.strokes.ink.count == 1 && archive.strokes.doodles.count == 1)
        #expect(archive.strokes[1].points.count == 9)
    }

    /// A v2 blob, built by hand: what every entry written before v3 holds.
    private func v2Archive(_ strokes: [TracingStroke]) -> Data {
        var raw = Data()
        raw.append(contentsOf: StrokeArchive.magic)
        raw.append(2)
        raw.append(0)
        func le<T>(_ value: T) { var v = value; withUnsafeBytes(of: &v) { raw.append(contentsOf: $0) } }
        le(UInt16(strokes.count))
        for stroke in strokes {
            le(UInt16(stroke.points.count))
            for p in stroke.points {
                le(Float32(p.location.x)); le(Float32(p.location.y))
                raw.append(UInt8(clamping: Int((p.force * 255).rounded())))
                raw.append(p.isInside ? 1 : 0)
                le(Int32(clamping: p.letterIndex))
            }
        }
        let capacity = raw.count + 64
        var out = Data(count: capacity)
        let written = out.withUnsafeMutableBytes { dst -> Int in
            raw.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          src.bindMemory(to: UInt8.self).baseAddress!, raw.count,
                                          nil, COMPRESSION_LZFSE)
            }
        }
        return out.prefix(written)
    }

    @Test("A v2 archive still decodes — attributed, and every stroke ink")
    func v2ArchiveDecodes() throws {
        let original = Self.sampleStrokes(count: 3, pointsEach: 20)
        let archive = try StrokeArchive.decodeArchive(v2Archive(original))
        #expect(archive.attributed)
        #expect(archive.strokes.count == original.count)
        #expect(archive.strokes.allSatisfy { !$0.isDoodle })
        for (a, b) in zip(original, archive.strokes) {
            #expect(a.points.map(\.letterIndex) == b.points.map(\.letterIndex))
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
