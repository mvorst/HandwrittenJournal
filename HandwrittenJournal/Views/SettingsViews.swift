import SwiftUI
import SwiftData

/// Frame 33. Everything per-profile, with the writing settings that replaced levels.
struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile
    @Binding var selected: UserProfile?

    @State private var showFontPicker = false
    @State private var showSizePicker = false
    @State private var showEditor = false
    @State private var showResetConfirm = false
    @State private var setup = WritingSetup.default

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("PROFILE") {
                        ProfileEditRow(profile: profile) { showEditor = true }
                    }

                    section("WRITING") {
                        Button { showFontPicker = true } label: {
                            SettingRow(title: "Font") { chevronValue(setup.face.label) }
                        }
                        Button { showSizePicker = true } label: {
                            SettingRow(title: "Font size") { chevronValue(setup.size.label) }
                        }
                        SettingRow(title: "Mode", subtitle: "Trace writing") {
                            Text("Trace").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                        }
                        SettingRow(title: "Guide lines") {
                            Toggle("", isOn: $profile.guideLinesEnabled).labelsHidden().tint(Tokens.Colour.action)
                        }
                        SettingRow(title: "Finger tracing allowed") {
                            Toggle("", isOn: $profile.allowFingerTracing).labelsHidden().tint(Tokens.Colour.action)
                        }
                        SettingRow(title: "Left-handed layout") {
                            Toggle("", isOn: $profile.isLeftHanded).labelsHidden().tint(Tokens.Colour.action)
                        }
                        // §13.6 (v3.3) — where the landscape rail goes. Auto follows handedness.
                        SettingRow(title: "Controls in landscape",
                                   subtitle: "Auto keeps them away from the writing hand") {
                            SegmentedControl(options: RailSide.allCases.map { (value: $0, label: $0.label) },
                                             selection: $profile.railSide, height: 44)
                                .frame(width: 270)
                        }
                    }

                    nudge

                    section("FEEDBACK") {
                        // v3.4 — `soundEnabled` is voice feedback: the iPad speaking at the
                        // moments a grown-up beside the child would (§4.12).
                        SettingRow(title: "Voice feedback",
                                   subtitle: "Says whose turn it is and cheers a finished line") {
                            Toggle("", isOn: $profile.soundEnabled).labelsHidden().tint(Tokens.Colour.action)
                        }
                        SettingRow(title: "Haptics") {
                            Toggle("", isOn: $profile.hapticsEnabled).labelsHidden().tint(Tokens.Colour.action)
                        }
                        SettingRow(title: "Colourblind ink scheme",
                                   subtitle: "Swaps green and red for blue and orange") {
                            Toggle("", isOn: $profile.colorBlindMode).labelsHidden().tint(Tokens.Colour.action)
                        }
                    }

                    section("DANGER ZONE") {
                        SecondaryButton(title: "Reset Progress", systemImage: "arrow.uturn.backward",
                                        minWidth: 300, destructive: true) { showResetConfirm = true }
                            .padding(.top, Tokens.Space.s3)
                        Text("Clears stars, points, badges and streaks. Journal entries are kept.\nGrown-ups only — the app does not check.")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s2)
                    }

                    TextButton(title: "Switch to someone else", systemImage: "arrow.triangle.2.circlepath") {
                        selected = nil
                        dismiss()
                    }
                    .padding(.top, Tokens.Space.s8)
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("\(profile.name)'s Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task { setup = profile.setup }
        .onChange(of: setup) { _, setup in
            // Compared with the profile, not the previous state: the first change is the
            // load from the profile itself, which is not a choice.
            profile.setup = setup
        }
        .onChange(of: profile.hapticsEnabled) { Haptics.configure(enabled: profile.hapticsEnabled) }
        .onChange(of: profile.soundEnabled) {
            Voice.configure(enabled: profile.soundEnabled)
            // Switched on, the voice introduces itself (§4.12, v3.7).
            if profile.soundEnabled { Voice.say(.voiceOn) }
        }
        .sheet(isPresented: $showFontPicker) { FontPickerView(setup: $setup).presentationDetents([.large]) }
        .sheet(isPresented: $showSizePicker) { SizePickerView(setup: $setup).presentationDetents([.large]) }
        .sheet(isPresented: $showEditor) {
            ProfileEditorView(profile: profile, isNew: false).presentationDetents([.large])
        }
        .confirmationDialog("Reset progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func chevronValue(_ value: String) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Text(value).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            Image(systemName: "chevron.right").foregroundStyle(Tokens.Colour.textSecondary)
        }
    }

    /// The one thing that replaces level progression — and it is addressed to a grown-up,
    /// never to the child, and it never changes anything by itself (§13.5).
    @ViewBuilder
    private var nudge: some View {
        if let suggestion = ProgressReport(profile: profile).sizeSuggestion {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: "lightbulb").foregroundStyle(Tokens.Colour.action)
                Text(suggestion).font(.hjCaption).foregroundStyle(Tokens.Colour.action)
            }
            .padding(Tokens.Space.s4)
            .sunkCard(radius: Tokens.Radius.chip)
            .padding(.top, Tokens.Space.s4)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        Text(title).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            .padding(.top, Tokens.Space.s7).padding(.bottom, Tokens.Space.s2)
        content()
    }

    private func reset() {
        profile.totalPoints = 0
        profile.totalStars = 0
        profile.currentStreak = 0
        profile.longestStreak = 0
        profile.earnedBadgeIDs = []
        profile.lastWroteOn = nil
    }
}

