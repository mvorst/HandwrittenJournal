import Foundation

struct ScoreResult {
    let accuracy: Double
    let stars: Int
    let basePoints: Int
    let starBonus: Int
    let streakBonus: Int
    let levelBonus: Int
    let totalPoints: Int
    let message: String
    let newBadges: [BadgeDefinition]
}

enum ScoringEngine {
    static func calculate(session: TracingSession, streak: Int, playerName: String, existingBadgeIDs: [String], player: PlayerProgress) -> ScoreResult {
        let accuracy = session.overallAccuracy
        let accuracyPercent = accuracy * 100

        let stars: Int
        let message: String
        if accuracyPercent >= 90 {
            stars = 3
            message = "Perfect, \(playerName)!"
        } else if accuracyPercent >= 70 {
            stars = 2
            message = "Great job, \(playerName)!"
        } else if accuracyPercent >= 50 {
            stars = 1
            message = "Good try, \(playerName)!"
        } else {
            stars = 0
            message = "Keep going, \(playerName)!"
        }

        let actualBase = Int(round(accuracyPercent))
        let starBonus = stars * 25
        let streakBonus = streak * 5
        let levelBonus = session.level * 10
        let totalPoints = actualBase + starBonus + streakBonus + levelBonus

        // Check for new badges using a temporary updated player
        let tempPlayer = player
        let updatedAttempts = tempPlayer.totalAttempts + 1
        let updatedStars = tempPlayer.totalStars + stars
        let updatedThreeStars = tempPlayer.threeStarCount + (stars == 3 ? 1 : 0)
        let updatedPerfect = tempPlayer.perfectCount + (accuracyPercent >= 99.5 ? 1 : 0)
        let updatedLevel = LevelDefinitions.levelForStars(updatedStars)

        // Create a snapshot for badge checking
        let checkPlayer = PlayerProgress(firstName: playerName)
        checkPlayer.totalAttempts = updatedAttempts
        checkPlayer.totalStars = updatedStars
        checkPlayer.threeStarCount = updatedThreeStars
        checkPlayer.perfectCount = updatedPerfect
        checkPlayer.currentLevel = updatedLevel
        checkPlayer.currentStreak = streak

        let newBadges = BadgeEngine.checkNewBadges(player: checkPlayer, existingBadgeIDs: existingBadgeIDs)

        return ScoreResult(
            accuracy: accuracy,
            stars: stars,
            basePoints: actualBase,
            starBonus: starBonus,
            streakBonus: streakBonus,
            levelBonus: levelBonus,
            totalPoints: totalPoints,
            message: message,
            newBadges: newBadges
        )
    }
}
