import SwiftUI
import UIKit

/// WIREFRAME_SPEC.md §7.2 — the curated list of traceable faces.
///
/// Each offered face has its own outline-fitted formation paths. The shapes differ:
/// Varela Round, for example, has a two-storey a. Adding a face requires paths and
/// validation against both the mask and all-font tracing tests.
struct JournalFace: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    /// PostScript name of the bundled font, or nil to fall back to the system rounded face.
    let postScriptName: String?
    let reason: String

    var isBundled: Bool { postScriptName != nil }

    static let all: [JournalFace] = [
        .init(id: "jua",     label: "Jua",        postScriptName: "Jua-Regular",
              reason: String(localized: "Rounded and heavy. The default.")),
        .init(id: "andika",  label: "Andika",     postScriptName: "Andika-Bold",
              reason: String(localized: "Designed for children learning to read.")),
        .init(id: "varela",  label: "Varela Round", postScriptName: "VarelaRound-Regular",
              reason: String(localized: "Very open letters, evenly rounded.")),
        .init(id: "sniglet", label: "Sniglet",    postScriptName: "Sniglet-ExtraBold",
              reason: String(localized: "The thickest — easiest to stay inside.")),
        .init(id: "comic",   label: "Comic Neue", postScriptName: "ComicNeue-Bold",
              reason: String(localized: "Looks like classroom printing.")),
    ]

    static let `default` = all[0]

    static func face(id: String) -> JournalFace { all.first { $0.id == id } ?? .default }

    /// Faces whose TTF is actually present in the bundle. Only these are offered.
    static var available: [JournalFace] {
        all.filter { face in
            guard let name = face.postScriptName else { return false }
            return UIFont(name: name, size: 12) != nil
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        if let name = postScriptName, let f = UIFont(name: name, size: size) { return f }
        // Heavy rounded system face is the closest traceable stand-in.
        let descriptor = UIFont.systemFont(ofSize: size, weight: .heavy)
            .fontDescriptor.withDesign(.rounded) ?? UIFont.systemFont(ofSize: size, weight: .heavy).fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// WIREFRAME_SPEC.md §7.3 — glyph size is a setting, not something earned.
struct JournalSize: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let size: CGFloat
    let lineSpacing: CGFloat

    static let all: [JournalSize] = [
        .init(id: "xl", label: String(localized: "Extra Large"), size: 96, lineSpacing: 120),
        .init(id: "l",  label: String(localized: "Large"),       size: 72, lineSpacing: 96),
        .init(id: "m",  label: String(localized: "Medium"),      size: 56, lineSpacing: 72),
        .init(id: "s",  label: String(localized: "Small"),       size: 42, lineSpacing: 56),
        .init(id: "xs", label: String(localized: "Extra Small"), size: 30, lineSpacing: 40),
    ]

    static let `default` = all[1]   // Large

    static func size(id: String) -> JournalSize { all.first { $0.id == id } ?? .default }

    /// The next size down, or nil at the smallest. Used by the Progress nudge (§13.5).
    var nextSmaller: JournalSize? {
        guard let i = Self.all.firstIndex(of: self), i + 1 < Self.all.count else { return nil }
        return Self.all[i + 1]
    }

    /// §11.2 ruled-line geometry, in points, relative to the baseline.
    var ascent: CGFloat  { size * 0.72 }
    var descent: CGFloat { size * 0.21 }
}

enum WritingMode: Int, Codable, CaseIterable, Sendable {
    case trace = 0
    case copy  = 1

    var label: String { self == .trace ? "Trace" : "Copy" }
    /// Copy mode needs a different scoring algorithm entirely — DESIGN_DOCUMENT §7.5.
    var isAvailable: Bool { self == .trace }
}

/// The three writing settings, resolved together. Sessions capture this at start so a
/// later settings change never rewrites history.
struct WritingSetup: Hashable, Sendable {
    var face: JournalFace
    var size: JournalSize
    var mode: WritingMode

    static let `default` = WritingSetup(face: .default, size: .default, mode: .trace)

    init(face: JournalFace = .default, size: JournalSize = .default, mode: WritingMode = .trace) {
        self.face = face; self.size = size; self.mode = mode
    }

    init(faceID: String, sizeID: String, mode: WritingMode) {
        self.face = .face(id: faceID)
        self.size = .size(id: sizeID)
        self.mode = mode
    }

    var summary: String { "\(face.label) · \(size.label) · \(mode.label)" }
    var shortSummary: String { "\(face.label) · \(size.label)" }

    func uiFont() -> UIFont { face.uiFont(size: size.size) }
}
