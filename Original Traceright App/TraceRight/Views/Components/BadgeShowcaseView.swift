import SwiftUI

struct BadgeShowcaseView: View {
    let earnedBadgeIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Badges")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BadgeDefinitions.all) { badge in
                        BadgeView(
                            badge: badge,
                            isEarned: earnedBadgeIDs.contains(badge.id)
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}
