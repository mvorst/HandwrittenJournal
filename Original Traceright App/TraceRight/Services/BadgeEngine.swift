import Foundation

enum BadgeEngine {
    static func checkNewBadges(player: PlayerProgress, existingBadgeIDs: [String]) -> [BadgeDefinition] {
        var newBadges: [BadgeDefinition] = []
        for badge in BadgeDefinitions.all {
            if !existingBadgeIDs.contains(badge.id) && badge.check(player) {
                newBadges.append(badge)
            }
        }
        return newBadges
    }
}
