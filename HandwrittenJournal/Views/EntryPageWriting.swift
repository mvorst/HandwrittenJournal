import SwiftUI

// MARK: - Edit mode: the writing surface, and the results after it

extension EntryPageView {

    /// How much of the window the stage keeps clear while a take runs from an empty
    /// page, so the newest words never land under the stop (v3.2).
    static let stageInset: CGFloat = 300

    /// One continuous scrolling page carrying all three text tiers — written, in hand,
    /// spoken — with everything else layered over it: the stage (one mic, and the stop in
    /// its place while it listens), the your-turn callout, the cap banner, the word editor.
    func writingStage(_ layout: ScreenLayout) -> some View {
        // v3.3 — the footer's controls stand beside the page in landscape and below it
        // in portrait. One `AnyLayout` rather than two view trees, so the surface keeps
        // its identity through a rotation: rebuilt mid-write it would restore its
        // archive again and drop the stroke in hand.
        let stack = layout.isLandscape
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0))
        return ZStack {
            VStack(spacing: 0) {
                chrome { tools }

                stack {
                    if layout.railOnLeft { rail(layout) }
                    pageColumn(layout)
                    if !layout.isLandscape { bottomBar }
                    if layout.railOnRight { rail(layout) }
                }
            }

            // §8.1b — a word was finished with letters in the wrong order. The modal
            // sits over everything, chrome included, and only tracing every wrong
            // letter correctly closes it.
            if let help = model.formationHelp {
                FormationHelpOverlay(help: help,
                                     setup: model.setup,
                                     allowFinger: profile.allowFingerTracing,
                                     colourBlind: profile.colorBlindMode,
                                     onLessonComplete: { model.completeFormationLesson($0) },
                                     onComplete: { model.completeFormationHelp() })
                .id(help)
                .transition(.opacity)
            }
        }
    }

    /// The page and what lies over it. In landscape it keeps the width it has in
    /// portrait (§11.1) and, while a word is being fixed, carries the word editor
    /// beneath it — above the keyboard, where the row being fixed is.
    private func pageColumn(_ layout: ScreenLayout) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                TracingSurface(text: model.pageText,
                               setup: model.setup,
                               showGuideLines: profile.guideLinesEnabled,
                               showGuideText: true,
                               colourBlind: profile.colorBlindMode,
                               allowFinger: profile.allowFingerTracing,
                               isEraserActive: model.tool.erases,
                               isDictating: model.mic == .listening,
                               editingRange: model.editing?.range ?? model.replacing,
                               startAtWord: model.startWord,
                               restoring: model.restoredStrokes,
                               restoredWidth: model.restoredWidth,
                               restoredAttributed: model.restoredAttributed,
                               restoredRemediatedChars: model.restoredRemediated,
                               isDoodleActive: model.tool.drawsDoodles,
                               crayon: model.crayon,
                               isTextEditActive: model.tool.editsWords,
                               handlesOnRight: profile.isLeftHanded,
                               bottomInset: model.mic == .listening && model.listeningFromStage
                                   ? Self.stageInset : 0,
                               controller: $model.controller)
                    // Replacing a tracing means a page with no ink on it, and the surface
                    // restores its archive once, when it is made.
                    .id(model.surface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if stageIsUp { stage }
                if model.showYourTurn && model.mic == .idle { yourTurnCallout }
                if model.mic == .capped { capBanner }
            }
            if layout.isLandscape, model.editing != nil || model.appending != nil { wordEditor }
        }
        .frame(width: layout.isLandscape ? layout.pageWidth : nil)
    }

    /// Portrait: the bar under the page — the word editor, the listening bar, or the footer.
    @ViewBuilder
    private var bottomBar: some View {
        if model.editing != nil || model.appending != nil {
            wordEditor
        } else if model.mic == .listening {
            listeningBar
        } else {
            footer
        }
    }

    /// Landscape (v3.3): the rail beside the page, on the side of the free hand, with a
    /// hairline against the page. It holds what the footer holds, stacked.
    private func rail(_ layout: ScreenLayout) -> some View {
        Group {
            if model.mic == .listening { railListening } else { railFooter }
        }
        .frame(width: layout.railWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: layout.railOnLeft ? .trailing : .leading) {
            Rectangle().fill(Tokens.Colour.divider).frame(width: 1)
        }
    }

    /// The stage is up while the page has nothing on it, and while a take started there
    /// is running — the same button in the same spot, mic then stop (§11.13, v3.2).
    private var stageIsUp: Bool {
        (model.pageText.isEmpty && model.mic != .listening)
            || (model.mic == .listening && model.listeningFromStage)
    }

    // MARK: - Toolbar tools

    /// Pencil, crayon, ABC, eraser, undo, clear, then the entry menu. Pencil, crayon and
    /// ABC are the three things the pen can be, and the one in hand is filled, so the way
    /// back to writing is always in view. The row tools follow the layer the pen is on:
    /// ink on the selected row, or the doodles while the crayon is in hand.
    private var tools: some View {
        let crayon = model.tool.drawsDoodles
        let canEdit = !model.pageText.isEmpty && model.mic == .idle
        let hasInk = crayon ? model.controller.hasDoodles : model.controller.hasInk
        return HStack(spacing: Tokens.Space.s2) {
            ToolbarIconButton(systemImage: "pencil", enabled: canEdit, active: canEdit && model.tool == .pen) {
                model.pickPencil()
            }
            .accessibilityLabel("Pencil — write over the letters")
            ToolbarIconButton(systemImage: "scribble.variable", enabled: canEdit, active: crayon) {
                model.toggleCrayon()
            }
            .accessibilityLabel(crayon ? "Put the crayon down" : "Crayon — doodle anywhere, it never counts")
            ToolbarIconButton(systemImage: "textformat.abc", enabled: canEdit, active: model.tool.editsWords) {
                model.toggleWordsTool()
            }
            .accessibilityLabel("Fix a word, or add more words")
            ToolbarIconButton(systemImage: "eraser.fill", enabled: hasInk, active: model.tool.erases) {
                model.toggleEraser()
            }
            ToolbarIconButton(systemImage: "arrow.uturn.backward", enabled: hasInk) { model.controller.undo() }
            ToolbarIconButton(systemImage: "trash", enabled: hasInk) { model.controller.clear() }
            entryMenu
        }
    }

    // MARK: - Overlays

    /// Frames 20 and 21 (v3.2) — the one microphone. It stands low on the empty page,
    /// near the child's hands, and when tapped it turns into the stop without moving:
    /// wherever you tapped to start, you tap to stop. When the take ends it docks into the
    /// footer as the say-more mic.
    private var stage: some View {
        let listening = model.mic == .listening
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            if !listening {
                Text("Tell me about your day, \(profile.name)")
                    .font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Say as much as you like — up to five minutes.\nYour words land right here for you to write.")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Space.s3)
                    .padding(.bottom, Tokens.Space.s6)
            }
            stageButton(listening: listening)
            Text(listening ? "Tap when you're done talking" : "Tap to start talking")
                .font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s3)
            if listening {
                Text("Nothing goes in your journal until you write it.")
                    .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                    .padding(.top, Tokens.Space.s4)
            } else {
                typeBox.padding(.top, Tokens.Space.s4)
            }
        }
        .padding(.bottom, Tokens.Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// One slot for both states, so start and stop are the same spot.
    private func stageButton(listening: Bool) -> some View {
        Button {
            if listening {
                model.dictationEnded()
            } else {
                if model.mic == .capped { model.dismissCapBanner() }
                model.micTapped()
            }
        } label: {
            ZStack {
                if listening {
                    Circle().fill(Tokens.Colour.danger.opacity(0.14))
                        .frame(width: 232, height: 232)
                    Circle().stroke(Tokens.Colour.danger.opacity(0.35), lineWidth: 6)
                        .frame(width: 200, height: 200)
                        .scaleEffect(stagePulse ? 1.16 : 1)
                        .opacity(stagePulse ? 0 : 1)
                        .onAppear {
                            stagePulse = false
                            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                                stagePulse = true
                            }
                        }
                }
                Circle().fill(listening ? Tokens.Colour.danger : Tokens.Colour.action)
                    .frame(width: 176, height: 176)
                    .hjShadow(Tokens.Elevation.raised)
                if listening {
                    RoundedRectangle(cornerRadius: 12).fill(Tokens.Colour.textOnAction)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "mic.fill").font(.system(size: 76))
                        .foregroundStyle(Tokens.Colour.textOnAction)
                }
            }
            .frame(width: 232, height: 232)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(listening ? "Stop talking" : "Start talking")
    }

    /// Frame 24 (v3.2) — the first telling just landed on a page with no ink. The callout
    /// takes the spot the mic stood on and goes with the first stroke, or a tap.
    private var yourTurnCallout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.s4) {
                ZStack {
                    Circle().fill(Tokens.Colour.pencilYellow).frame(width: 64, height: 64)
                    Image(systemName: "pencil.line").font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Tokens.Colour.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your turn — write it!").font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                    Text("Write over the dark letters with your pencil. Tap the mic below to say more.")
                        .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                }
            }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: 660)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .fill(Tokens.Colour.paperRaised)
                .hjShadow(Tokens.Elevation.modal))
            .padding(.bottom, Tokens.Space.s6)
            .onTapGesture { model.showYourTurn = false }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// Frame 42 — the five-minute cap is a banner over the page, not a screen.
    private var capBanner: some View {
        HStack(spacing: Tokens.Space.s4) {
            ZStack {
                Circle().fill(Tokens.Colour.paperSunk).frame(width: 64, height: 64)
                Image(systemName: "mic.fill").font(.system(size: 28)).foregroundStyle(Tokens.Colour.starOff)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("That's a whole lot of story!").font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                Text("I stopped listening so we can start writing. The first line is ready for your pencil.")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: 660)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.card)
            .fill(Tokens.Colour.paperRaised)
            .hjShadow(Tokens.Elevation.modal))
        .padding(.top, Tokens.Space.s6)
        .onTapGesture { model.dismissCapBanner() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Footers

    /// The writing footer (v3.2): the say-more mic once the page has words, the readout
    /// or the crayons, the progress bar, the scroll chevron, and the one finish control.
    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                // The mic lives here once the page has words — saying more, any time. On
                // an empty page it stands on the stage instead; one mic, never two.
                if !model.pageText.isEmpty { micButton }

                if model.tool.drawsDoodles {
                    crayons
                } else {
                    readoutBlock.frame(width: 218, alignment: .leading)
                }

                if model.totalWords > 0 {
                    WritingProgressBar(written: model.wordsWritten, total: model.totalWords)
                }

                // The readout and the bar keep to the leading edge whatever is missing
                // (no mic on an empty page, no bar before any words); the controls trail.
                Spacer(minLength: 0)

                // Scrolling without a gesture, because two-finger scroll is a lot to ask
                // of a five-year-old holding a pencil.
                ToolbarIconButton(systemImage: "chevron.down") { model.controller.nextLines() }

                finishButton(compact: false)
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The rail's footer (v3.3): the same pieces top to bottom — the mic and the readout,
    /// the progress, and at the foot the scroll chevron beside the one finish control, a
    /// reach from the pencil rather than under the palm.
    private var railFooter: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                if !model.pageText.isEmpty { micButton }
                if model.tool.drawsDoodles {
                    crayons
                } else {
                    readoutBlock.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if model.totalWords > 0 {
                WritingProgressBar(written: model.wordsWritten, total: model.totalWords)
            }
            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.s4) {
                ToolbarIconButton(systemImage: "chevron.down") { model.controller.nextLines() }
                finishButton(compact: true)
            }
        }
        .padding(Tokens.Layout.screenMargin)
    }

    private var micButton: some View {
        Button {
            if model.mic == .capped { model.dismissCapBanner() } else { model.micTapped() }
        } label: {
            ZStack {
                Circle().fill(model.mic == .capped ? Tokens.Colour.paperSunk : Tokens.Colour.action)
                    .frame(width: 64, height: 64)
                Image(systemName: "mic.fill").font(.system(size: 28))
                    .foregroundStyle(model.mic == .capped ? Tokens.Colour.textSecondary : Tokens.Colour.textOnAction)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Say more")
    }

    private var readoutBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(readout)
                .font(.hjBody)
                .foregroundStyle(model.controller.wordsWritten > 0 ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
            Text(hint)
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .lineLimit(2)
        }
    }

    /// The one finish control: scores the page and shows the results. Back in the
    /// toolbar scores too, and just leaves. Compact in the rail, where it shares the
    /// width with the chevron.
    private func finishButton(compact: Bool) -> some View {
        PrimaryButton(title: "I'm finished", systemImage: "checkmark",
                      minWidth: compact ? 160 : 200, height: 64,
                      enabled: model.controller.pageHasInk,
                      fillsWidth: compact,
                      horizontalPadding: compact ? Tokens.Space.s4 : Tokens.Space.s6) {
            model.isEraserActive = false
            model.finishWriting()
        }
    }

    private var readout: String {
        if model.pageText.isEmpty { return "Nothing said yet" }
        return model.controller.wordsWritten > 0
            ? "So far: \(Int((model.controller.liveAccuracy * 100).rounded()))%"
            : "Nothing written yet"
    }

    /// The three crayons (§5.6), where the readout usually sits, while the crayon is in
    /// hand. Never a state, never a score.
    private var crayons: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            HStack(spacing: Tokens.Space.s3) {
                ForEach(Crayon.allCases) { crayon in
                    Button { model.pickCrayon(crayon.rawValue) } label: {
                        Circle().fill(crayon.colour)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Tokens.Colour.action,
                                                     lineWidth: model.crayon == crayon.rawValue ? Tokens.Stroke.selected : 0))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(crayon.name)
                    .accessibilityAddTraits(model.crayon == crayon.rawValue ? .isSelected : [])
                }
            }
            Text("Doodles never count — tap the pencil to write again")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .lineLimit(2)
        }
        .frame(width: 218, alignment: .leading)
    }

    /// The footer while recording (v3.2): the level and the clock, and — when the take
    /// was started from the footer mic — the stop, in the mic's own spot. A take started
    /// from the stage stops on the stage, and this bar has nothing to tap.
    private var listeningBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                if !model.listeningFromStage { stopButton }
                LevelMeter(level: model.speech.level)
                    .frame(width: 280, height: 40)
                clock
                Spacer()
                Text(listeningCaption)
                    .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 280, alignment: .trailing)
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The rail while a take runs (v3.3): the stop where the mic was, the clock beside
    /// it, the level across the rail, and the one line of reassurance.
    private var railListening: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                if !model.listeningFromStage { stopButton }
                clock
            }
            LevelMeter(level: model.speech.level)
                .frame(height: 40)
            Text(listeningCaption)
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Layout.screenMargin)
    }

    private var stopButton: some View {
        Button { model.dictationEnded() } label: {
            ZStack {
                Circle().fill(Tokens.Colour.danger).frame(width: 64, height: 64)
                RoundedRectangle(cornerRadius: 5).fill(Tokens.Colour.textOnAction)
                    .frame(width: 22, height: 22)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Stop talking")
    }

    private var clock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SpeechRecognitionService.formatted(model.speech.elapsed))
                .font(.hjNumeralL).monospacedDigit().foregroundStyle(Tokens.Colour.textPrimary)
            Text("of \(SpeechRecognitionService.formatted(SpeechRecognitionService.maximumDuration))")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
        }
    }

    private var listeningCaption: String {
        model.replacing == nil
            ? "Nothing goes in your journal until you write it."
            : "Say it again — the new words take the old ones' place."
    }

    /// §11.13 (v3.2) — the ABC tool's footer. With a word picked it fixes that word in
    /// place: type over it, or say it again. With nothing picked it adds words to the end
    /// of the page. Either way the tool goes down when the child is done.
    private var wordEditor: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            if model.editing == nil, model.hasSpokenText {
                Text("…or tap a word above to fix it")
                    .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                    .padding(.top, Tokens.Space.s2)
            }
            HStack(spacing: Tokens.Space.s4) {
                if let editing = model.editing {
                    Text(editing.isRun ? "Fix these words:" : "Fix the word:")
                        .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                        .fixedSize()
                    TextField("Word", text: Binding(
                        get: { model.editing?.draft ?? editing.draft },
                        set: { model.editing?.draft = $0 }
                    ))
                    .font(.hjHeadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(false)
                    .padding(.horizontal, Tokens.Space.s4).padding(.vertical, Tokens.Space.s3)
                    .sunkCard(radius: Tokens.Radius.button)
                    .frame(minWidth: 180, maxWidth: 320)
                    .focusedOnAppear()
                    .onSubmit { model.commitEdit() }
                    PrimaryButton(title: "Fix it", systemImage: "checkmark", minWidth: 130, height: 56,
                                  enabled: !(model.editing?.draft.isEmpty ?? true)) {
                        model.commitEdit()
                    }
                    SecondaryButton(title: "Say it again", systemImage: "mic.fill", minWidth: 170) {
                        model.speakOverSelection()
                    }
                } else {
                    Text("Add words:")
                        .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                        .fixedSize()
                    TextField("Type more words", text: Binding(
                        get: { model.appending ?? "" },
                        set: { model.appending = $0 }
                    ))
                    .font(.hjHeadline)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, Tokens.Space.s4).padding(.vertical, Tokens.Space.s3)
                    .sunkCard(radius: Tokens.Radius.button)
                    .frame(minWidth: 300, maxWidth: 380)
                    .focusedOnAppear()
                    .onSubmit { model.commitAppend() }
                    PrimaryButton(title: "Add them", systemImage: "checkmark", minWidth: 170, height: 56,
                                  enabled: !(model.appending ?? "").trimmingCharacters(in: .whitespaces).isEmpty) {
                        model.commitAppend()
                    }
                }
                TextButton(title: "Never mind") { model.cancelEdit() }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The one line of guidance under the accuracy. It changes as the page does, because
    /// the thing worth saying changes with the state of the page.
    private var hint: String {
        if model.tool.erases {
            return model.tool.drawsDoodles
                ? "Rub out a doodle — nothing else is touched"
                : "Rub out a letter to fix it — nothing else is lost"
        }
        if model.tool.editsWords { return "Tap a word to fix it, or after the last word to add more" }
        if model.pageText.isEmpty { return "Tap the big microphone to begin" }
        if model.controller.hasSelection { return "Write over the dark letters" }
        if model.hasSpokenText { return "Write with your pencil — ABC fixes a word or adds more" }
        return "Tap the mic to say more — or a line's handle to pick it"
    }

    // MARK: - Results

    func resultsStage(_ layout: ScreenLayout) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if layout.isLandscape {
                    // v3.3 — the score beside the page, and one way out under both.
                    HStack(alignment: .center, spacing: Tokens.Space.s7) {
                        scoreColumn.frame(maxWidth: .infinity)
                        pageColumnOfResults.frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                } else {
                    scoreColumn
                    pageColumnOfResults
                }
                wayOut
            }
        }
    }

    /// The headline, the stars, the ring and the points — the score.
    private var scoreColumn: some View {
        VStack(spacing: 0) {
            Text(headline).font(.hjDisplay).foregroundStyle(Tokens.Colour.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Tokens.Space.s8)
            Text(subtitle).font(.hjHeadline).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.top, Tokens.Space.s2)

            if let result = model.lastResult, result.wordsWritten > 0 {
                    StarsView(earned: result.stars, size: StarsView.results.size, gap: StarsView.results.gap)
                        .padding(.top, Tokens.Space.s5)
                    AccuracyRing(accuracy: result.accuracy).padding(.top, Tokens.Space.s5)
                    Text("+ \(result.totalPoints) points").font(.hjNumeralL)
                        .foregroundStyle(Tokens.Colour.textPrimary).padding(.top, Tokens.Space.s4)
                    Text(ScoringEngine.finishMessage(for: result))
                        .font(.hjCaption)
                        .foregroundStyle(result.everyLetterFinished ? Tokens.Colour.success : Tokens.Colour.textSecondary)
                        .padding(.top, Tokens.Space.s2)

                    if !result.finishedEverything {
                        Text("\(result.wordsRemaining) words you said are still spoken — waiting on the page for next time.")
                            .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, Tokens.Space.s5)
                    }
                }
        }
    }

    /// The page as it was written, its setup, and any badge it earned.
    private var pageColumnOfResults: some View {
        VStack(spacing: 0) {
                if let session = model.session, session.hasWriting {
                    pagePreview(session).padding(.top, Tokens.Space.s6)
                }

                Text(model.setup.summary).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                    .padding(.top, Tokens.Space.s4)

                ForEach(model.newBadges) { badge in
                    HStack(spacing: Tokens.Space.s4) {
                        Image(systemName: badge.systemImage).font(.system(size: 28))
                            .foregroundStyle(Tokens.Colour.starOn)
                            .frame(width: 60, height: 60)
                            .background(Tokens.Colour.paperRaised, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEW BADGE").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            Text(badge.name).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(Tokens.Space.s4).card()
                    .padding(.horizontal, Tokens.Layout.screenMargin).padding(.top, Tokens.Space.s4)
                }
        }
    }

    /// One way out (v3.2): home. The page is in the journal now, and there is nothing
    /// left to do here; saying more happens from the journal.
    private var wayOut: some View {
        VStack(spacing: Tokens.Space.s3) {
            PrimaryButton(title: "Back to my journal", systemImage: "book.closed",
                          minWidth: 340, height: 72) { dismissSession() }
            Text(model.lastResult?.finishedEverything == true
                 ? "Want to say more about today? Open this entry from your journal and tap the mic."
                 : "Carry on any time: open this entry from your journal and the waiting words are still there.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Layout.screenMargin)
        }
        .padding(.top, Tokens.Space.s7)
        .padding(.bottom, Tokens.Space.s8)
    }

    private var headline: String {
        guard let result = model.lastResult, result.wordsWritten > 0 else { return "Saved for later" }
        return result.finishedEverything ? "You wrote everything you said!" : "Great writing, \(profile.name)!"
    }

    private var subtitle: String {
        guard let result = model.lastResult, result.wordsWritten > 0 else {
            return "Your words are waiting in the journal."
        }
        if result.finishedEverything {
            return result.wordsWritten == 1 ? "You wrote 1 word today" : "All \(result.wordsWritten) words, in your own hand"
        }
        return result.wordsWritten == 1
            ? "You wrote 1 word today"
            : "You wrote \(result.wordsWritten) words today"
    }

    private func pagePreview(_ session: WritingSession) -> some View {
        Group {
            if let data = session.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxHeight: 220)
                    .card()
                    .padding(.horizontal, Tokens.Layout.screenMargin)
            }
        }
    }
}
