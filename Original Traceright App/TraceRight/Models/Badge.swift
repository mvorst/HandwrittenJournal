import Foundation

enum BadgeCategory: String, CaseIterable {
    case accuracy
    case streak
    case level
    case volume
}

struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let category: BadgeCategory
    let iconName: String
    let requirement: String
    let check: (PlayerProgress) -> Bool
}

enum BadgeDefinitions {
    static let all: [BadgeDefinition] = [
        // Accuracy Badges
        BadgeDefinition(id: "sharp_shooter", name: "Sharp Shooter", category: .accuracy, iconName: "target", requirement: "First 3-star rating") { $0.threeStarCount >= 1 },
        BadgeDefinition(id: "bullseye", name: "Bullseye", category: .accuracy, iconName: "scope", requirement: "Five 3-star ratings") { $0.threeStarCount >= 5 },
        BadgeDefinition(id: "laser_focus", name: "Laser Focus", category: .accuracy, iconName: "bolt.circle.fill", requirement: "Twenty 3-star ratings") { $0.threeStarCount >= 20 },
        BadgeDefinition(id: "perfectionist", name: "Perfectionist", category: .accuracy, iconName: "star.circle.fill", requirement: "100% accuracy on any attempt") { $0.perfectCount >= 1 },

        // Streak Badges
        BadgeDefinition(id: "on_fire", name: "On Fire", category: .streak, iconName: "flame.fill", requirement: "3-day streak") { $0.currentStreak >= 3 },
        BadgeDefinition(id: "unstoppable", name: "Unstoppable", category: .streak, iconName: "flame.circle.fill", requirement: "7-day streak") { $0.currentStreak >= 7 },
        BadgeDefinition(id: "dedicated", name: "Dedicated", category: .streak, iconName: "calendar.badge.checkmark", requirement: "14-day streak") { $0.currentStreak >= 14 },
        BadgeDefinition(id: "monthly_master", name: "Monthly Master", category: .streak, iconName: "crown.fill", requirement: "30-day streak") { $0.currentStreak >= 30 },

        // Level Badges
        BadgeDefinition(id: "getting_started", name: "Getting Started", category: .level, iconName: "pencil.circle.fill", requirement: "Reach level 2") { $0.currentLevel >= 2 },
        BadgeDefinition(id: "warming_up", name: "Warming Up", category: .level, iconName: "pencil.and.outline", requirement: "Reach level 4") { $0.currentLevel >= 4 },
        BadgeDefinition(id: "skilled_writer", name: "Skilled Writer", category: .level, iconName: "text.badge.star", requirement: "Reach level 6") { $0.currentLevel >= 6 },
        BadgeDefinition(id: "expert", name: "Expert", category: .level, iconName: "graduationcap.fill", requirement: "Reach level 8") { $0.currentLevel >= 8 },
        BadgeDefinition(id: "handwriting_hero", name: "Handwriting Hero", category: .level, iconName: "trophy.fill", requirement: "Reach level 10") { $0.currentLevel >= 10 },

        // Volume Badges
        BadgeDefinition(id: "first_words", name: "First Words", category: .volume, iconName: "character.cursor.ibeam", requirement: "Complete 1 tracing") { $0.totalAttempts >= 1 },
        BadgeDefinition(id: "sentence_builder", name: "Sentence Builder", category: .volume, iconName: "text.justify.left", requirement: "Complete 25 tracings") { $0.totalAttempts >= 25 },
        BadgeDefinition(id: "paragraph_pro", name: "Paragraph Pro", category: .volume, iconName: "doc.text.fill", requirement: "Complete 100 tracings") { $0.totalAttempts >= 100 },
    ]

    static func badge(for id: String) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
}
