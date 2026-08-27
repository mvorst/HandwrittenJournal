import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let label: String
    var size: CGFloat = 140
    var lineWidth: CGFloat = 12
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)

            // Center text
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: size * 0.1, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animatedProgress = progress
            }
        }
    }

    private var progressColor: Color {
        if progress >= 0.9 { return AppConstants.insideGreen }
        if progress >= 0.7 { return AppConstants.primaryAction }
        if progress >= 0.5 { return .orange }
        return AppConstants.outsideRed
    }
}
