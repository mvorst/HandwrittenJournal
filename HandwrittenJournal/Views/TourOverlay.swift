import SwiftUI

/// The tour's spotlight (v3.11) — how the app shows a first-time child what to tap:
/// everything but the thing in hand goes under the scrim, a speech bubble beside it says
/// what to do (the same words are said aloud by whoever shows it), and a finger taps it
/// until the child's does. Journal Home uses it for its two tiles (frames 61/62, §4.3)
/// and the practice sheet for the big A (frame 63, §4.11).
///
/// The overlay covers the screen but is not modal: the target stays under the hole, for
/// a finger and for VoiceOver alike, and a tap on the scrim says the line again.
struct TourOverlay: View {
    /// What the bubble says.
    let line: String
    /// The thing in hand, in this overlay's coordinate space.
    let target: CGRect
    /// The overlay's own size — the whole screen.
    let size: CGSize
    /// The hole's corner radius: a tile's radius plus its air by default; tighter round
    /// a letter.
    var holeRadius: CGFloat = Tokens.Radius.card + TourPlacement.holeInset
    let onSkip: () -> Void
    let onRepeat: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The bubble's height as laid out, for the landscape placement that centres it on
    /// the target; an estimate until it has been measured.
    @State private var bubbleHeight: CGFloat = TourPlacement.estimatedBubbleHeight

    var body: some View {
        let placement = TourPlacement.place(target: target, in: size, bubbleHeight: bubbleHeight)
        ZStack(alignment: .topLeading) {
            // The scrim with the target cut out of it: a tap in the hole reaches what is
            // beneath, a tap on the scrim says the line again.
            CutOutShape(hole: placement.hole, radius: holeRadius)
                .fill(Tokens.Colour.overlayScrim, style: FillStyle(eoFill: true))
                .contentShape(CutOutShape(hole: placement.hole, radius: holeRadius), eoFill: true)
                .onTapGesture(perform: onRepeat)
                .accessibilityHidden(true)
            // A rim round the hole, so it reads as *this one*.
            RoundedRectangle(cornerRadius: holeRadius)
                .strokeBorder(Tokens.Colour.action, lineWidth: Tokens.Stroke.selected)
                .frame(width: placement.hole.width, height: placement.hole.height)
                .offset(x: placement.hole.minX, y: placement.hole.minY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            bubble(placement)
            TutorialFinger(tip: placement.fingerTip, reduceMotion: reduceMotion)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .onAppear { AccessibilityNotification.Announcement(line).post() }
    }

    /// The speech bubble: the line, and *Skip* in the corner. Its tail sits on the target.
    private func bubble(_ placement: TourPlacement) -> some View {
        let tailEdge: Edge.Set = placement.tail == .top ? .top : .leading
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(line)
                .font(.hjHeadline)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer(minLength: 0)
                TextButton(title: "Skip", tint: Tokens.Colour.textSecondary, action: onSkip)
            }
        }
        .padding(.horizontal, Tokens.Space.s5)
        .padding(.top, Tokens.Space.s5)
        .padding(.bottom, Tokens.Space.s3)
        .padding(tailEdge, TourPlacement.tailLength)
        .frame(width: placement.bubble.width, alignment: .leading)
        .background(
            SpeechBubbleShape(radius: Tokens.Radius.card,
                              tail: placement.tail,
                              tailCenter: placement.tailCenter,
                              tailLength: TourPlacement.tailLength,
                              tailWidth: TourPlacement.tailWidth)
                .fill(Tokens.Colour.paperRaised)
                .hjShadow(Tokens.Elevation.modal)
        )
        .background(GeometryReader { geo in
            Color.clear.preference(key: BubbleHeightKey.self, value: geo.size.height)
        })
        .onPreferenceChange(BubbleHeightKey.self) { height in
            if height > 0 { bubbleHeight = height }
        }
        .offset(x: placement.bubble.minX, y: placement.bubble.minY)
        .accessibilityElement(children: .contain)
    }
}

/// Where the hole, the bubble and the finger go for a target — pure, so the tests can
/// place them without a screen. The bubble sits under the target in portrait, its tail
/// on the target's centre, and beside it in landscape when there is room; it never
/// crosses the screen margin.
struct TourPlacement: Equatable {
    enum Tail: Equatable { case top, leading }

    /// The cut-out in the scrim — the target with a little air round it.
    let hole: CGRect
    /// The bubble's frame, tail included; the height is the bubble's own.
    let bubble: CGRect
    let tail: Tail
    /// Where the tail points along its edge — from the bubble's leading edge for a
    /// `top` tail, from its top edge for a `leading` one.
    let tailCenter: CGFloat
    /// Where the finger lands: on the target, right of centre, so the hand covers its
    /// corner rather than its words.
    let fingerTip: CGPoint

    static let bubbleWidth: CGFloat = 400
    static let gap: CGFloat = 20
    static let holeInset: CGFloat = 8
    static let tailLength: CGFloat = 14
    static let tailWidth: CGFloat = 28
    static let estimatedBubbleHeight: CGFloat = 160
    /// Less room than this beside the target and the bubble goes under it instead.
    static let minimumBesideWidth: CGFloat = 280

