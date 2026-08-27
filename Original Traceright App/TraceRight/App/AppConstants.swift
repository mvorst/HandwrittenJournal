import SwiftUI

enum AppConstants {
    // MARK: - Colors
    static let insideGreen = Color(hex: 0x34C759)
    static let outsideRed = Color(hex: 0xFF3B30)
    static let guideTextColor = Color.black.opacity(0.8)
    static let baselineRuleColor = Color(hex: 0xE5E5EA)
    static let primaryAction = Color(hex: 0x007AFF)
    static let appBackground = Color(hex: 0xFAF8F5)
    static let starGold = Color(hex: 0xFFD700)
    static let starUnearned = Color(hex: 0xD1D1D6)

    // MARK: - CGColors for Core Graphics
    static let insideGreenCG = CGColor(red: 0x34/255.0, green: 0xC7/255.0, blue: 0x59/255.0, alpha: 1.0)
    static let outsideRedCG = CGColor(red: 0xFF/255.0, green: 0x3B/255.0, blue: 0x30/255.0, alpha: 1.0)

    // MARK: - Layout
    static let horizontalMargin: CGFloat = 40
    static let topBarHeight: CGFloat = 60
    static let bottomBarHeight: CGFloat = 50

    // MARK: - Text
    static let maxTextLength = 200
    static let maxNameLength = 20

    // MARK: - Stroke
    static let defaultStrokeWidth: CGFloat = 3.0
    static let minStrokeWidth: CGFloat = 1.5
    static let maxStrokeWidth: CGFloat = 5.0

    // MARK: - Animation
    static let revealFadeDuration: TimeInterval = 0.5
    static let starBounceDuration: TimeInterval = 0.3
    static let badgeSpringDuration: TimeInterval = 0.5
}
