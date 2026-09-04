import SwiftUI

/// Frame 60 — *How to trace a letter* (§4.11, v3.8). The practice sheet's tutorial: a
/// card over the sheet on a first visit, and behind the ? in the toolbar after that. It
/// teaches by doing — the practice sheet's own one-letter loop runs inside the card, and
/// the three steps light up as the letter goes through them, each said aloud in step with
/// what the sheet is doing (§4.12): the first line over the bare letter, the demo starting
/// only when it ends; the second as the blue dot lands and the arrows draw; the third when
/// the demo hands over. *Watch again* starts the arrows and the narration over together.
///
/// Closable three ways — *Skip*, the ✕, and *Let's practice* once the letter is traced —
/// but never by the scrim: a hand resting beside the card while the pencil traces must
/// not dismiss the lesson.
struct PracticeTutorialOverlay: View {
    let allowFinger: Bool
    let colourBlind: Bool
    let onClose: () -> Void

    @State private var controller = PracticeController()

    /// The tutorial's letter: a little *a*, whose bowl begins on the right — the one
    /// place a child does not expect to start — so the blue dot has something to say.
    static let letter = "a"
    /// The welcome's sheet (frames 57/58): 320 wide centres a lone letter at the sheet's
    /// 300 pt cap.
    private static let sheetWidth: CGFloat = 320
    private static let sheetHeight: CGFloat = 400

    private var step: PracticeTutorialStep { PracticeTutorialStep.current(phase: controller.phase) }

    /// How long the sheet shows the bare letter before its arrows start: the first line,
    /// plus a breath — or a short beat when the voice is off.
    static func introDelay(voiceOn: Bool, line: TimeInterval) -> TimeInterval {
        voiceOn && line > 0 ? line + 0.4 : 0.9
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Tokens.Colour.overlayScrim.ignoresSafeArea()
                    .accessibilityHidden(true)
                card(landscape: geo.size.width > geo.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
        .onAppear {
            Telemetry.screen(.practiceTutorial)
            Voice.say(.practiceHowWatch)
        }
        // The arrows wait for the first line: the letter sits bare while it is said, and
        // the demo starts as it ends.
        .task {
            let delay = Self.introDelay(voiceOn: Voice.enabled, line: Voice.duration(of: .practiceHowWatch))
            try? await Task.sleep(for: .seconds(delay))
            guard case .idle = controller.phase else { return }
            controller.startOverWithDemo()
        }
        .onDisappear { Voice.stop() }
        .onChange(of: controller.phase) { before, phase in
            switch phase {
            case .watching:
                // The dot has landed and the arrows are drawing — step two, as it happens.
                Voice.say(.practiceHowStart)
            case .yourTurn:
                // The demo handed over — step three.
                if case .watching = before { Voice.say(.practiceHowTrace) }
            case .traced:
                Voice.say(.practiceHowDone)
            case .idle:
                break
            }
        }
        .animation(Tokens.Motion.spring, value: step)
    }

    // MARK: - The card

    /// Portrait: the title, the steps, the sheet and the buttons in a column. Landscape:
    /// the words and the buttons beside the sheet, so the card fits an 834 pt height
    /// without the sheet shrinking (v3.3's rule).
    @ViewBuilder
    private func card(landscape: Bool) -> some View {
        Group {
            if landscape {
                HStack(alignment: .center, spacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: 0) {
                        title
                        steps.padding(.top, Tokens.Space.s5)
                        buttons.padding(.top, Tokens.Space.s6)
                    }
                    .frame(width: 400, alignment: .leading)
                    sheet
                }
                .padding(.horizontal, Tokens.Space.s6)
                .padding(.vertical, Tokens.Space.s6)
            } else {
                VStack(spacing: 0) {
                    title
                    steps.padding(.top, Tokens.Space.s5)
                    sheet.padding(.top, Tokens.Space.s5)
                    buttons.padding(.top, Tokens.Space.s5)
                }
                .padding(.horizontal, Tokens.Space.s6)
                .padding(.top, Tokens.Space.s6)
                .padding(.bottom, Tokens.Space.s5)
                .frame(width: 640)
            }
        }
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet)
            .fill(Tokens.Colour.paperRaised)
            .hjShadow(Tokens.Elevation.modal))
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tokens.Colour.textSecondary)
                    .frame(width: Tokens.Target.minimum, height: Tokens.Target.minimum)
                    .background(Tokens.Colour.paperSunk, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .padding(Tokens.Space.s4)
            .accessibilityLabel("Close")
        }
        .padding(Tokens.Space.s6)
    }

    private var title: some View {
        Text("How to trace a letter")
            .font(.hjTitle1)
            .foregroundStyle(Tokens.Colour.textPrimary)
            .multilineTextAlignment(.center)
    }

    /// The three steps, the current one in the action colour, done ones ticked.
    private var steps: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ForEach(PracticeTutorialStep.taught, id: \.self) { each in
                stepRow(each)
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func stepRow(_ each: PracticeTutorialStep) -> some View {
        let state = each.state(now: step)
        return HStack(alignment: .top, spacing: Tokens.Space.s4) {
            ZStack {
                Circle()
                    .fill(state == .waiting ? Tokens.Colour.paperSunk : Tokens.Colour.action)
                    .frame(width: 32, height: 32)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Tokens.Colour.textOnAction)
                } else {
                    Text(verbatim: "\(each.rawValue + 1)")
                        .font(.hjBodyEm)
                        .foregroundStyle(state == .waiting ? Tokens.Colour.textSecondary : Tokens.Colour.textOnAction)
                }
            }
            Text(each.text)
                .font(state == .current ? .hjHeadline : .hjBody)
                .foregroundStyle(state == .current ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, state == .current ? 1 : 4)
            Spacer(minLength: 0)
        }
    }

    /// Jua only — the one face the formations are fitted to (§4.11). The sheet's own
    /// good-ink bar, not the modal's full-formation one: the tutorial teaches the sheet.
    private var sheet: some View {
        PracticeSurface(setup: WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace),
                        allowFinger: allowFinger,
                        colourBlind: colourBlind,
                        sheetText: Self.letter,
                        centred: true,
                        controller: controller)
            .frame(width: Self.sheetWidth, height: Self.sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .strokeBorder(step == .done ? Tokens.Colour.success : Tokens.Colour.divider,
                              lineWidth: step == .done ? Tokens.Stroke.emphasis : Tokens.Stroke.hairline))
            .card(fill: Tokens.Colour.paper)
            .accessibilityLabel("A little letter \(Self.letter) to trace")
    }

    /// *Let's practice* once the letter is traced; until then *Watch again* and *Skip*.
    @ViewBuilder
    private var buttons: some View {
        if step == .done {
            PrimaryButton(title: "Let's practice", systemImage: "checkmark") { close() }
        } else {
            HStack(spacing: Tokens.Space.s6) {
                TextButton(title: "Watch again", systemImage: "arrow.counterclockwise") {
                    Haptics.tap()
                    // The narration starts over with the arrows: whatever was being said
                    // stops, and step two is said again as the dot lands.
                    Voice.stop()
                    controller.startOverWithDemo()
                }
                TextButton(title: "Skip", tint: Tokens.Colour.textSecondary) { close() }
            }
        }
    }

    private func close() {
        Haptics.tap()
        Voice.stop()
        onClose()
    }
}

