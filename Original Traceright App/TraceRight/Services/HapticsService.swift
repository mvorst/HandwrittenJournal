import UIKit

final class HapticsService {
    static let shared = HapticsService()

    private var lightGenerator: UIImpactFeedbackGenerator?
    private var lastHapticTime: TimeInterval = 0
    private let minInterval: TimeInterval = 0.05

    private init() {
        lightGenerator = UIImpactFeedbackGenerator(style: .light)
        lightGenerator?.prepare()
    }

    func outsideLetterHaptic() {
        let now = CACurrentMediaTime()
        guard now - lastHapticTime > minInterval else { return }
        lastHapticTime = now
        lightGenerator?.impactOccurred(intensity: 0.4)
    }

    func starEarnedHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func levelUpHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func badgeEarnedHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
