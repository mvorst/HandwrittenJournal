import SwiftUI

/// Input level while recording. Decorative, but it tells a child the iPad is listening.
struct LevelMeter: View {
    let level: Double
    var barCount = 42

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<barCount, id: \.self) { i in
                let phase = Double(i) / Double(barCount)
                let envelope = sin(phase * .pi * 3.1) * 0.5 + 0.5
                let height = max(4, 40 * (0.15 + envelope * 0.85 * max(0.12, level)))
                Capsule()
                    .fill(phase > 0.82 ? Tokens.Colour.starOff : Tokens.Colour.action)
                    .frame(width: 5, height: height)
            }
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
            Text(total > 0 ? "\(written) of \(total) words" : " ")
                .font(.hjCaption)
                .foregroundStyle(Tokens.Colour.textSecondary)
        }
    }
}
