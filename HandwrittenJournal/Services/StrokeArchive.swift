import Foundation
import Compression

/// DESIGN_DOCUMENT.md §6.1 — the `HJST` binary format.
///
/// A two-line sentence traced by a child runs 3,000–8,000 points. JSON would be ~400 KB
/// per sentence, which is unacceptable when the goal is to keep every sentence forever
/// and eventually sync it. This lands at ~20 KB compressed.
///
/// **v2 carries each point's letter.** The record is derived from which letters have
/// ink, and ink is attributed to the row in hand as it is drawn; an archive that stores
/// only positions has to re-derive that against the mask when the page reopens, and a
/// descender's tail re-read against the whole page can land on the row below and
/// unfinish a line the child finished. Storing the attribution makes a restored page
/// reopen with exactly the record it closed with. v1 archives still decode; their
/// points come back unattributed and the canvas attributes them afresh.
enum StrokeArchive {

    enum ArchiveError: Error { case badMagic, badVersion, truncated, compressionFailed }

    static let magic: [UInt8] = Array("HJST".utf8)
    static let version: UInt8 = 2
    /// §6.1 — set when per-point inside data is meaningless, as it will be in Copy mode.
    static let flagNoInsideData: UInt8 = 1 << 0

    /// What a decode hands back: the strokes, and whether their points carry the letter
    /// they were drawn against.
    struct Decoded {
        let strokes: [TracingStroke]
        let attributed: Bool
    }

    // MARK: - Encode

    static func encode(_ strokes: [TracingStroke], flags: UInt8 = 0) throws -> Data {
        var raw = Data()
        raw.append(contentsOf: magic)
        raw.append(version)
        raw.append(flags)
        raw.appendLE(UInt16(min(strokes.count, Int(UInt16.max))))

        for stroke in strokes.prefix(Int(UInt16.max)) {
            let points = Array(stroke.points.prefix(Int(UInt16.max)))
            raw.appendLE(UInt16(points.count))
            for p in points {
                raw.appendLE(Float32(p.location.x))
                raw.appendLE(Float32(p.location.y))
                raw.append(UInt8(clamping: Int((p.force * 255).rounded())))
                raw.append(p.isInside ? 1 : 0)
                raw.appendLE(Int32(clamping: p.letterIndex))
            }
        }
        return try compress(raw)
    }

    // MARK: - Decode

    static func decode(_ data: Data) throws -> [TracingStroke] {
        try decodeArchive(data).strokes
    }

    static func decodeArchive(_ data: Data) throws -> Decoded {
        let raw = try decompress(data)
        var cursor = 0

        func need(_ n: Int) throws {
            guard cursor + n <= raw.count else { throw ArchiveError.truncated }
        }

        try need(8)
        guard Array(raw[0..<4]) == magic else { throw ArchiveError.badMagic }
        let version = raw[4]
        guard version == 1 || version == 2 else { throw ArchiveError.badVersion }
        let attributed = version >= 2
        let pointSize = attributed ? 14 : 10
        cursor = 6
        let strokeCount = Int(raw.readLE(UInt16.self, at: &cursor))

        var strokes: [TracingStroke] = []
        strokes.reserveCapacity(strokeCount)
        for _ in 0..<strokeCount {
            try need(2)
            let pointCount = Int(raw.readLE(UInt16.self, at: &cursor))
            try need(pointCount * pointSize)
            var stroke = TracingStroke()
            stroke.points.reserveCapacity(pointCount)
            for _ in 0..<pointCount {
                let x = raw.readLE(Float32.self, at: &cursor)
                let y = raw.readLE(Float32.self, at: &cursor)
                let force = CGFloat(raw[raw.startIndex + cursor]) / 255; cursor += 1
                let inside = raw[raw.startIndex + cursor] == 1; cursor += 1
                let letter = attributed ? Int(raw.readLE(Int32.self, at: &cursor)) : -1
                stroke.points.append(StrokePoint(location: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                                                 force: force,
                                                 isInside: inside,
                                                 letterIndex: letter))
            }
            strokes.append(stroke)
        }
        return Decoded(strokes: strokes, attributed: attributed)
    }

    // MARK: - LZFSE

    private static func compress(_ data: Data) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_ENCODE, capacityHint: data.count)
    }

    private static func decompress(_ data: Data) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_DECODE, capacityHint: max(data.count * 8, 1024))
    }

    private static func transform(_ data: Data, operation: compression_stream_operation, capacityHint: Int) throws -> Data {
        guard !data.isEmpty else { return Data() }
        var out = Data()
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var stream = compression_stream(dst_ptr: buffer, dst_size: bufferSize, src_ptr: buffer, src_size: 0, state: nil)
        guard compression_stream_init(&stream, operation, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else {
            throw ArchiveError.compressionFailed
        }
        defer { compression_stream_destroy(&stream) }

        let result: Data? = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = base
            stream.src_size = data.count
            var accumulated = Data()
            repeat {
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    accumulated.append(buffer, count: bufferSize - stream.dst_size)
                    if status == COMPRESSION_STATUS_END { return accumulated }
                default:
                    return nil
                }
            } while true
        }
        guard let final = result else { throw ArchiveError.compressionFailed }
        out = final
        return out
    }
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func appendLE<T>(_ value: T) {
        var v = value
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    func readLE<T>(_ type: T.Type, at cursor: inout Int) -> T {
        let size = MemoryLayout<T>.size
        let start = index(startIndex, offsetBy: cursor)
        let slice = self[start..<index(start, offsetBy: size)]
        cursor += size
        return slice.withUnsafeBytes { $0.loadUnaligned(as: T.self) }
    }
}
