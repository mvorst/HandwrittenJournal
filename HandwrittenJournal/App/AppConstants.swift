import SwiftUI

/// Generated from WIREFRAME_SPEC.md §5–§9. Do not hand-edit values; change the spec first.
enum Tokens {

    // MARK: - §5 Colour

    enum Colour {
        // 5.1 Surfaces
        static let paper        = Color(hex: 0xFAF8F5)
        static let paperSunk    = Color(hex: 0xF1EEE9)
        static let paperRaised  = Color(hex: 0xFFFFFF)
        static let overlayScrim = Color(hex: 0x000000).opacity(0.40)

        // 5.2 Ink
        static let inkNatural    = Color(hex: 0x2C2C2E)
        static let inkInside     = Color(hex: 0x34C759)
        static let inkOutside    = Color(hex: 0xFF3B30)
        static let inkInsideCB   = Color(hex: 0x007AFF)
        static let inkOutsideCB  = Color(hex: 0xFF9500)

        // 5.3 Guide layer
        static let guideText = Color(hex: 0x000000).opacity(0.80)
        /// Dictated words waiting to be written — cooler as well as lighter than the
        /// guide, so "not yet real" reads at a glance (WIREFRAME_SPEC.md §5.3, v2.5).
        static let spokenText = Color(hex: 0x5B6B8C).opacity(0.42)
        static let ruleLine  = Color(hex: 0xE5E5EA)

        // 5.4 Text
        static let textPrimary   = Color(hex: 0x1C1C1E)
        static let textSecondary = Color(hex: 0x6C6C70)
        static let textOnAction  = Color(hex: 0xFFFFFF)

        // 5.5 Semantic
        static let action         = Color(hex: 0x007AFF)
        static let actionPressed  = Color(hex: 0x0060D0)
        static let actionDisabled = Color(hex: 0xB4D5FA)
        static let starOn         = Color(hex: 0xFFD700)
        static let starOff        = Color(hex: 0xD1D1D6)
        static let streakFlame    = Color(hex: 0xFF9500)
        static let success        = Color(hex: 0x34C759)
        static let danger         = Color(hex: 0xFF3B30)
        static let divider        = Color(hex: 0xE5E5EA)
    }

    // MARK: - §6 Grid and spacing

    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 24      // screen outer margin
        static let s6: CGFloat = 32
        static let s7: CGFloat = 40      // writing surface inset — engine constant
        static let s8: CGFloat = 56
        static let s9: CGFloat = 72
    }

    /// §3 artboard and §6 margins. The app is portrait only.
    enum Layout {
        static let screenMargin: CGFloat  = Space.s5
        static let surfaceInset: CGFloat  = Space.s7
        static let toolbarHeight: CGFloat = 72
        static let homeIndicator: CGFloat = 24
        /// Width of the writing surface on an 834 pt canvas. Computed at runtime from the
        /// real width; this is the reference figure the spec quotes.
        static func surfaceWidth(in totalWidth: CGFloat) -> CGFloat {
            totalWidth - surfaceInset * 2
        }
        static func contentWidth(in totalWidth: CGFloat) -> CGFloat {
            totalWidth - screenMargin * 2
        }
    }

    // MARK: - §8 Elevation, radii, strokes

    enum Radius {
        static let chip: CGFloat   = 8
        static let button: CGFloat = 14
        static let card: CGFloat   = 20
        static let sheet: CGFloat  = 28
    }

    enum Elevation {
        static let card   = ShadowSpec(radius: 8,  y: 0, opacity: 0.06)
        static let raised = ShadowSpec(radius: 24, y: 0, opacity: 0.10)
        static let modal  = ShadowSpec(radius: 48, y: 0, opacity: 0.18)
    }

    struct ShadowSpec {
        let radius: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 2
        static let selected: CGFloat = 3
    }

    // MARK: - §4 Interaction

    enum Motion {
        static let standard: Double  = 0.30
        static let pageFlip: Double  = 0.35
        static let guideFade: Double = 0.50
        static let settle: Double    = 0.45
        static var spring: Animation { .spring(response: 0.4, dampingFraction: 0.7) }
    }

    enum Target {
        static let minimum: CGFloat        = 44
        static let childPrimaryW: CGFloat  = 280
        static let childPrimaryH: CGFloat  = 64
    }
}

// MARK: - §7.1 UI type scale
// SF Pro Rounded. The wireframes substitute Nunito; the app uses the real thing.

extension Font {
    private static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static var hjDisplay: Font    { rounded(44, .bold) }
    static var hjTitle1: Font     { rounded(34, .bold) }
    static var hjTitle2: Font     { rounded(28, .semibold) }
    static var hjHeadline: Font   { rounded(22, .semibold) }
    static var hjBody: Font       { rounded(18, .regular) }
    static var hjBodyEm: Font     { rounded(18, .semibold) }
    static var hjCaption: Font    { rounded(15, .regular) }
    static var hjCaptionSm: Font  { rounded(13, .regular) }
    static var hjButton: Font     { rounded(24, .bold) }
    static var hjButtonSm: Font   { rounded(18, .semibold) }
    static var hjNumeralXL: Font  { rounded(60, .bold) }
    static var hjNumeralL: Font   { rounded(34, .bold) }
}

/// Line heights from §7.1, for places that need exact vertical rhythm.
enum LineHeight {
    static let display: CGFloat = 52, title1: CGFloat = 41, title2: CGFloat = 34
    static let headline: CGFloat = 28, body: CGFloat = 24, caption: CGFloat = 20
    static let captionSm: CGFloat = 18, button: CGFloat = 28, buttonSm: CGFloat = 22
    static let numeralXL: CGFloat = 68, numeralL: CGFloat = 41
}

// MARK: - Colour helper

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension View {
    func hjShadow(_ spec: Tokens.ShadowSpec) -> some View {
        shadow(color: .black.opacity(spec.opacity), radius: spec.radius, x: 0, y: spec.y)
    }
}
