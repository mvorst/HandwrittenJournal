import SwiftUI

struct DashboardView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var gameState: GameStateViewModel
    @State private var showSettings: Bool = false

    private var player: PlayerProgress? {
        gameState.player
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top bar with settings
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Greeting
                Text("Hi, \(player?.firstName ?? "Friend")!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                // Streak
                if let streak = player?.currentStreak, streak > 0 {
                    StreakView(streak: streak)
                }

                // Level progress
                if let player = player {
                    LevelProgressView(
                        currentLevel: player.currentLevel,
                        totalStars: player.totalStars
                    )
                    .frame(maxWidth: 400)
                }

                // Start Writing button
                Button(action: { navigationState.currentScreen = .dictation }) {
                    Text("Start Writing")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppConstants.primaryAction)
                                .shadow(color: AppConstants.primaryAction.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .padding(.vertical, 8)

                // Points
                if let points = player?.totalPoints {
                    Text("Total Points: \(points.formatted())")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Badges
                if let badgeIDs = player?.earnedBadgeIDs {
                    BadgeShowcaseView(earnedBadgeIDs: badgeIDs)
                }

                Spacer().frame(height: 40)
            }
        }
        .appBackground()
        .sheet(isPresented: $showSettings) {
            if let player = player {
                SettingsView(player: player, gameState: gameState)
            }
        }
    }
}
