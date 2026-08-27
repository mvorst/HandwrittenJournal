import SwiftUI

struct RevealView: View {
    let session: TracingSession
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var gameState: GameStateViewModel
    @State private var guideAlpha: CGFloat = 1.0
    @State private var showScoreButton: Bool = false
    @StateObject private var viewModel: TracingViewModel

    init(session: TracingSession, navigationState: NavigationState, gameState: GameStateViewModel) {
        self.session = session
        self.navigationState = navigationState
        self.gameState = gameState
        let vm = TracingViewModel(text: session.text, level: session.level)
        vm.session = session
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Writing")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Canvas showing strokes with fading guide text
            TracingCanvasRepresentable(
                viewModel: viewModel,
                guideAlpha: guideAlpha,
                showGuideLines: false,
                hapticsEnabled: false
            )
            .allowsHitTesting(false) // Disable input during reveal

            // Bottom area
            if showScoreButton {
                Button(action: scoreAndNavigate) {
                    Text("See My Score")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 240, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(AppConstants.primaryAction))
                }
                .padding(.vertical, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .appBackground()
        .onAppear {
            // Animate guide text fade
            withAnimation(.easeInOut(duration: AppConstants.revealFadeDuration)) {
                guideAlpha = 0
            }
            // Show score button after fade
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.revealFadeDuration + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showScoreButton = true
                }
            }
        }
    }

    private func scoreAndNavigate() {
        guard let player = gameState.player else { return }

        gameState.updateStreak()

        let result = ScoringEngine.calculate(
            session: session,
            streak: player.currentStreak,
            playerName: player.firstName,
            existingBadgeIDs: player.earnedBadgeIDs,
            player: player
        )

        navigationState.currentScreen = .results(session: session, scoreResult: result)
    }
}
