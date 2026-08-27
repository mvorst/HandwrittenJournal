import SwiftUI
import SwiftData

@MainActor
final class GameStateViewModel: ObservableObject {
    @Published var player: PlayerProgress?
    @Published var currentLevelConfig: LevelConfig = LevelDefinitions.config(for: 1)
    @Published var justLeveledUp: Bool = false

    func loadPlayer(_ player: PlayerProgress) {
        self.player = player
        updateLevelConfig()
    }

    func updateLevelConfig() {
        guard let player = player else { return }
        currentLevelConfig = LevelDefinitions.config(for: player.currentLevel)
    }

    func updateStreak() {
        guard let player = player else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastPlayed = player.lastPlayedDate {
            let lastDay = calendar.startOfDay(for: lastPlayed)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Already played today, no streak change
            } else if daysBetween == 1 {
                player.currentStreak += 1
            } else {
                // Missed a day, reset streak
                player.currentStreak = 1
            }
        } else {
            player.currentStreak = 1
        }
        player.lastPlayedDate = Date()
    }

    func applyScore(_ result: ScoreResult, session: TracingSession) {
        guard let player = player else { return }

        let previousLevel = player.currentLevel

        player.totalStars += result.stars
        player.totalPoints += result.totalPoints
        player.totalAttempts += 1
        if result.stars == 3 {
            player.threeStarCount += 1
        }
        if result.accuracy >= 0.995 {
            player.perfectCount += 1
        }

        // Add new badges
        for badge in result.newBadges {
            if !player.earnedBadgeIDs.contains(badge.id) {
                player.earnedBadgeIDs.append(badge.id)
            }
        }

        // Check level advancement
        let newLevel = LevelDefinitions.levelForStars(player.totalStars)
        if newLevel > previousLevel {
            player.currentLevel = newLevel
            justLeveledUp = true
        }

        updateLevelConfig()
    }

    func resetProgress() {
        guard let player = player else { return }
        player.currentLevel = 1
        player.totalStars = 0
        player.totalPoints = 0
        player.currentStreak = 0
        player.lastPlayedDate = nil
        player.totalAttempts = 0
        player.threeStarCount = 0
        player.perfectCount = 0
        player.earnedBadgeIDs = []
        player.purchasedRewardIDs = []
        justLeveledUp = false
        updateLevelConfig()
    }
}
