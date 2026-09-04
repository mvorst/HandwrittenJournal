import SwiftUI

/// Frame 49 — letter practice. A worksheet, not a journal page: touch a letter to watch
/// how it is written, trace it, move on. Nothing here is saved or graded — but a letter
/// that flips green earns points (§8.3, v3.1), the one thing the sheet keeps. A first
/// visit opens *How to trace a letter* over the sheet (frame 60, v3.8); the ? in the
/// toolbar brings it back.
struct PracticeView: View {
    let profile: UserProfile
    @State private var controller = PracticeController()
    /// What the letter in hand just earned — shown in the footer until the next letter.
    @State private var lastAward = 0
    /// Frame 60 — the tutorial card is up.
    @State private var showingTutorial = false
    /// The letter the award in the footer belongs to — it stays up through that
    /// letter's replay and goes when another letter is chosen or the pen is back down.
    @State private var awardedChar: Character?

    /// Jua only — the stroke-order guides are hand-fitted to its letterforms (§4.11).
    /// Only the face matters here: the sheet computes its own size, filling the screen
    /// with the largest type at which the widest row still fits.
    private var setup: WritingSetup {
        WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = ScreenLayout(geo, railSide: profile.resolvedRailSide)
            // v3.3 — in landscape the sheet keeps its portrait width, so the letters keep
            // their size, and the prompt and the award move into the rail beside it.
            let stack = layout.isLandscape
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))
            stack {
                if layout.railOnLeft { rail(layout) }
                PracticeSurface(setup: setup,
                                allowFinger: profile.allowFingerTracing,
                                colourBlind: profile.colorBlindMode,
                                completed: profile.practiceLetters(),
                                controller: controller)
                    .frame(width: layout.isLandscape ? layout.pageWidth : nil)
                    .frame(maxHeight: .infinity)
                if !layout.isLandscape { footer }
                if layout.railOnRight { rail(layout) }
            }
        }
        .background(Tokens.Colour.paper)
        .navigationTitle("Practice Letters")
        .onAppear { Telemetry.screen(.practice) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { todayPill }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showTutorial() } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("How to trace a letter")
                Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!controller.hasInk)
                Button { controller.clear() } label: { Image(systemName: "trash") }
                    .disabled(!controller.hasInk)
            }
        }
        // Frame 60 — over the sheet and its chrome, in the family of the PIN pad. Owed
        // once per profile: the first visit opens it after the push has landed, so the
        // sheet is there beneath the card.
        .fullScreenCover(isPresented: $showingTutorial) {
            PracticeTutorialOverlay(allowFinger: profile.allowFingerTracing,
                                    colourBlind: profile.colorBlindMode) { finishTutorial() }
                .presentationBackground(.clear)
        }
        .task {
            guard !profile.practiceTutorialSeen else { return }
            try? await Task.sleep(for: .milliseconds(450))
            showTutorial()
        }
        // §8.3 — the moment a letter flips green is the moment it earns. The ledger says
        // no to a letter that has already earned as much today, so retracing is free.
        .onChange(of: controller.phase) { before, phase in
            switch phase {
            case .traced(let char):
                let followed = controller.followedOrder
                lastAward = profile.awardPractice(character: char, followedOrder: followed)
                awardedChar = char
                Telemetry.log(.practiceTraced(followedOrder: followed))
                Voice.say(.practiceTraced(char, followedOrder: followed))
                if !followed { replayAfterWrongOrder(char) }
            case .yourTurn(let char):
                if char != awardedChar { lastAward = 0 }
                // Said only when the demo hands over — a pen that is already writing
                // does not need telling (§4.12).
                if case .watching = before { Voice.say(.practiceYourTurn(char)) }
            case .watching(let char):
                if char != awardedChar { lastAward = 0 }
            case .idle:
                lastAward = 0
            }
        }
        // The pen is back down: the live % takes the footer over from the award. Keyed
        // on strokes begun, which the canvas reports at pen-down — `hasInk` only reaches
        // the controller at pen-up, in the same update as the award it would wipe.
        .onChange(of: controller.inkBegins) { lastAward = 0 }
    }

    /// A letter traced out of the arrow order (v3.8): the point is kept, the nudge is
    /// said, and after a beat — long enough to see the green — the ink is wiped and the
    /// arrows play again, so the letter is shown the right way before it is tried again.
    /// Nothing happens if the child has already moved on to another letter.
    private func replayAfterWrongOrder(_ char: Character) {
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard controller.phase == .traced(char), !controller.followedOrder else { return }
            controller.startOverWithDemo()
        }
    }

    private func showTutorial() {
        guard !showingTutorial else { return }
        Voice.stop()
        showingTutorial = true
    }

    /// Seen, however it closed — *Skip* included. The ? brings it back on request.
    private func finishTutorial() {
        profile.practiceTutorialSeen = true
        showingTutorial = false
    }

    private var footer: some View {
        HStack(spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt)
                    .font(.hjHeadline)
                    .foregroundStyle(Tokens.Colour.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let legend {
                    Text(legend)
                        .font(.hjCaption)
                        .foregroundStyle(Tokens.Colour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer()
            award
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: 72)
        .background(Tokens.Colour.paper)
        .overlay(alignment: .top) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
        .animation(Tokens.Motion.spring, value: lastAward)
    }

    /// The rail beside the sheet in landscape (v3.3): the prompt, the legend and the
    /// award, top to bottom, with a hairline against the sheet.
    private func rail(_ layout: ScreenLayout) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(prompt)
                .font(.hjHeadline)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let legend {
                Text(legend)
                    .font(.hjCaption)
                    .foregroundStyle(Tokens.Colour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            award.padding(.top, Tokens.Space.s2)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Layout.screenMargin)
        .frame(width: layout.railWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: layout.railOnLeft ? .trailing : .leading) {
            Rectangle().fill(Tokens.Colour.divider).frame(width: 1)
        }
        .animation(Tokens.Motion.spring, value: lastAward)
    }

    /// What the letter in hand just earned, or the live accuracy while it is being traced.
    @ViewBuilder
    private var award: some View {
        if lastAward > 0 {
            Text("+\(lastAward) points")   // "+1 point" via the catalog
                .font(.hjNumeralL)
                .foregroundStyle(Tokens.Colour.success)
                .contentTransition(.numericText())
                .transition(.opacity)
        } else if controller.hasInk {
            Text("\(controller.accuracyPercent)%")
                .font(.hjNumeralL)
                .foregroundStyle(Tokens.Colour.textSecondary)
                .contentTransition(.numericText())
        }
    }

    /// "+18 today" — what the sheet has earned so far today, in the toolbar where the
    /// child can watch it climb. The bar supplies its own capsule; the label must insist
    /// on its width or the bar squeezes the text away and leaves the sparkle alone.
    private var todayPill: some View {
        let today = profile.practicePoints()
        return HStack(spacing: Tokens.Space.s2) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(today > 0 ? Tokens.Colour.starOn : Tokens.Colour.starOff)
            (today > 0 ? Text("+\(today) today") : Text("0 today"))
                .font(.hjBodyEm)
                .foregroundStyle(today > 0 ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .fixedSize()
        .padding(.horizontal, Tokens.Space.s2)
        .animation(Tokens.Motion.spring, value: today)
        .accessibilityLabel("\(today) practice points today")
    }

    /// What the colours mean — shown while nothing is selected, once there is
    /// something to explain.
    private var legend: String? {
        guard case .idle = controller.phase, !profile.practiceLetters().isEmpty else { return nil }
        let done = profile.colorBlindMode ? String(localized: "Blue") : String(localized: "Green")
        return String(localized: "\(done) letters are done for today. Orange ones earned 1 point — try them in the arrow order.")
    }

    private var prompt: String {
        switch controller.phase {
        case .idle:                 return String(localized: "Touch a letter to see how it's written")
        case .watching(let char):   return String(localized: "Watch how you write \(Voice.letterName(char))…")
        case .yourTurn(let char):   return String(localized: "Your turn — trace \(Voice.letterName(char))!")
        case .traced(let char):
            // §8.1a — traced, but not the way the arrows showed: nudge, don't scold.
            if controller.followedOrder, char.isNumber { return String(localized: "Nice \(String(char)). Try another one.") }
            return controller.followedOrder
                ? String(localized: "Nice \(Voice.letterName(char))! Pick another letter.")
                : String(localized: "Good \(Voice.letterName(char))! Try the strokes in the arrow order.")
        }
    }
}
