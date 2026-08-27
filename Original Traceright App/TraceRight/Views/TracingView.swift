import SwiftUI

struct TracingView: View {
    let text: String
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var gameState: GameStateViewModel
    @StateObject private var viewModel: TracingViewModel

    init(text: String, navigationState: NavigationState, gameState: GameStateViewModel) {
        self.text = text
        self.navigationState = navigationState
        self.gameState = gameState
        let level = gameState.player?.currentLevel ?? 1
        _viewModel = StateObject(wrappedValue: TracingViewModel(text: text, level: level))
    }

    private var levelConfig: LevelConfig {
        viewModel.levelConfig
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("Level \(viewModel.session.level)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Spacer()

                // Star indicator (empty stars showing potential)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.system(size: 20))
                            .foregroundColor(AppConstants.starUnearned)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { viewModel.undoLastStroke() }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppConstants.primaryAction)

                    Button(action: { viewModel.clearAll() }) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)

                    Button(action: done) {
                        HStack {
                            Text("Done")
                            Image(systemName: "checkmark")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppConstants.primaryAction))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.shadow(color: .black.opacity(0.05), radius: 2, y: 2))

            // Canvas
            TracingCanvasRepresentable(
                viewModel: viewModel,
                showGuideLines: gameState.player?.guideLinesEnabled ?? true,
                hapticsEnabled: gameState.player?.hapticsEnabled ?? true
            )

            // Bottom bar
            HStack {
                Text("Live accuracy: \(Int(viewModel.liveAccuracy * 100))%")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                let estimatedPoints = Int(viewModel.liveAccuracy * 100) + (viewModel.session.level * 10)
                Text("Points: +\(estimatedPoints)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppConstants.primaryAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.shadow(color: .black.opacity(0.05), radius: 2, y: -2))
        }
        .appBackground()
    }

    private func done() {
        let session = viewModel.session
        navigationState.currentScreen = .reveal(session: session)
    }
}
