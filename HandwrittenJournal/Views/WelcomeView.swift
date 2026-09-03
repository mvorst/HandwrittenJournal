import SwiftUI

/// Frames 55–58 — the welcome (v3.4). Shown once per iPad, before the Profile Picker:
/// a grown-up agrees to the terms of use and the privacy policy, says whether the iPad
/// should talk, then hands it over for the child to trace a letter with the Apple
/// Pencil. The traced letter leads straight into *Add someone*.
///
/// The steps come from `Onboarding.stepsDue`, so a change to the terms brings back the
/// agreement alone. Both orientations: the column keeps the page's width, centred.
struct WelcomeView: View {
    let onboarding: Onboarding
    @Environment(\.openURL) private var openURL

    @State private var steps: [WelcomeStep] = []
    @State private var index = 0
    @State private var controller = PracticeController()
    @State private var pencilSeen = false
    @State private var fingerSeen = false

    /// The one letter of the pencil check. Capital A: the first letter a child learns,
    /// three straight strokes that read clearly at any size.
    static let checkLetter = "A"
    /// The sheet sizes its letter to its width (§4.11, capped at 300 pt) and lays it
    /// out from the left inset, so a narrow sheet is what centres it.
    private static let sheetWidth: CGFloat = 320
    private static let sheetHeight: CGFloat = 400

    private var step: WelcomeStep? { steps.indices.contains(index) ? steps[index] : nil }

