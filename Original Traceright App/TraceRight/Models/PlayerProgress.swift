import Foundation
import SwiftData

@Model
final class PlayerProgress {
    var firstName: String = ""
    var currentLevel: Int = 1
    var totalStars: Int = 0
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var lastPlayedDate: Date?
    var totalAttempts: Int = 0
    var threeStarCount: Int = 0
    var perfectCount: Int = 0
    var earnedBadgeIDs: [String] = []
    var purchasedRewardIDs: [String] = []
    var isLeftHanded: Bool = false
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var guideLinesEnabled: Bool = true

    init(firstName: String = "") {
        self.firstName = firstName
    }
}