/// Frame 34.
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    let onboarding: Onboarding = .shared

    /// Reached from the picker, where no one is chosen yet, so this gear has to offer
    /// every profile rather than the one in use — the same editor the long press opens.
    @State private var editing: UserProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !profiles.isEmpty {
                        Text("PROFILES").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s6)
                        ForEach(profiles) { profile in
                            ProfileEditRow(profile: profile) { editing = profile }
                        }
                        Text("Touch and hold a profile on the chooser to reach the same editor.")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s3)
                    }

                    Text("ABOUT").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(.top, profiles.isEmpty ? Tokens.Space.s6 : Tokens.Space.s7)
                    SettingRow(title: "Version") {
                        Text(Self.version).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    }

                    // v3.4 — what the welcome asked a grown-up to agree to, kept reachable.
                    Text("LEGAL").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(.top, Tokens.Space.s7)
                    LinkRow(title: "Terms of use") { openURL(Onboarding.termsURL) }
                    LinkRow(title: "Privacy policy") { openURL(Onboarding.privacyURL) }
                    Text(agreedLine)
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(.top, Tokens.Space.s3)

                    Text("GOOD TO KNOW").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(.top, Tokens.Space.s7)
                    note("A profile PIN is a courtesy lock, not security. It keeps a brother or sister out of someone else's journal — it will not stop a determined grown-up, and nothing here is encrypted.")
                    note("Deleting a profile or resetting progress cannot be undone. Both are marked \u{201C}grown-ups only\u{201D} but the app does not check.")
                    note("The microphone feeds speech recognition on this iPad and nothing else. No audio is recorded or kept, and the words your child says never leave the iPad.")
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $editing) { profile in
            ProfileEditorView(profile: profile, isNew: false).presentationDetents([.large])
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            .padding(Tokens.Space.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sunkCard()
            .padding(.top, Tokens.Space.s3)
    }

    private var agreedLine: String {
        guard let date = onboarding.termsAcceptedAt, onboarding.hasAcceptedCurrentTerms else {
            return String(localized: "Not yet agreed on this iPad.")
        }
        return String(localized: "A grown-up agreed on \(date.formatted(date: .long, time: .omitted)).")
    }

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// The way into name, photo and PIN. Both gears carry one — the picker's for every
/// profile, the journal's for the one in use — so editing is never only a long press.
struct ProfileEditRow: View {
    let profile: UserProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s4) {
                AvatarView(image: profile.avatarImageData, initial: profile.initial, diameter: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                    Text("Name, photo and PIN").font(.hjCaptionSm).foregroundStyle(Tokens.Colour.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Tokens.Colour.textSecondary)
            }
            .frame(minHeight: 80)
            .padding(.horizontal, Tokens.Space.s4)
            // Without a shape the Spacer is dead space and only the words take the tap.
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colour.divider).frame(height: 1).padding(.leading, Tokens.Space.s4)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text("Edit \(profile.name): name, photo and PIN"))
    }
}