    var body: some View {
        GeometryReader { geo in
            let layout = ScreenLayout(geo)
            ZStack {
                Tokens.Colour.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    switch step {
                    case .terms:  scrolling(layout) { termsStep }
                    case .voice:  scrolling(layout) { voiceStep }
                    // Never in a scroll view: a one-finger drag on the letter would
                    // scroll instead of ink, and the sheet would never see it.
                    case .pencil: pencilStep(layout)
                    case nil:     EmptyView()
                    }
                }
            }
        }
        .onAppear {
            if steps.isEmpty { steps = onboarding.stepsDue }
            Telemetry.screen(.welcome)
        }
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: index)
    }

    // MARK: - Chrome

    /// The grown-up's steps scroll when the window is short (landscape); the column
    /// keeps the page's width. Bouncing only when there is something to scroll keeps
    /// the taps crisp.
    private func scrolling<Content: View>(_ layout: ScreenLayout, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(width: Tokens.Layout.contentWidth(in: layout.pageWidth))
                .frame(maxWidth: .infinity)
                .padding(.bottom, Tokens.Space.s8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Back on every step but the first, and one dot per step owed.
    private var header: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, _ in
                    Capsule()
                        .fill(i <= index ? Tokens.Colour.action : Tokens.Colour.starOff)
                        .frame(width: i == index ? 28 : 10, height: 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(index + 1) of \(steps.count)")
            HStack {
                if index > 0 {
                    TextButton(title: "Back") { index -= 1 }
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
        }
        .frame(height: Tokens.Layout.toolbarHeight)
        .padding(.top, Tokens.Space.s2)
    }

    private func well(_ systemImage: String) -> some View {
        ZStack {
            Circle().fill(Tokens.Colour.paperSunk).frame(width: 176, height: 176)
            Image(systemName: systemImage)
                .font(.system(size: 84, weight: .medium))
                .foregroundStyle(Tokens.Colour.action)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
            .multilineTextAlignment(.center)
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 706)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 706)
    }

    private func note(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Tokens.Colour.textSecondary)
                .frame(width: 26)
            Text(text).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sunkCard()
    }

    // MARK: - Frame 55 — a grown-up agrees

    private var termsStep: some View {
        VStack(spacing: 0) {
            well("checkmark.seal")
                .padding(.top, Tokens.Space.s6)
            title("A grown-up needs to agree")
                .padding(.top, Tokens.Space.s6)
            body("Handwritten Journal is made for children, so a parent, guardian or teacher agrees to the terms on their behalf. It takes a minute, and it only happens once.")
                .padding(.top, Tokens.Space.s3)
            VStack(spacing: 0) {
                LinkRow(title: "Terms of use") { openURL(Onboarding.termsURL) }
                LinkRow(title: "Privacy policy") { openURL(Onboarding.privacyURL) }
            }
            .padding(.top, Tokens.Space.s6)
            note("lock.fill", "There is no account, and what your child says and writes never leaves this iPad unless a grown-up shares a PDF. The privacy policy explains the anonymous crash reports and usage statistics.")
                .padding(.top, Tokens.Space.s5)
            PrimaryButton(title: "I agree", systemImage: "checkmark") {
                Haptics.tap()
                onboarding.acceptTerms()
                Telemetry.termsAccepted(onboarding)
                advance()
            }
            .padding(.top, Tokens.Space.s7)
            caption("Tapping I agree accepts the terms of use and the privacy policy for you and your child.")
                .padding(.top, Tokens.Space.s3)
        }
    }

    // MARK: - Frame 56 — voice feedback

    private var voiceStep: some View {
        VStack(spacing: 0) {
            well("speaker.wave.2.fill")
                .padding(.top, Tokens.Space.s6)
            title("Should the iPad talk?")
                .padding(.top, Tokens.Space.s6)
            body("With voice feedback on, the iPad says when it's your child's turn to write, names the letter to trace on the practice sheet and cheers a finished line. It never reads the journal aloud.")
                .padding(.top, Tokens.Space.s3)
            SecondaryButton(title: "Hear it", systemImage: "speaker.wave.2.fill") {
                Voice.say(.preview, always: true)
            }
            .padding(.top, Tokens.Space.s6)
            PrimaryButton(title: "Yes, talk to me", systemImage: "speaker.wave.2.fill") { chooseVoice(true) }
                .padding(.top, Tokens.Space.s7)
            TextButton(title: "No thanks, stay quiet") { chooseVoice(false) }
                .padding(.top, Tokens.Space.s3)
            caption("Every profile gets its own switch: Settings › Feedback › Voice feedback.")
                .padding(.top, Tokens.Space.s3)
        }
    }

    private func chooseVoice(_ on: Bool) {
        Haptics.tap()
        Voice.stop()
        onboarding.chooseVoiceFeedback(on)
        advance()
    }

    // MARK: - Frames 57 and 58 — trace a letter

    /// Jua only — the one face the formations are fitted to (§4.11). A finger is
    /// allowed to ink so that it can be recognised as a finger.
    private var sheetSetup: WritingSetup {
        WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
    }

    /// Portrait: the words, the sheet, the status and the buttons in a column. Landscape
    /// (v3.3's rule — nothing re-wraps, the sheet keeps its size): the words and the
    /// buttons in a column beside the sheet, so the whole step fits without scrolling.
    @ViewBuilder
    private func pencilStep(_ layout: ScreenLayout) -> some View {
        Group {
            if layout.isLandscape {
                HStack(alignment: .center, spacing: Tokens.Space.s7) {
                    VStack(spacing: 0) {
                        title("Let's check your Apple Pencil")
                        pencilBody.padding(.top, Tokens.Space.s3)
                        status.padding(.top, Tokens.Space.s6)
                        pencilButtons
                    }
                    .frame(width: 420)
                    letterSheet
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    title("Let's check your Apple Pencil")
                        .padding(.top, Tokens.Space.s6)
                    pencilBody.padding(.top, Tokens.Space.s3)
                    letterSheet.padding(.top, Tokens.Space.s6)
                    status.padding(.top, Tokens.Space.s5)
                    pencilButtons
                    Spacer(minLength: 0)
                }
                .frame(width: Tokens.Layout.contentWidth(in: layout.pageWidth))
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: controller.inkBegins) { inkBegan() }
    }

    private var pencilBody: some View {
        body("Hand the iPad to your writer. Watch the arrows, then trace the big \(Self.checkLetter) with the Apple Pencil.")
    }

    private var letterSheet: some View {
        PracticeSurface(setup: sheetSetup,
                        allowFinger: true,
                        colourBlind: false,
                        sheetText: Self.checkLetter,
                        autoSelectSoleGlyph: true,
                        controller: controller)
            .frame(width: Self.sheetWidth, height: Self.sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .strokeBorder(Tokens.Colour.divider, lineWidth: Tokens.Stroke.hairline))
            .card(fill: Tokens.Colour.paper)
            .accessibilityLabel("A big letter \(Self.checkLetter) to trace")
    }

    private var pencilButtons: some View {
        VStack(spacing: 0) {
            PrimaryButton(title: "Let's write", systemImage: "pencil.line", enabled: pencilSeen) {
                finishCheck(.pencil)
            }
            .padding(.top, Tokens.Space.s5)
            TextButton(title: "I don't have an Apple Pencil") { finishCheck(.noPencil) }
                .padding(.top, Tokens.Space.s3)
        }
    }

    /// What the sheet has seen: nothing yet, a pencil, or a finger.
    private var status: some View {
        HStack(spacing: Tokens.Space.s3) {
            if pencilSeen {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.Colour.success)
                Text("That's an Apple Pencil — you're ready!")
                    .foregroundStyle(Tokens.Colour.success)
            } else if fingerSeen {
                Image(systemName: "hand.point.up.left.fill").foregroundStyle(Tokens.Colour.starOn)
                Text("That was a finger. Try the Apple Pencil.")
                    .foregroundStyle(Tokens.Colour.textPrimary)
            } else {
                Text("Waiting for the pencil…")
                    .foregroundStyle(Tokens.Colour.textSecondary)
            }
        }
        .font(.hjHeadline)
        .frame(height: LineHeight.headline)
        .animation(Tokens.Motion.spring, value: pencilSeen)
        .animation(Tokens.Motion.spring, value: fingerSeen)
    }

    private func inkBegan() {
        guard let touch = controller.lastInkTouch else { return }
        if touch == .pencil {
            guard !pencilSeen else { return }
            pencilSeen = true
            Haptics.success()
            if onboarding.voiceFeedbackDefault { Voice.say(.pencilFound, always: true) }
        } else if !pencilSeen, !fingerSeen {
            fingerSeen = true
            Haptics.warning()
            if onboarding.voiceFeedbackDefault { Voice.say(.thatWasAFinger, always: true) }
        }
    }

    private func finishCheck(_ result: Onboarding.PencilCheck) {
        Haptics.tap()
        Voice.stop()
        onboarding.recordPencilCheck(result)
        onboarding.finish()
        Telemetry.log(.welcomeFinished(pencil: result, voice: onboarding.voiceFeedbackDefault))
        reloadIfStillOwed()
    }

    // MARK: - Steps

    private func advance() {
        if index + 1 < steps.count {
            index += 1
        } else {
            reloadIfStillOwed()
        }
        // Otherwise the last owed step is done and `Onboarding` no longer needs the
        // welcome; `RootView` swaps to the Profile Picker on its own.
    }

    /// The steps were read when the welcome appeared. If something is still owed after
    /// the last of them — the agreement was cleared underneath us — start again from
    /// what is owed now rather than sit on a finished step.
    private func reloadIfStillOwed() {
        guard onboarding.needsWelcome else { return }
        steps = onboarding.stepsDue
        index = 0
    }
}

/// A row that opens a page in Safari — the terms and the privacy policy (frames 55
/// and 34). `Row / Setting` with the label in `action` and `arrow.up.right.square`
/// trailing.
struct LinkRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s4) {
                Text(title).font(.hjBody).foregroundStyle(Tokens.Colour.action)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Tokens.Colour.action)
            }
            .frame(minHeight: 64)
            .padding(.horizontal, Tokens.Space.s4)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colour.divider).frame(height: 1).padding(.leading, Tokens.Space.s4)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Opens in Safari")
    }
}