    static func place(target: CGRect, in size: CGSize, bubbleHeight: CGFloat) -> TourPlacement {
        let margin = Tokens.Layout.screenMargin
        let hole = target.insetBy(dx: -holeInset, dy: -holeInset)
        let fingerTip = CGPoint(x: target.minX + target.width * 0.62, y: target.midY + 6)
        let landscape = size.width > size.height
        let besideX = hole.maxX + gap
        let besideWidth = min(bubbleWidth, size.width - margin - besideX)
        if landscape, besideWidth >= minimumBesideWidth {
            let lowest = max(margin, size.height - margin - bubbleHeight)
            let y = min(max(target.midY - bubbleHeight / 2, margin), lowest)
            return TourPlacement(hole: hole,
                                 bubble: CGRect(x: besideX, y: y, width: besideWidth, height: bubbleHeight),
                                 tail: .leading,
                                 tailCenter: target.midY - y,
                                 fingerTip: fingerTip)
        }
        let width = min(bubbleWidth, size.width - margin * 2)
        let rightmost = max(margin, size.width - margin - width)
        let x = min(max(target.midX - width / 2, margin), rightmost)
        return TourPlacement(hole: hole,
                             bubble: CGRect(x: x, y: hole.maxY + gap, width: width, height: bubbleHeight),
                             tail: .top,
                             tailCenter: target.midX - x,
                             fingerTip: fingerTip)
    }
}

private struct BubbleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// The screen less a rounded hole — filled even-odd, it is the scrim with the target cut
/// out; as a content shape, it is what a tap on the scrim hits and a tap in the hole
/// falls through.
struct CutOutShape: Shape {
    let hole: CGRect
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(roundedRect: hole, cornerRadius: radius))
        return path
    }
}

/// A rounded card with a tail on one edge, the tail drawn inside the frame's first
/// `tailLength` points on that side.
struct SpeechBubbleShape: Shape {
    let radius: CGFloat
    let tail: TourPlacement.Tail
    let tailCenter: CGFloat
    let tailLength: CGFloat
    let tailWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var body = rect
        switch tail {
        case .top:
            body.origin.y += tailLength
            body.size.height -= tailLength
        case .leading:
            body.origin.x += tailLength
            body.size.width -= tailLength
        }
        var path = Path(roundedRect: body, cornerRadius: radius)
        let half = tailWidth / 2
        var point = Path()
        switch tail {
        case .top:
            let c = min(max(tailCenter, body.minX + radius + half), body.maxX - radius - half)
            point.move(to: CGPoint(x: c - half, y: body.minY + 1))
            point.addLine(to: CGPoint(x: c, y: rect.minY))
            point.addLine(to: CGPoint(x: c + half, y: body.minY + 1))
        case .leading:
            let c = min(max(tailCenter, body.minY + radius + half), body.maxY - radius - half)
            point.move(to: CGPoint(x: body.minX + 1, y: c - half))
            point.addLine(to: CGPoint(x: rect.minX, y: c))
            point.addLine(to: CGPoint(x: body.minX + 1, y: c + half))
        }
        point.closeSubpath()
        path.addPath(point)
        return path
    }
}

/// A finger that taps the target, over and over, until the child's does: it comes in
/// from the lower right, presses — a ring spreads from the tip — lifts, and goes back for
/// another. Under Reduce Motion it rests on the target with the ring round the tip.
struct TutorialFinger: View {
    let tip: CGPoint
    let reduceMotion: Bool

    enum Phase: CaseIterable { case away, arrive, press, lift }

    /// The symbol's point size, the box the two symbols share at that size (the outline
    /// runs a point or two larger than the fill), and where the fingertip is in the box,
    /// as fractions of its width and height — measured from the rendered symbol.
    static let fontSize: CGFloat = 72
    static let box = CGSize(width: 74, height: 82)
    static let tipInBox = CGPoint(x: 0.215, y: 0.085)
    static let ringSize: CGFloat = 44
    static let restingOffset = CGSize(width: 48, height: 56)

    var body: some View {
        if reduceMotion {
            ZStack {
                ring(scale: 1, opacity: 0.9)
                hand(offset: .zero, scale: 1)
            }
        } else {
            PhaseAnimator(Phase.allCases) { phase in
                ZStack {
                    ring(scale: phase == .lift ? 1.8 : 0.6, opacity: phase == .press ? 0.9 : 0)
                    hand(offset: phase == .away ? Self.restingOffset : .zero,
                         scale: phase == .press ? 0.9 : 1)
                }
            } animation: { phase in
                switch phase {
                case .away:   return .easeInOut(duration: 0.6).delay(0.5)
                case .arrive: return .easeOut(duration: 0.5).delay(0.35)
                case .press:  return .easeOut(duration: 0.12)
                case .lift:   return .easeOut(duration: 0.55)
                }
            }
        }
    }

    private func ring(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(Tokens.Colour.action, lineWidth: 3)
            .frame(width: Self.ringSize, height: Self.ringSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(tip)
    }

    /// The hand, dark with a paper-white rim so it reads on the blue tile, the white one
    /// and the scrim alike, placed so its fingertip is on `tip`.
    private func hand(offset: CGSize, scale: CGFloat) -> some View {
        ZStack {
            Image(systemName: "hand.point.up.left.fill")
                .foregroundStyle(Tokens.Colour.textPrimary)
            Image(systemName: "hand.point.up.left")
                .foregroundStyle(Tokens.Colour.paperRaised)
        }
        .font(.system(size: Self.fontSize, weight: .regular))
        .frame(width: Self.box.width, height: Self.box.height)
        .scaleEffect(scale, anchor: UnitPoint(x: Self.tipInBox.x, y: Self.tipInBox.y))
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
        .position(x: tip.x + (0.5 - Self.tipInBox.x) * Self.box.width,
                  y: tip.y + (0.5 - Self.tipInBox.y) * Self.box.height)
        .offset(offset)
    }
}
