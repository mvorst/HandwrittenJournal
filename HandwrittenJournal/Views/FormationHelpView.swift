import SwiftUI

/// §8.1b — the remediation modal. A word was finished with letters drawn in the wrong
/// order: the word sits at the top with those letters in red, and one of them (picked at
/// random) is taught below with the practice sheet's own demo-then-trace loop. There is
/// no way out except through — tracing the letter correctly is what closes the modal,
/// and doing so lifts that letter's order discount.
struct FormationHelpOverlay: View {
    let help: WriteSessionViewModel.FormationHelp
    let setup: WritingSetup
    let allowFinger: Bool
    let colourBlind: Bool
    /// The letter was traced correctly — lift its discount and let the child go on.
    let onComplete: () -> Void

    @State private var practice = PracticeController()
    /// A wrong attempt is being cleared and the arrows replayed.
    @State private var retrying = false

    var body: some View {
        ZStack {
            // The page is out of reach until the lesson is done — including the chrome.
            Color.black.opacity(0.35).ignoresSafeArea()
            card
        }
        .onChange(of: practice.attemptFailures) { attemptFailed() }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Text("Let's practice \(letterName)!")
                .font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s6)

            wordDisplay
                .font(Font(setup.face.uiFont(size: 64) as CTFont))
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .padding(.top, Tokens.Space.s4)
                .padding(.horizontal, Tokens.Space.s6)

            Text(instruction)
                .font(.hjBody)
                .foregroundStyle(retrying ? wrongColour : Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Tokens.Space.s3)
                .padding(.horizontal, Tokens.Space.s6)

            PracticeSurface(setup: WritingSetup(face: setup.face, size: .default, mode: .trace),
                            allowFinger: allowFinger,
                            colourBlind: colourBlind,
                            sheetText: String(help.picked.character),
                            autoSelectSoleGlyph: true,
                            requireFullFormation: true,
                            controller: practice)
                .frame(height: 440)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                    .stroke(Tokens.Colour.divider, lineWidth: 1))
                .padding(.top, Tokens.Space.s4)
                .padding(.horizontal, Tokens.Space.s6)

            Group {
                if isDone {
                    PrimaryButton(title: "I did it — keep writing", systemImage: "checkmark",
                                  minWidth: 340, height: 64) { onComplete() }
                } else {
                    TextButton(title: "Watch again", systemImage: "arrow.counterclockwise") {
                        practice.startOverWithDemo()
                    }
                }
            }
            .padding(.top, Tokens.Space.s4)
            .padding(.bottom, Tokens.Space.s5)
        }
        .frame(maxWidth: 660)
        .background(Tokens.Colour.paperRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .hjShadow(Tokens.Elevation.modal)
        .padding(Tokens.Space.s6)
    }

    // MARK: - The word

    /// The word with its wrong-order letters in red. On success the letter that was
    /// just remediated turns green; the others stay red — their discount stands.
    private var wordDisplay: Text {
        var word = Text(verbatim: "")
        for (offset, character) in help.wordText.enumerated() {
            let colour: Color = help.wrongOffsets.contains(offset)
                ? (isDone && offset == help.picked.offset ? rightColour : wrongColour)
                : Tokens.Colour.textPrimary
            word = word + Text(verbatim: String(character)).foregroundColor(colour)
        }
        return word
    }

    // MARK: - State

    private var isDone: Bool {
        if case .traced = practice.phase { return true }
        return false
    }

    private var instruction: String {
        if retrying { return "Almost! Watch the arrows again — start where they start." }
        switch practice.phase {
        case .idle, .watching: return "The red letters were written in a different order.\nWatch how \(letterName) is written…"
        case .yourTurn:        return "Your turn — trace \(letterName) just like the arrows!"
        case .traced:          return "That's the way! \(help.wordText) is fixed."
        }
    }

    /// A wrong-order attempt. The canvas has already wiped the ink and started the
    /// arrows again — synchronously, at the pen-up that condemned it, so there is
    /// never doomed ink for the child's retrace to merge into. All that is left to
    /// do here is say so for a moment.
    private func attemptFailed() {
        guard !isDone, !retrying else { return }
        retrying = true
        Haptics.tap()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            retrying = false
        }
    }

    private var letterName: String {
        let character = help.picked.character
        if character.isNumber { return "the \(character)" }
        return character.isUppercase ? "big \(character)" : "little \(character)"
    }

    private var wrongColour: Color { colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside }
    private var rightColour: Color { colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside }
}
