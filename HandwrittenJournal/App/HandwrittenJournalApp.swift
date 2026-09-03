import SwiftUI
import SwiftData

@main
struct HandwrittenJournalApp: App {

    init() {
        FontRegistry.registerBundledFonts()
        #if DEBUG
        // Before the first body: the welcome's steps are read when it appears, so a
        // harness reset that landed later would leave it showing the wrong ones.
        DemoData.settleWelcome(Onboarding.shared)
        #endif
        // Google Analytics (§10.5) — configured here because there is no AppDelegate;
        // this runs at the same point in launch. After the harness has settled the
        // welcome, so that whether the terms stand is what decides collection.
        // Sends nothing until a grown-up has agreed.
        Telemetry.start(onboarding: Onboarding.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, WritingSession.self])
    }
}

/// The welcome comes first, once per iPad (§4.0, v3.4). After it, choosing a person is
/// the deliberate first act of the app — the last-used profile is highlighted but never
/// auto-entered (§4.1).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var selected: UserProfile?
    @State private var onboarding = Onboarding.shared
    @State private var seeded = false

    var body: some View {
        Group {
            if onboarding.needsWelcome {
                WelcomeView(onboarding: onboarding)
                    .transition(.opacity)
            } else if let profile = selected {
                JournalHomeView(profile: profile, selected: $selected)
                    .transition(.opacity)
            } else {
                ProfilePickerView(selected: $selected)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: selected?.id)
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: onboarding.needsWelcome)
        .onChange(of: selected?.id) {
            if let profile = selected {
                Haptics.configure(enabled: profile.hapticsEnabled)
                Voice.configure(enabled: profile.soundEnabled)
            } else {
                Voice.configure(enabled: false)
            }
        }
        .task {
            #if DEBUG
            guard !seeded else { return }
            seeded = true
            DemoData.seedIfNeeded(context)
            DemoData.applyRequestedOrientation()
            DemoData.dumpStrokesIfRequested()
            if DemoData.screen != nil, DemoData.screen != "welcome" {
                try? await Task.sleep(for: .milliseconds(120))
                let all = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
                selected = all.max { ($0.sessions?.count ?? 0) < ($1.sessions?.count ?? 0) } ?? all.first
            }
            #endif
        }
    }
}
