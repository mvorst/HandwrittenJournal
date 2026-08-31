import SwiftUI

/// Frame 44 — letter practice. A worksheet, not a journal page: touch a letter to watch
/// how it is written, trace it, move on. Nothing is scored, saved, or counted.
struct PracticeView: View {
    let profile: UserProfile
    @State private var controller = PracticeController()

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
                            controller: controller)
            footer
        }
        .background(Tokens.Colour.paper)
        .navigationTitle("Practice Letters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!controller.hasInk)
                Button { controller.clear() } label: { Image(systemName: "trash") }
                    .disabled(!controller.hasInk)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Tokens.Space.s4) {
            Text(prompt)
                .font(.hjHeadline)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if controller.hasInk {
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
