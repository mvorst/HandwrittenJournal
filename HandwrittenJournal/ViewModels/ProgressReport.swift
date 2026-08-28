import Foundation

/// DESIGN_DOCUMENT.md §4.9. Aggregates by **setting**, because raw accuracy drops every
/// time the font or size changes and a single line would tell a child they are getting
/// worse at the moment a grown-up made the task harder.
struct ProgressReport {
    let profile: UserProfile

    struct Row: Identifiable {
        var id: String { "\(fontKey)-\(sizeKey)-\(mode.rawValue)" }
        let fontKey: String
        let sizeKey: String
        let mode: WritingMode
        let best: Double
        let average: Double
        let count: Int
        var isCurrent = false

        var setup: WritingSetup { WritingSetup(faceID: fontKey, sizeID: sizeKey, mode: mode) }
        var label: String { setup.shortSummary }
    }

    /// Entries the child has actually written in.
    private var written: [WritingSession] { profile.orderedSessions.filter(\.hasWriting) }

    /// Only rows that have data — otherwise the table is a wall of zeros.
    var rows: [Row] {
        let grouped = Dictionary(grouping: written) { session in
            "\(session.fontKey)|\(session.sizeKey)|\(session.modeRaw)"
        }
        let current = profile.setup
        return grouped.compactMap { key, sessions -> Row? in
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, let modeRaw = Int(parts[2]) else { return nil }
            let accuracies = sessions.map(\.accuracy)
            guard !accuracies.isEmpty else { return nil }
            let mode = WritingMode(rawValue: modeRaw) ?? .trace
            return Row(fontKey: parts[0], sizeKey: parts[1], mode: mode,
                       best: accuracies.max() ?? 0,
                       average: accuracies.reduce(0, +) / Double(accuracies.count),
                       count: accuracies.count,
                       isCurrent: parts[0] == current.face.id && parts[1] == current.size.id && mode == current.mode)
        }
        .sorted { $0.count > $1.count }
    }

    /// A 5-entry rolling average, newest last.
    var trend: [Double] {
        let ordered = written
            .sorted { ($0.tracedAt ?? .distantPast) < ($1.tracedAt ?? .distantPast) }
            .map(\.accuracy)
        guard ordered.count >= 5 else { return [] }
        return (4..<ordered.count).map { i in
            ordered[(i - 4)...i].reduce(0, +) / 5
        }
    }

    /// Points on the time axis where the font or size changed — a dip after one of these
    /// is expected, and saying so is the whole job of this screen.
    var settingMarkers: [(index: Int, label: String)] {
        let ordered = written.sorted { ($0.tracedAt ?? .distantPast) < ($1.tracedAt ?? .distantPast) }
        var markers: [(Int, String)] = []
        var previous: String?
        for (i, session) in ordered.enumerated() {
            let key = "\(session.fontKey)|\(session.sizeKey)"
            if let previous, previous != key {
                markers.append((max(0, i - 4), session.setup.size.label))
            }
            previous = key
        }
        return markers
    }

    var hasEnoughData: Bool { (rows.first?.count ?? 0) >= 5 }

    var currentRow: Row? { rows.first(where: \.isCurrent) }

    var sessionCount: Int { written.count }
    var wordCount: Int { written.reduce(0) { $0 + $1.wordsWritten } }
    var daysJournaled: Int {
        Set(written.compactMap { $0.tracedAt.map { Calendar.current.startOfDay(for: $0) } }).count
    }

    /// §13.5 — the only thing that replaces level progression. A suggestion to a grown-up
    /// when the current setting has been comfortable for a fortnight.
    var sizeSuggestion: String? {
        guard let smaller = profile.setup.size.nextSmaller else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        let recent = written
            .filter { $0.fontKey == profile.fontKey && $0.sizeKey == profile.sizeKey }
            .filter { ($0.tracedAt ?? .distantPast) >= cutoff }
            .map(\.accuracy)
        guard recent.count >= 5 else { return nil }
        let mean = recent.reduce(0, +) / Double(recent.count)
        guard mean >= 0.90 else { return nil }
        return "\(profile.name) has been above 90% for two weeks — \(smaller.label) might be ready to try."
    }
}
