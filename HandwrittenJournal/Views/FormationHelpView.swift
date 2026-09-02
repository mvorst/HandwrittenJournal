import SwiftUI

/// §8.1b — the remediation modal. A word was finished with letters drawn in the wrong
/// order: the word sits at the top with those letters in red, and each of them is taught
/// below with the practice sheet's own demo-then-trace loop. The lessons run as a
/// carousel — up to three letters visible at once, the current one live under the pen,
/// finished ones green with a check, waiting ones dimmed — that advances itself as each
/// letter is traced. There is no way out except through — tracing every letter correctly
/// is what closes the modal, and each correct trace lifts that letter's order discount.
struct FormationHelpOverlay: View {
    let help: WriteSessionViewModel.FormationHelp
    let setup: WritingSetup
    let allowFinger: Bool
    let colourBlind: Bool
    /// A lesson's letter was traced correctly — lift its occurrences' discounts.
    let onLessonComplete: (WriteSessionViewModel.FormationHelp.Lesson) -> Void
    /// Every lesson is done and the child tapped through — close the modal.
    let onComplete: () -> Void

    @State private var practice = PracticeController()
    /// A wrong attempt is being cleared and the arrows replayed.
    @State private var retrying = false
    /// The lesson under the pen; earlier ones are done, later ones wait.
    @State private var current = 0
    /// Lessons whose letter has been traced correctly.
    @State private var completed: Set<Int> = []
    /// The carousel's leading tile — moved only by the modal, never by a hand.
    @State private var viewportStart: Int?

    var body: some View {
        ZStack {
            // The page is out of reach until the lesson is done — including the chrome.
            Color.black.opacity(0.35).ignoresSafeArea()
            card
        }
        .onChange(of: practice.attemptFailures) { old, new in
            // Strictly-more: swapping in the next lesson's fresh controller resets the
            // count, and that reset is not a failure.
            if new > old { attemptFailed() }
        }
        .onChange(of: practice.phase) {
            if case .traced = practice.phase { lessonTraced() }
        }
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

            carousel
                .frame(height: 440)
                .padding(.top, Tokens.Space.s4)
                .padding(.horizontal, Tokens.Space.s6)

            Group {
                if allDone {
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
        .frame(maxWidth: help.lessons.count > 1 ? 920 : 660)
        // The shadow is the card's, not its contents' — cast from the composed view it
        // would ghost every label as a second, offset copy.
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.card)
            .fill(Tokens.Colour.paperRaised)
            .hjShadow(Tokens.Elevation.modal))
        .padding(Tokens.Space.s6)
    }

    // MARK: - The carousel

    /// One tile per lesson, up to three across; only the current tile is a live
    /// practice sheet. Scrolling is the modal's own — a finger stroke that happens to
    /// run sideways must ink the letter, never drag the strip.
    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                ForEach(help.lessons.indices, id: \.self) { index in
                    tile(index)
                        .containerRelativeFrame(.horizontal,
                                                count: min(3, help.lessons.count),
                                                span: 1, spacing: Tokens.Space.s3)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $viewportStart, anchor: .leading)
        .scrollDisabled(true)
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let lesson = help.lessons[index]
        Group {
            if index == current {
                // Stays live once traced too, so the child's green ink lingers for
                // the beat before the carousel moves on.
                PracticeSurface(setup: WritingSetup(face: setup.face, size: .default, mode: .trace),
                                allowFinger: allowFinger,
                                colourBlind: colourBlind,
                                sheetText: String(lesson.character),
                                autoSelectSoleGlyph: true,
                                requireFullFormation: true,
                                controller: practice)
                    .id(index)
            } else {
                preview(lesson, done: completed.contains(index))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
            .stroke(index == current && !allDone ? Tokens.Colour.action : Tokens.Colour.divider,
                    lineWidth: index == current && !allDone ? 2 : 1))
    }

    /// A finished or waiting letter: green with its check once traced, dimmed while
    /// its turn is still coming.
    private func preview(_ lesson: WriteSessionViewModel.FormationHelp.Lesson, done: Bool) -> some View {
        ZStack {
            Tokens.Colour.paper
            Text(verbatim: String(lesson.character))
                .font(Font(setup.face.uiFont(size: 160) as CTFont))
                .foregroundStyle(done ? rightColour : Tokens.Colour.spokenText)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(Tokens.Space.s4)
            if done {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(rightColour)
                        .padding(.bottom, Tokens.Space.s5)
                }
            }
        }
    }

    // MARK: - The word

    /// The word with its wrong-order letters in red. Each remediated letter turns
    /// green as its lesson is traced; the rest stay red until theirs is.
    private var wordDisplay: Text {
        var word = Text(verbatim: "")
        for (offset, character) in help.wordText.enumerated() {
            word = word + Text(verbatim: String(character)).foregroundColor(colour(forOffset: offset))
        }
        return word
    }

    private func colour(forOffset offset: Int) -> Color {
        guard help.wrongOffsets.contains(offset) else { return Tokens.Colour.textPrimary }
        let fixed = completed.contains { help.lessons[$0].offsets.contains(offset) }
        return fixed ? rightColour : wrongColour
    }

    // MARK: - State

    private var allDone: Bool { completed.count == help.lessons.count }

    private var instruction: String {
        if retrying { return "Almost! Watch the arrows again — start where they start." }
        if allDone { return "That's the way! \(help.wordText) is fixed." }
        switch practice.phase {
        case .idle, .watching:
            return current == 0
                ? "The red letters were written in a different order.\nWatch how \(letterName) is written…"
                : "Now watch how \(letterName) is written…"
        case .yourTurn: return "Your turn — trace \(letterName) just like the arrows!"
        case .traced:   return "That's the way! Next letter…"
        }
    }

    /// The current lesson's letter was traced correctly: lift its discounts at once,
    /// and after a beat — long enough to see the green — move the carousel on.
    private func lessonTraced() {
        guard !completed.contains(current) else { return }
        completed.insert(current)
        onLessonComplete(help.lessons[current])
        guard current + 1 < help.lessons.count else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeInOut(duration: 0.45)) {
                practice = PracticeController()
                current += 1
                // Keep the live tile mid-strip where the count allows: with three or
                // fewer lessons this is always 0 and the strip never moves.
                viewportStart = max(0, min(current - 1, help.lessons.count - 3))
            }
        }
    }

    /// A wrong-order attempt. The canvas has already wiped the ink and started the
    /// arrows again — synchronously, at the pen-up that condemned it, so there is
    /// never doomed ink for the child's retrace to merge into. All that is left to
    /// do here is say so for a moment.
    private func attemptFailed() {
        guard !completed.contains(current), !retrying else { return }
        retrying = true
        Haptics.tap()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            retrying = false
        }
    }

    private var letterName: String {
        let character = help.lessons[min(current, help.lessons.count - 1)].character
        if character.isNumber { return "the \(character)" }
        return character.isUppercase ? "big \(character)" : "little \(character)"
    }

    private var wrongColour: Color { colourBlind ? Tokens.Colour.inkOutsideCB : Tokens.Colour.inkOutside }
    private var rightColour: Color { colourBlind ? Tokens.Colour.inkInsideCB : Tokens.Colour.inkInside }
}
