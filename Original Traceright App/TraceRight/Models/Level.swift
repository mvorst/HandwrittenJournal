import UIKit

struct LevelConfig {
    let level: Int
    let fontSize: CGFloat
    let fontWeight: UIFont.Weight
    let lineSpacing: CGFloat
    let description: String
    let starsRequired: Int
    let edgeTolerance: Int

    /// The guide text font — uses Jua if available, falls back to SF Pro Rounded.
    var font: UIFont {
        if let jua = UIFont(name: "Jua", size: fontSize) {
            return jua
        }
        // Fallback to SF Pro Rounded
        return UIFont.systemFont(ofSize: fontSize, weight: fontWeight).rounded()
    }
}

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

enum LevelDefinitions {
    static let all: [LevelConfig] = [
        LevelConfig(level: 1, fontSize: 96, fontWeight: .black, lineSpacing: 120, description: "Extra large, boldest", starsRequired: 0, edgeTolerance: 4),
        LevelConfig(level: 2, fontSize: 84, fontWeight: .heavy, lineSpacing: 108, description: "Very large, heavy", starsRequired: 6, edgeTolerance: 3),
        LevelConfig(level: 3, fontSize: 72, fontWeight: .bold, lineSpacing: 96, description: "Large, bold", starsRequired: 15, edgeTolerance: 3),
        LevelConfig(level: 4, fontSize: 64, fontWeight: .semibold, lineSpacing: 84, description: "Large, semibold", starsRequired: 27, edgeTolerance: 2),
        LevelConfig(level: 5, fontSize: 56, fontWeight: .medium, lineSpacing: 72, description: "Medium-large", starsRequired: 42, edgeTolerance: 2),
        LevelConfig(level: 6, fontSize: 48, fontWeight: .regular, lineSpacing: 64, description: "Medium", starsRequired: 60, edgeTolerance: 1),
        LevelConfig(level: 7, fontSize: 42, fontWeight: .regular, lineSpacing: 56, description: "Medium-small", starsRequired: 82, edgeTolerance: 1),
        LevelConfig(level: 8, fontSize: 36, fontWeight: .light, lineSpacing: 48, description: "Small, light", starsRequired: 108, edgeTolerance: 0),
        LevelConfig(level: 9, fontSize: 30, fontWeight: .light, lineSpacing: 40, description: "Small, lighter", starsRequired: 138, edgeTolerance: 0),
        LevelConfig(level: 10, fontSize: 24, fontWeight: .thin, lineSpacing: 32, description: "Smallest, thinnest", starsRequired: 172, edgeTolerance: 0),
    ]

    static func config(for level: Int) -> LevelConfig {
        let clamped = max(1, min(10, level))
        return all[clamped - 1]
    }

    static func levelForStars(_ totalStars: Int) -> Int {
        for config in all.reversed() {
            if totalStars >= config.starsRequired {
                return config.level
            }
        }
        return 1
    }

    static func starsForNextLevel(currentLevel: Int) -> Int? {
        guard currentLevel < 10 else { return nil }
        return all[currentLevel].starsRequired
    }
}
