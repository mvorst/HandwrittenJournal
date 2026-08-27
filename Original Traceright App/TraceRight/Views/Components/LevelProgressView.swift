import SwiftUI

struct LevelProgressView: View {
    let currentLevel: Int
    let totalStars: Int

    private var nextLevelStars: Int? {
        LevelDefinitions.starsForNextLevel(currentLevel: currentLevel)
    }

    private var currentLevelStars: Int {
        LevelDefinitions.config(for: currentLevel).starsRequired
    }

    private var progress: Double {
        guard let next = nextLevelStars else { return 1.0 }
        let starsInLevel = next - currentLevelStars
        let earned = totalStars - currentLevelStars
        guard starsInLevel > 0 else { return 1.0 }
        return min(1.0, Double(earned) / Double(starsInLevel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LEVEL \(currentLevel)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppConstants.primaryAction)
                        .frame(width: geo.size.width * progress, height: 16)
                }
            }
            .frame(height: 16)

            if let next = nextLevelStars {
                Text("\(totalStars) / \(next) stars to Level \(currentLevel + 1)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                Text("Max level reached!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppConstants.starGold)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }
}
