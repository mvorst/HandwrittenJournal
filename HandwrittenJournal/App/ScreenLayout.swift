import SwiftUI

/// WIREFRAME_SPEC.md §3 (v3.3) — which of the two layouts a window gets, and the
/// numbers that follow from it.
///
/// **The page keeps its portrait width.** Ink is stored at the width it was written at
/// and drawn over the guide letters, so a page must never re-wrap (§11.1). In landscape
/// the writing page, the reading page and the practice sheet therefore stay the width
/// the device has in portrait — the shorter side of the window — and everything the
/// portrait footer held moves into a **rail** beside the page, on the side of the free
/// hand (`RailSide`). The app is full screen only, so the window is the screen.
struct ScreenLayout: Equatable {
    let size: CGSize
    /// The side the rail takes in landscape; ignored in portrait.
    var railSide: RailSide.Resolved = .left

    var isLandscape: Bool { size.width > size.height }

    /// The width the page keeps in both orientations: the device's portrait width.
    var pageWidth: CGFloat { min(size.width, size.height) }

    /// What is left beside the page in landscape — 344 pt on a 13-inch iPad, 360 on an
    /// 11-inch, 389 on a mini — and nothing in portrait.
    var railWidth: CGFloat { isLandscape ? size.width - pageWidth : 0 }

    var railOnLeft: Bool { isLandscape && railSide == .left }
    var railOnRight: Bool { isLandscape && railSide == .right }

    /// Journal Home in landscape (§4.3, v3.3): the dashboard column — header, action
    /// deck, points, badges — beside the journal. 560 pt where there is room, never more
    /// than half of the content width.
    var dashboardWidth: CGFloat {
        let content = size.width - Tokens.Layout.screenMargin * 2
        return min(560, (content - Tokens.Layout.screenMargin) / 2)
    }
}

extension ScreenLayout {
    /// From a geometry proxy at the root of a screen. The safe areas are added back in:
    /// the page width is the device's shorter side, not the shorter side of what is
    /// left between the status bar and the home indicator.
    init(_ geo: GeometryProxy, railSide: RailSide.Resolved = .left) {
        self.init(size: CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                               height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom),
                  railSide: railSide)
    }
}

/// §13.6 (v3.3) — where the landscape rail goes. *Auto* keeps it away from the writing
/// hand: left for a right-handed child, right for a left-handed one, so a resting
/// forearm never crosses a button and the finish control is never under the palm.
enum RailSide: Int, CaseIterable, Identifiable {
    case auto = 0
    case left = 1
    case right = 2

    var id: Int { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .auto:  return "Auto"
        case .left:  return "Left"
        case .right: return "Right"
        }
    }

    enum Resolved: Equatable { case left, right }

    func resolved(isLeftHanded: Bool) -> Resolved {
        switch self {
        case .auto:  return isLeftHanded ? .right : .left
        case .left:  return .left
        case .right: return .right
        }
    }
}
