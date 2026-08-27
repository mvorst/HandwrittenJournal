import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var players: [PlayerProgress]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var navigationState = NavigationState()
    @StateObject private var gameState = GameStateViewModel()

    private var currentPlayer: PlayerProgress? {
        players.first
    }

    var body: some View {
        Group {
            switch navigationState.currentScreen {
            case .welcome:
                WelcomeView(navigationState: navigationState)
            case .dashboard:
                DashboardView(navigationState: navigationState, gameState: gameState)
            case .dictation:
                DictationView(navigationState: navigationState)
            case .tracing(let text):
                TracingView(text: text, navigationState: navigationState, gameState: gameState)
            case .reveal(let session):
                RevealView(session: session, navigationState: navigationState, gameState: gameState)
            case .results(let session, let scoreResult):
                ResultsView(session: session, scoreResult: scoreResult, navigationState: navigationState, gameState: gameState)
            }
        }
        .environmentObject(navigationState)
        .environmentObject(gameState)
        .onAppear {
            if let player = currentPlayer {
                gameState.loadPlayer(player)
                navigationState.currentScreen = .dashboard
            } else {
                navigationState.currentScreen = .welcome
            }
        }
    }
}
