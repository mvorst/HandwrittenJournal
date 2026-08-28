import Foundation
import SwiftData

/// DESIGN_DOCUMENT.md §5.2. A session is one sitting: the child talks once, and the whole
/// transcript becomes one continuous page they trace through.
///
/// There is no sentence entity. The transcript is a single scrolling document — splitting
/// it into pieces made the child's own words feel like exercises, and made the app carry a
/// splitter, a review list and a queue that earned nothing.
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

    /// What gets traced — the confirmed transcript.
    var transcript: String = ""
    /// What the recogniser originally heard, before anyone fixed it.
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

    init(setup: WritingSetup = .default, startedAt: Date = .now, transcript: String = "") {
        self.startedAt = startedAt
        self.transcript = transcript
        self.rawTranscript = transcript
        self.fontKey = setup.face.id
        self.sizeKey = setup.size.id
        self.modeRaw = setup.mode.rawValue
        self.totalWords = Self.wordCount(transcript)
    }

    // MARK: - Derived

    var setup: WritingSetup {
        WritingSetup(faceID: fontKey, sizeID: sizeKey, mode: WritingMode(rawValue: modeRaw) ?? .trace)
    }

    var hasWriting: Bool { strokeArchive != nil && wordsWritten > 0 }

    /// A session the child stopped part-way through. This is what a "draft" is now.
    var isComplete: Bool { totalWords > 0 && wordsWritten >= totalWords }

    var wordsRemaining: Int { max(0, totalWords - wordsWritten) }

    var progress: Double {
        totalWords > 0 ? Double(wordsWritten) / Double(totalWords) : 0
    }

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    var displayDate: String { startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()) }
    var shortDate: String { startedAt.formatted(.dateTime.month(.abbreviated).day()) }
    var timeOfDay: String { startedAt.formatted(date: .omitted, time: .shortened) }

    var title: String { customTitle ?? firstLine }

    var firstLine: String {
        let words = transcript.split(separator: " ").prefix(8).joined(separator: " ")
        return words.isEmpty ? "Empty entry" : (words.count < transcript.count ? words + "…" : words)
    }

    /// Where the child got to, in words — used to scroll a resumed session to the right
    /// place and to label the resume card.
    var nextWords: String {
        let words = transcript.split(separator: " ")
        guard wordsWritten < words.count else { return "" }
        return words[wordsWritten...].prefix(6).joined(separator: " ")
    }

    func updateTranscript(_ text: String) {
        transcript = text
        totalWords = Self.wordCount(text)
    }

    func record(_ result: ScoreResult, strokes: Data?, thumbnail: Data?, canvas: CGSize, at date: Date = .now) {
        tracedAt = date
        accuracy = result.accuracy
        stars = result.stars
        points = result.totalPoints
        letterAccuracies = result.letterAccuracies
        wordsWritten = result.wordsWritten
        totalWords = max(totalWords, result.totalWords)
        strokeArchive = strokes
        thumbnailData = thumbnail
        canvasWidth = canvas.width
        canvasHeight = canvas.height
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }
}
