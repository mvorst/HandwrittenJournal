import SwiftUI

/// Frame 49 — letter practice. A worksheet, not a journal page: touch a letter to watch
/// how it is written, trace it, move on. Nothing here is saved or graded — but a letter
/// that flips green earns points (§8.3, v3.1), the one thing the sheet keeps.
struct PracticeView: View {
    let profile: UserProfile
    @State private var controller = PracticeController()
    /// What the letter in hand just earned — shown in the footer until the next letter.
    @State private var lastAward = 0

    /// Jua only — the stroke-order guides are hand-fitted to its letterforms (§4.11).
    /// Only the face matters here: the sheet computes its own size, filling the screen
    /// with the largest type at which the widest row still fits.
    private var setup: WritingSetup {
        WritingSetup(face: .face(id: "jua"), size: .default, mode: .trace)
    }

    var body: some View {
        VStack(spacing: 0) {
            PracticeSurface(setup: setup,
                            allowFinger: profile.allowFingerTracing,
                            colourBlind: profile.colorBlindMode,
                            completed: profile.practiceLetters(),
                            controller: controller)
            footer
        }
        .background(Tokens.Colour.paper)
        .navigationTitle("Practice Letters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { todayPill }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!controller.hasInk)
                Button { controller.clear() } label: { Image(systemName: "trash") }
                    .disabled(!controller.hasInk)
            }
        }
        // §8.3 — the moment a letter flips green is the moment it earns. The ledger says
        // no to a letter that has already earned as much today, so retracing is free.
        .onChange(of: controller.phase) { _, phase in
            if case .traced(let char) = phase {
                lastAward = profile.awardPractice(character: char, followedOrder: controller.followedOrder)
            } else {
                lastAward = 0
            }
        }
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
            if lastAward > 0 {
                Text("+\(lastAward) \(lastAward == 1 ? "point" : "points")")
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
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: 72)
        .background(Tokens.Colour.paper)
        .overlay(alignment: .top) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
        .animation(Tokens.Motion.spring, value: lastAward)
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
            Text(today > 0 ? "+\(today) today" : "0 today")
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
        let done = profile.colorBlindMode ? "Blue" : "Green"
        return "\(done) letters are done for today. Orange ones earned 1 point — try them in the arrow order."
    }

    private var prompt: String {
        switch controller.phase {
        case .idle:                 return "Touch a letter to see how it's written"
        case .watching(let char):   return "Watch how you write \(display(char))…"
        case .yourTurn(let char):   return "Your turn — trace \(display(char))!"
        case .traced(let char):
            // §8.1a — traced, but not the way the arrows showed: nudge, don't scold.
            return controller.followedOrder
                ? "Nice \(display(char))! Pick another letter."
                : "Good \(display(char))! Try the strokes in the arrow order."
        }
    }

    private func display(_ char: Character) -> String {
        if char.isNumber { return "the \(char)" }
        return char.isUppercase ? "big \(char)" : "little \(char)"
    }
}
