import SwiftUI
import SwiftData

@main
struct TraceRightApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PlayerProgress.self, AttemptRecord.self])
    }
}
