import Foundation
import SwiftData

/// DESIGN_DOCUMENT.md §5.2–§5.4 (v2.5). One entry is one page, and **the transcript is
/// the record**: it holds only text the child has written. Everything they said but have
/// not yet written lives in `spokenBuffer` — provisional, editable, and absent from the
/// journal, exports and every count.
///
/// Separate dictations are separated by a newline in both fields, so a new telling always
/// starts a fresh line on the page and committed lines can never reflow underneath the
/// child's ink.
@Model
final class WritingSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var customTitle: String?

    // Captured at session start so a later settings change never rewrites history
    var fontKey: String = "jua"
    var sizeKey: String = "l"
    var modeRaw: Int = WritingMode.trace.rawValue

    /// THE RECORD — only text the child has written. Grows one finished line at a time.
    var transcript: String = ""
    /// Said but not yet written. Not part of the record.
    var spokenBuffer: String = ""
    /// Everything the recogniser heard, verbatim.
    var rawTranscript: String = ""
    var spokenDuration: Double = 0

    /// The child's voice for the whole sitting (§10.4).
    @Attribute(.externalStorage) var audioData: Data?

    // The writing itself. Only the latest pass is kept — re-tracing replaces.
    var tracedAt: Date?
    var accuracy: Double = 0
    var stars: Int = 0
    var points: Int = 0
    var letterAccuracies: [Double] = []
    var wordsWritten: Int = 0
    var totalWords: Int = 0

    var canvasWidth: Double = 0
    var canvasHeight: Double = 0
    @Attribute(.externalStorage) var strokeArchive: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?

    var author: UserProfile?

    init(setup: WritingSetup = .default, startedAt: Date = .now,
         transcript: String = "", spokenBuffer: String = "") {
        self.startedAt = startedAt
        self.transcript = transcript
        self.spokenBuffer = spokenBuffer
        self.rawTranscript = transcript
        self.fontKey = setup.face.id
        self.sizeKey = setup.size.id
        self.modeRaw = setup.mode.rawValue
        self.wordsWritten = Self.wordCount(transcript)
        self.totalWords = Self.wordCount(transcript) + Self.wordCount(spokenBuffer)
    }

    // MARK: - Derived

    var setup: WritingSetup {
        WritingSetup(faceID: fontKey, sizeID: sizeKey, mode: WritingMode(rawValue: modeRaw) ?? .trace)
    }

    var hasWriting: Bool { strokeArchive != nil && wordsWritten > 0 }

    /// A "draft" is an entry with spoken words still waiting (§5.4). The record itself is
    /// always fully written, whatever the buffer holds.
    var isComplete: Bool { totalWords > 0 && spokenBuffer.isEmpty }

    var wordsRemaining: Int { Self.wordCount(spokenBuffer) }

    /// What the writing page lays out: the record, then the spoken buffer, each telling on
    /// its own paragraph. The hard break is what keeps committed lines from reflowing.
    var pageText: String {
        if transcript.isEmpty { return spokenBuffer }
        if spokenBuffer.isEmpty { return transcript }
        return transcript + "\n" + spokenBuffer
    }

    var progress: Double {
        totalWords > 0 ? Double(wordsWritten) / Double(totalWords) : 0
    }

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    var displayDate: String { startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()) }
    var shortDate: String { startedAt.formatted(.dateTime.month(.abbreviated).day()) }
    var timeOfDay: String { startedAt.formatted(date: .omitted, time: .shortened) }

    var title: String { customTitle ?? firstLine }

    var firstLine: String {
        let source = transcript.isEmpty ? spokenBuffer : transcript
        let words = source.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
        return words.isEmpty ? "Empty entry" : (words.count < source.count ? words + "…" : words)
    }

    /// The next few unwritten words — the resume card quotes the buffer, the one piece of
    /// UI that ever shows spoken text outside the page itself.
    var nextWords: String {
        spokenBuffer.split(whereSeparator: \.isWhitespace).prefix(6).joined(separator: " ")
    }

    /// The record/buffer boundary moved — a line was finished, a word was fixed, or more
    /// was said. Counts follow the text; they are never set independently.
    func setPage(record: String, buffer: String) {
        transcript = record
        spokenBuffer = buffer
        wordsWritten = Self.wordCount(record)
        totalWords = wordsWritten + Self.wordCount(buffer)
    }

    /// A new telling always starts its own paragraph (§5.2).
    func appendDictation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        setPage(record: transcript,
                buffer: spokenBuffer.isEmpty ? trimmed : spokenBuffer + "\n" + trimmed)
    }

    func record(_ result: ScoreResult, strokes: Data?, thumbnail: Data?, canvas: CGSize, at date: Date = .now) {
        tracedAt = date
        accuracy = result.accuracy
        stars = result.stars
        points = result.totalPoints
        letterAccuracies = result.letterAccuracies
        strokeArchive = strokes
        thumbnailData = thumbnail
        canvasWidth = canvas.width
        canvasHeight = canvas.height
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }
}
