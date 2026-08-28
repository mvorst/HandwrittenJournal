import SwiftUI
import SwiftData

@main
struct HandwrittenJournalApp: App {

    init() { FontRegistry.registerBundledFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, WritingSession.self])
    }
}

/// Choosing a person is the deliberate first act of the app — the last-used profile is
/// highlighted but never auto-entered (§4.1).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var selected: UserProfile?
    @State private var seeded = false

    var body: some View {
        Group {
            if let profile = selected {
                JournalHomeView(profile: profile, selected: $selected)
                    .transition(.opacity)
            } else {
                ProfilePickerView(selected: $selected)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: selected?.id)
        .onChange(of: selected?.id) {
            if let profile = selected { Haptics.configure(enabled: profile.hapticsEnabled) }
        }
        .task {
            #if DEBUG
            guard !seeded else { return }
            seeded = true
            DemoData.seedIfNeeded(context)
            if DemoData.screen != nil {
                try? await Task.sleep(for: .milliseconds(120))
                let all = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
                selected = all.max { ($0.sessions?.count ?? 0) < ($1.sessions?.count ?? 0) } ?? all.first
            }
            #endif
        }
    }
}
