import SwiftUI

/// Frames 55–59 — the welcome (v3.4, v3.6). Shown once per iPad, before the Profile
/// Picker: a grown-up agrees to the terms of use and the privacy policy, says whether
/// the iPad should talk, then hands it over for the child to trace a letter with the
/// Apple Pencil. The traced letter leads straight into *Add someone*.
///
/// The steps come from `Onboarding.stepsDue`, so a change to the terms brings back the
/// agreement alone, and the pencil check stays until an Apple Pencil has traced the
/// letter: *I don't have an Apple Pencil* opens a page that says why the app needs one
/// (frame 59), and *Skip for now* there lets this launch through with the check owed
/// again at the next. Both orientations: the column keeps the page's width, centred.
struct WelcomeView: View {
    let onboarding: Onboarding
    @Environment(\.openURL) private var openURL

    @State private var steps: [WelcomeStep] = []
    @State private var index = 0
    @State private var controller = PracticeController()
    @State private var pencilSeen = false
    @State private var fingerSeen = false
    /// Frame 59 — *You'll need an Apple Pencil*, shown in place of the letter.
    @State private var showingWhyPencil = false
    /// The pencil check's narration has been said (v3.7).
    @State private var introSaid = false

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
                    // The grown-up's page again: it scrolls like the first two.
                    case .pencil where showingWhyPencil:
                        scrolling(layout) { whyPencilStep }
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
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: showingWhyPencil)
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

    /// Back on every step but the first — and on the why-a-pencil page, where it
    /// returns to the letter — and one dot per step owed.
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
                if index > 0 || showingWhyPencil {
                    TextButton(title: "Back") { goBack() }
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
        }
        .frame(height: Tokens.Layout.toolbarHeight)
        .padding(.top, Tokens.Space.s2)
    }

    private func goBack() {
        if showingWhyPencil {
            showingWhyPencil = false
        } else {
            index -= 1
        }
    }

    private func well(_ systemImage: String) -> some View {
        ZStack {
            Circle().fill(Tokens.Colour.paperSunk).frame(width: 176, height: 176)
            Image(systemName: systemImage)
                .font(.system(size: 84, weight: .medium))
                .foregroundStyle(Tokens.Colour.action)
        }
    }

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
            .multilineTextAlignment(.center)
    }

    private func body(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 706)
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 706)
    }

    private func note(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
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
        .onAppear { sayIntro() }
    }

    /// The child's step is narrated once, if the grown-up chose a voice: the arrows, the
    /// letter and the pencil, said as the sheet appears (§4.12, v3.7). Coming back from
    /// frame 59 does not repeat it.
    private func sayIntro() {
        guard !introSaid, onboarding.voiceFeedbackDefault else { return }
        introSaid = true
        Voice.say(.pencilIntro, always: true)
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
                finishCheck()
            }
            .padding(.top, Tokens.Space.s5)
            TextButton(title: "I don't have an Apple Pencil") { explainPencil() }
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

    /// An Apple Pencil traced the letter — the welcome is settled for good.
    private func finishCheck() {
        Haptics.tap()
        Voice.stop()
        onboarding.recordPencilCheck(.pencil)
        onboarding.finish()
        Telemetry.log(.welcomeFinished(pencil: .pencil, voice: onboarding.voiceFeedbackDefault))
        reloadIfStillOwed()
    }

    // MARK: - Frame 59 — you'll need an Apple Pencil

    /// *I don't have an Apple Pencil* used to carry straight on (v3.4). Now it comes
    /// here first: this is a handwriting app, so the page says why the pencil is the
    /// point and helps find the right one. *Back to the letter* returns to the check;
    /// *Skip for now* lets this launch through — the check is back the next time the
    /// app opens, until a pencil traces the letter.
    private var whyPencilStep: some View {
        VStack(spacing: 0) {
            well("applepencil.and.scribble")
                .padding(.top, Tokens.Space.s6)
            title("You'll need an Apple Pencil")
                .padding(.top, Tokens.Space.s6)
            body("This is a handwriting app. Your child writes with a pencil in their hand, just as they do on paper — the grip, the pressure, the hand resting on the page, every letter formed stroke by stroke. That is what the app teaches and what it grades, so it doesn't start without one.")
                .padding(.top, Tokens.Space.s3)
            VStack(spacing: Tokens.Space.s3) {
                note("hand.raised.slash", "A finger isn't handwriting. Dragging a fingertip builds none of the habits a pencil does — how to hold it, how hard to press, where the hand rests — so the app would be practising the wrong thing.")
                note("pencil.tip.crop.circle", "The page is graded stroke by stroke — where the ink went, in which direction, in what order. A fingertip is wider than the strokes it would trace, and the scores would mean nothing.")
                note("applepencil", "Any Apple Pencil that pairs with this iPad will do.")
            }
            .padding(.top, Tokens.Space.s6)
            LinkRow(title: "Which Apple Pencil fits this iPad?") { openURL(Onboarding.pencilCompatibilityURL) }
                .padding(.top, Tokens.Space.s3)
            PrimaryButton(title: "Back to the letter", systemImage: "pencil.line") {
                Haptics.tap()
                showingWhyPencil = false
            }
            .padding(.top, Tokens.Space.s7)
            TextButton(title: "Skip for now") { skipCheck() }
                .padding(.top, Tokens.Space.s3)
            caption("Skipping lets you set up today. The letter will be back the next time the app opens, until it has seen an Apple Pencil.")
                .padding(.top, Tokens.Space.s3)
        }
    }

    private func explainPencil() {
        Haptics.tap()
        Voice.stop()
        showingWhyPencil = true
        Telemetry.screen(.welcomeNoPencil)
    }

    /// *Skip for now* — through for this launch only (§4.0, v3.6).
    private func skipCheck() {
        Haptics.tap()
        Voice.stop()
        onboarding.skipPencilCheck()
        onboarding.finish()
        Telemetry.log(.welcomeFinished(pencil: .skipped, voice: onboarding.voiceFeedbackDefault))
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
/// and 34) and Apple's pencil table (frame 59). `Row / Setting` with the label in
/// `action` and `arrow.up.right.square` trailing.
struct LinkRow: View {
    let title: LocalizedStringKey
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
