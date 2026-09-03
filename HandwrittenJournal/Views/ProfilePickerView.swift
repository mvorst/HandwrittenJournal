import SwiftUI
import SwiftData

/// Frames 1 and 2. Choosing a person is the deliberate first act of the app: the
/// last-used profile is highlighted but never auto-entered.
struct ProfilePickerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    @Binding var selected: UserProfile?
    @State private var editing: UserProfile?
    @State private var creatingNew = false
    @State private var pinFor: UserProfile?
    @State private var showAppSettings = false

    private let avatarSize: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let layout = ScreenLayout(geo)
            ZStack {
                Tokens.Colour.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        ToolbarIconButton(systemImage: "gearshape.fill") { showAppSettings = true }
                    }
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                    .padding(.top, Tokens.Space.s5)

                    Text("Handwritten Journal").font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                        .padding(.top, Tokens.Space.s6)

                    if profiles.isEmpty {
                        emptyState
                    } else {
                        Text("Who's writing today?").font(.hjHeadline).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s3)
                        grid(layout)
                        Text("Touch and hold a profile to edit it")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.bottom, Tokens.Space.s8)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .sheet(item: $editing) { profile in
            ProfileEditorView(profile: profile, isNew: false)
        }
        .sheet(isPresented: $creatingNew) {
            ProfileEditorView(profile: nil, isNew: true)
        }
        .sheet(item: $pinFor) { profile in
            PinPadView(profile: profile) { selected = profile }
        }
        .sheet(isPresented: $showAppSettings) { AppSettingsView().presentationDetents([.large]) }
        .onAppear { Telemetry.screen(.profilePicker) }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            AvatarView(diameter: avatarSize, isAddTile: true)
            Text("Nobody is here yet").font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s6)
            Text("Make a profile for each person who writes.\nEveryone gets their own journal, font and size.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Tokens.Space.s3)
            PrimaryButton(title: "Add someone", systemImage: "person.crop.circle.badge.plus") {
                creatingNew = true
            }
            .padding(.top, Tokens.Space.s7)
            Spacer()
        }
    }

    /// Two across in portrait; one row of four in landscape (v3.3), the same 96 pt apart.
    private func grid(_ layout: ScreenLayout) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 96), count: layout.isLandscape ? 4 : 2)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: Tokens.Space.s8) {
                ForEach(profiles) { profile in
                    tile(for: profile)
                }
                addTile
            }
            .padding(.horizontal, Tokens.Space.s9)
            .padding(.vertical, Tokens.Space.s8)
        }
    }

    private func tile(for profile: UserProfile) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            AvatarView(image: profile.avatarImageData,
                       initial: profile.initial,
                       diameter: avatarSize,
                       locked: profile.hasPIN)
                .overlay {
                    if profile.id == lastUsedID {
                        Circle().stroke(Tokens.Colour.action, lineWidth: Tokens.Stroke.selected)
                            .padding(-10)
                    }
                }
            Text(profile.name).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
            Text(profile.setup.shortSummary).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            if profile.hasPIN { pinFor = profile } else { selected = profile }
        }
        .onLongPressGesture { editing = profile }
    }

    private var addTile: some View {
        VStack(spacing: Tokens.Space.s3) {
            AvatarView(diameter: avatarSize, isAddTile: true)
            Text("Add someone").font(.hjHeadline).foregroundStyle(Tokens.Colour.textSecondary)
            Text(" ").font(.hjCaption)
        }
        .contentShape(Rectangle())
        .onTapGesture { creatingNew = true }
    }

    private var lastUsedID: UUID? {
        profiles.max { ($0.lastWroteOn ?? .distantPast) < ($1.lastWroteOn ?? .distantPast) }?.id
    }
}

/// Frames 3 and 4. A wrong PIN shakes the dots — no lockout, no error copy beyond
/// "Try again". This is a courtesy lock between siblings, not security (§10.3).
struct PinPadView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    let onSuccess: () -> Void

    @State private var entered = ""
    @State private var wrong = false
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            Tokens.Colour.overlayScrim.ignoresSafeArea()

            VStack(spacing: 0) {
                AvatarView(image: profile.avatarImageData,
                           initial: profile.initial,
                           diameter: 140,
                           locked: true)
                    .padding(.top, Tokens.Space.s7)
                Text(profile.name).font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                    .padding(.top, Tokens.Space.s5)
                (wrong ? Text("Try again") : Text("Enter your secret PIN"))
                    .font(.hjBody)
                    .foregroundStyle(wrong ? Tokens.Colour.danger : Tokens.Colour.textSecondary)
                    .padding(.top, Tokens.Space.s2)

                HStack(spacing: 24) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count && !wrong ? Tokens.Colour.action : .clear)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(wrong ? Tokens.Colour.danger : Tokens.Colour.starOff,
                                                     lineWidth: i < entered.count && !wrong ? 0 : 2))
                    }
                }
                .offset(x: shake)
                .padding(.top, Tokens.Space.s5)

                keypad.padding(.top, Tokens.Space.s6)

                TextButton(title: "Cancel") { dismiss() }
                    .padding(.vertical, Tokens.Space.s5)
            }
            .frame(width: 700)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet)
                .fill(Tokens.Colour.paperRaised)
                .hjShadow(Tokens.Elevation.modal))
        }
        .presentationBackground(.clear)
    }

    private var keypad: some View {
        VStack(spacing: 24) {
            ForEach([["1","2","3"], ["4","5","6"], ["7","8","9"], ["","0","del"]], id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        keyView(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 88, height: 88)
        } else if key == "del" {
            Button { back() } label: {
                Image(systemName: "xmark").font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Tokens.Colour.textPrimary)
                    .frame(width: 88, height: 88)
            }
        } else {
            Button { push(key) } label: {
                Text(key).font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                    .frame(width: 88, height: 88)
                    .background(Tokens.Colour.paperSunk, in: Circle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func push(_ digit: String) {
        guard entered.count < 4 else { return }
        wrong = false
        entered += digit
        Haptics.tap()
        if entered.count == 4 { check() }
    }

    private func back() {
        guard !entered.isEmpty else { return }
        entered.removeLast()
        wrong = false
    }

    private func check() {
        if profile.verify(pin: entered) {
            Haptics.success()
            onSuccess()
            dismiss()
        } else {
            Haptics.warning()
            wrong = true
            entered = ""
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) { shake = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = 0 }
        }
    }
}
