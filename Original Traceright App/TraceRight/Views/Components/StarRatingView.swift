import SwiftUI

struct StarRatingView: View {
    let stars: Int
    let maxStars: Int
    var animated: Bool = false
    @State private var animatedStars: [Bool] = []

    init(stars: Int, maxStars: Int = 3, animated: Bool = false) {
        self.stars = stars
        self.maxStars = maxStars
        self.animated = animated
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<maxStars, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundColor(index < stars ? AppConstants.starGold : AppConstants.starUnearned)
                    .scaleEffect(animated && index < animatedStars.count && animatedStars[index] ? 1.0 : (animated ? 0.3 : 1.0))
                    .animation(animated ? .spring(response: 0.4, dampingFraction: 0.5).delay(Double(index) * 0.2) : nil, value: animatedStars)
            }
        }
        .onAppear {
            if animated {
                animatedStars = Array(repeating: false, count: maxStars)
                for i in 0..<stars {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                        if i < animatedStars.count {
                            animatedStars[i] = true
                        }
                    }
                }
            }
        }
    }
}
