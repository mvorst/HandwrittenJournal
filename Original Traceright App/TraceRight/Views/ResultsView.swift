import SwiftUI
import SwiftData

struct ResultsView: View {
    let session: TracingSession
    let scoreResult: ScoreResult
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var gameState: GameStateViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showConfetti: Bool = false
    @State private var applied: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Message
                Text(scoreResult.message)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                // Stars
                StarRatingView(stars: scoreResult.stars, animated: true)

                Text("\(scoreResult.stars) out of 3")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                // Accuracy ring
                ProgressRingView(progress: scoreResult.accuracy, label: "Accuracy")

                // Points breakdown
                VStack(spacing: 8) {
                    Text("+ \(scoreResult.totalPoints) points earned")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppConstants.primaryAction)

                    if scoreResult.totalPoints > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            pointRow("Base", scoreResult.basePoints)
                            pointRow("Star bonus", scoreResult.starBonus)
                            pointRow("Streak bonus", scoreResult.streakBonus)
                            pointRow("Level bonus", scoreResult.levelBonus)
                        }
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                }

                // New badges
                if !scoreResult.newBadges.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(scoreResult.newBadges) { badge in
                            HStack(spacing: 12) {
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 28))
                                    .foregroundColor(AppConstants.primaryAction)
                                VStack(alignment: .leading) {
                                    Text("NEW BADGE")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(AppConstants.starGold)
                                    Text(badge.name)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppConstants.starGold.opacity(0.1))
                            )
                        }
                    }
                }

                // Level up notification
                if gameState.justLeveledUp {
                    VStack(spacing: 8) {
                        Text("LEVEL UP!")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppConstants.starGold)
                        Text("Level \(gameState.player?.currentLevel ?? 1)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppConstants.starGold.opacity(0.15))
                    )
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button(action: tryAgain) {
                        Text("Try Again")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(AppConstants.primaryAction)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppConstants.primaryAction, lineWidth: 2)
                            )
                    }

                    Button(action: newSentence) {
                        Text("New Sentence")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppConstants.primaryAction)
                            )
                    }

                    Button(action: goHome) {
                        Text("Home")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 40)
        }
        .appBackground()
        .onAppear {
            applyResults()
        }
    }

    private func pointRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("+\(value)")
        }
        .frame(maxWidth: 200)
    }

    private func applyResults() {
        guard !applied else { return }
        applied = true

        gameState.applyScore(scoreResult, session: session)

        // Save attempt record
        let record = AttemptRecord(
            text: session.text,
            level: session.level,
            accuracy: scoreResult.accuracy,
            starsEarned: scoreResult.stars,
            pointsEarned: scoreResult.totalPoints
        )
        modelContext.insert(record)
    }

    private func tryAgain() {
        gameState.justLeveledUp = false
        navigationState.currentScreen = .tracing(text: session.text)
    }

    private func newSentence() {
        gameState.justLeveledUp = false
        navigationState.currentScreen = .dictation
    }

    private func goHome() {
        gameState.justLeveledUp = false
        navigationState.currentScreen = .dashboard
    }
}
