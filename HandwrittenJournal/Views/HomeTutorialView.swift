import SwiftUI

/// Frames 61 and 62 — Journal Home's first visit (§4.3, v3.11). The screen shows a new
/// profile its two tiles one at a time, with the tour's spotlight (`TourOverlay`):
/// *Practice my letters* comes first — the sheet has its own lessons waiting behind it
/// (frames 63 and 60) — and, back from the sheet, *New Entry*. Only a tap on the tile in
/// hand moves the tour on; *Skip* ends it.

/// The tour's steps, in order (frames 61, 62). Pure, so the tests can walk a profile
/// through them without a screen.
enum HomeTutorialStep: Int, CaseIterable, Hashable {
    /// *Tap Practice my letters* is owed — a new profile's first visit.
    case practice = 0
    /// Practice was tapped; *Now tap New Entry* is owed, back on the screen.
    case newEntry = 1
    /// Both tiles tapped, or the tour skipped.
    case done = 2

    /// The tile the step points at; none once the tour is done.
    var tile: HomeTile? {
        switch self {
        case .practice: return .practice
        case .newEntry: return .newEntry
        case .done:     return nil
        }
    }

    /// The step after a tap on `tile`: only the tile in hand moves the tour on — the
    /// other one is under the scrim.
    func advanced(byTapping tile: HomeTile) -> HomeTutorialStep {
        guard tile == self.tile, let next = HomeTutorialStep(rawValue: rawValue + 1) else { return self }
        return next
    }
}

@MainActor
extension HomeTutorialStep {
    /// What the step says — and what its bubble shows (§4.12).
    var cue: Voice.Cue? {
        switch self {
        case .practice: return .homeHowPractice
        case .newEntry: return .homeHowNewEntry
        case .done:     return nil
        }
    }

    var text: String { cue?.text ?? "" }

    /// What Journal Home says as it appears from the picker: the greeting once the tour
    /// is done, nothing before — the tour's own line takes its place.
    var greeting: Voice.Cue? { self == .done ? .home : nil }
}

/// The action deck's two tiles (§4.3).
enum HomeTile: Hashable {
    case newEntry
    case practice
}

/// Where each tile of the deck is, reported up so the tour can point at one.
struct HomeTileAnchorKey: PreferenceKey {
    static var defaultValue: [HomeTile: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [HomeTile: Anchor<CGRect>], nextValue: () -> [HomeTile: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
