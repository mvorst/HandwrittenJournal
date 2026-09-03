import SwiftUI

/// Input level while recording. Decorative, but it tells a child the iPad is listening.
struct LevelMeter: View {
    let level: Double

    private static let barWidth: CGFloat = 5
    private static let gap: CGFloat = 5

    var body: some View {
        // As many bars as the width given holds (v3.3): the meter takes the room it is
        // offered — 280 pt in the portrait bar, the rail's width in landscape — rather
        // than a fixed count that overran both and pushed the rail off the screen.
        GeometryReader { geo in
            let barCount = max(1, Int((geo.size.width + Self.gap) / (Self.barWidth + Self.gap)))
            HStack(spacing: Self.gap) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = Double(i) / Double(barCount)
                    let envelope = sin(phase * .pi * 3.1) * 0.5 + 0.5
                    let height = max(4, 40 * (0.15 + envelope * 0.85 * max(0.12, level)))
                    Capsule()
                        .fill(phase > 0.82 ? Tokens.Colour.starOff : Tokens.Colour.action)
                        .frame(width: Self.barWidth, height: height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 40)
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

/// How far down the page the child has got. Replaces the sentence queue: with one
/// continuous document, progress is words written, not pieces completed.
struct WritingProgressBar: View {
    let written: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(written) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.Colour.paperSunk)
                    Capsule().fill(Tokens.Colour.action)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
            (total > 0 ? Text("\(written) of \(total) words") : Text(verbatim: " "))
                .font(.hjCaption)
                .foregroundStyle(Tokens.Colour.textSecondary)
        }
    }
}
