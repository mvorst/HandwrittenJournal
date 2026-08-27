import Foundation

enum RewardCategory: String, CaseIterable {
    case inkColor
    case paperTheme
    case soundPack
    case celebration
}

struct RewardDefinition: Identifiable {
    let id: String
    let name: String
    let category: RewardCategory
    let iconName: String
    let cost: Int
}

enum RewardDefinitions {
    static let all: [RewardDefinition] = [
        // Ink Colors
        RewardDefinition(id: "ink_blue", name: "Blue Ink", category: .inkColor, iconName: "paintbrush.fill", cost: 200),
        RewardDefinition(id: "ink_purple", name: "Purple Ink", category: .inkColor, iconName: "paintbrush.fill", cost: 300),
        RewardDefinition(id: "ink_gold", name: "Gold Ink", category: .inkColor, iconName: "paintbrush.fill", cost: 500),
        RewardDefinition(id: "ink_rainbow", name: "Rainbow Ink", category: .inkColor, iconName: "paintbrush.fill", cost: 1000),

        // Paper Themes
        RewardDefinition(id: "paper_graph", name: "Graph Paper", category: .paperTheme, iconName: "square.grid.3x3", cost: 300),
        RewardDefinition(id: "paper_dotted", name: "Dotted Grid", category: .paperTheme, iconName: "circle.grid.3x3", cost: 300),
        RewardDefinition(id: "paper_space", name: "Space Theme", category: .paperTheme, iconName: "sparkles", cost: 500),
        RewardDefinition(id: "paper_ocean", name: "Ocean Theme", category: .paperTheme, iconName: "water.waves", cost: 500),

        // Sound Packs
        RewardDefinition(id: "sound_chime", name: "Crystal Chimes", category: .soundPack, iconName: "bell.fill", cost: 400),
        RewardDefinition(id: "sound_nature", name: "Nature Sounds", category: .soundPack, iconName: "leaf.fill", cost: 400),

        // Celebration Animations
        RewardDefinition(id: "confetti_stars", name: "Star Confetti", category: .celebration, iconName: "star.fill", cost: 500),
        RewardDefinition(id: "confetti_hearts", name: "Heart Confetti", category: .celebration, iconName: "heart.fill", cost: 500),
    ]
}