/// The tutorial's steps, in the order the sheet's loop goes through them (frame 60).
/// Pure, so the tests can walk a letter through them without a card.
enum PracticeTutorialStep: Int, CaseIterable, Hashable {
    /// The demo is playing — touch a letter, watch.
    case watch
    /// The demo handed over — start at the blue dot.
    case start
    /// The pen is down — trace it.
    case trace
    /// Traced: the sheet is theirs.
    case done

    /// The steps the card lists; `done` is a state, not a step.
    static var taught: [PracticeTutorialStep] { [.watch, .start, .trace] }

    enum State { case done, current, waiting }

    /// Where a letter is in the loop: the bare letter before its demo is step one, the
    /// arrows drawing from the dot is step two, its turn is step three, and traced is done.
    static func current(phase: PracticePhase) -> PracticeTutorialStep {
        switch phase {
        case .idle:     return .watch
        case .watching: return .start
        case .yourTurn: return .trace
        case .traced:   return .done
        }
    }

    func state(now: PracticeTutorialStep) -> State {
        if rawValue < now.rawValue { return .done }
        return rawValue == now.rawValue ? .current : .waiting
    }

    var text: String {
        switch self {
        case .watch: return String(localized: "Touch a letter and watch how it's written.")
        case .start: return String(localized: "Start at the blue dot and follow the arrows.")
        case .trace: return String(localized: "Trace it with your Apple Pencil. Green ink is on the letter, red is off.")
        case .done:  return String(localized: "That's it! Pick any letter on the sheet.")
        }
    }
}
