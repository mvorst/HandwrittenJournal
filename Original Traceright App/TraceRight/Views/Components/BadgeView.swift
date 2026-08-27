import SwiftUI

struct BadgeView: View {
    let badge: BadgeDefinition
    let isEarned: Bool
    var size: CGFloat = 60

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isEarned ? AppConstants.primaryAction.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: size, height: size)

                Image(systemName: badge.iconName)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(isEarned ? AppConstants.primaryAction : Color.gray.opacity(0.4))
            }

            Text(badge.name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isEarned ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: size + 10)
        }
    }
}
