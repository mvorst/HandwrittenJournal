import SwiftUI

enum Screen {
    case welcome
    case dashboard
    case dictation
    case tracing(text: String)
    case reveal(session: TracingSession)
    case results(session: TracingSession, scoreResult: ScoreResult)
}

class NavigationState: ObservableObject {
    @Published var currentScreen: Screen = .welcome
}
