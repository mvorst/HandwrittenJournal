import SwiftUI

struct StreakView: View {
    let streak: Int
    @State private var flicker: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)
                .scaleEffect(flicker ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: flicker)

            Text("\(streak)-Day Streak")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.orange)
        }
        .onAppear { flicker = true }
    }
}
