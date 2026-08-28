import SwiftUI

// MARK: - The page (the one screen of v2.5), and the results after it

extension WriteSessionView {

    /// One continuous scrolling page carrying all three text tiers — written, in hand,
    /// spoken — with the mic in the footer and everything else layered over the page:
    /// the empty-page invitation, the listening bar, the cap banner, the word editor.
    var writingStage: some View {
        VStack(spacing: 0) {
            toolbar

            ZStack(alignment: .top) {
                TracingSurface(text: model.pageText,
                               setup: model.setup,
                               showGuideLines: profile.guideLinesEnabled,
                               showGuideText: true,
                               colourBlind: profile.colorBlindMode,
                               allowFinger: profile.allowFingerTracing,
                               isEraserActive: model.isEraserActive,
                               isDictating: model.mic == .listening,
                               editingRange: model.editing?.range,
                               startAtWord: model.startWord,
                               restoring: model.restoredStrokes,
                               controller: $model.controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.pageText.isEmpty && model.mic == .idle { invitation }
                if model.mic == .capped { capBanner }
            }

            if let editing = model.editing {
                wordEditor(editing)
            } else if model.mic == .listening {
                listeningBar
            } else {
                footer
            }
        }
    }

    private var toolbar: some View {
        HStack {
            TextButton(title: "I'm finished") { finishAndMaybeClose() }
            Spacer()
            Text(today).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
            Spacer()
            HStack(spacing: Tokens.Space.s2) {
                ToolbarIconButton(systemImage: "eraser.fill",
                                  enabled: model.controller.hasInk,
                                  active: model.isEraserActive) { model.isEraserActive.toggle() }
                ToolbarIconButton(systemImage: "arrow.uturn.backward",
                                  enabled: model.controller.hasInk) { model.controller.undo() }
                ToolbarIconButton(systemImage: "trash",
                                  enabled: model.controller.hasInk) { model.controller.clear() }
            }
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: Tokens.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    private func finishAndMaybeClose() {
        model.isEraserActive = false
        if model.pageText.isEmpty { dismissSession() } else { model.finishWriting() }
    }

    // MARK: - Overlays

    /// Frame 20 — the same mic as the footer's, drawn big when there is nothing else to
    /// aim at.
    private var invitation: some View {
        VStack(spacing: 0) {
            Button { model.micTapped() } label: {
                ZStack {
                    Circle().fill(Tokens.Colour.action).frame(width: 176, height: 176)
                        .hjShadow(Tokens.Elevation.raised)
                    Image(systemName: "mic.fill").font(.system(size: 76)).foregroundStyle(Tokens.Colour.textOnAction)
                }
            }
            .buttonStyle(PressableStyle())
            Text("Tell me about your day, \(profile.name)")
                .font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s7)
            Text("Say as much as you like — up to five minutes.\nYour words land right here for you to write.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s3)
            typeBox.padding(.top, Tokens.Space.s6)
        }
        .padding(.top, 150)
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
                Text("I stopped listening so we can start writing. Tap the first line whenever you're ready.")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: 660)
        .background(Tokens.Colour.paperRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .hjShadow(Tokens.Elevation.modal)
        .padding(.top, Tokens.Space.s6)
        .onTapGesture { model.dismissCapBanner() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Footers

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                // The mic — saying more, any time. Same control as the big one on an
                // empty page.
                Button { model.micTapped() } label: {
                    ZStack {
                        Circle().fill(Tokens.Colour.action).frame(width: 64, height: 64)
                        Image(systemName: "mic.fill").font(.system(size: 28)).foregroundStyle(Tokens.Colour.textOnAction)
                    }
                }
                .buttonStyle(PressableStyle())

                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(model.controller.wordsWritten > 0
                         ? "So far: \(Int((model.controller.liveAccuracy * 100).rounded()))%"
                         : "Nothing written yet")
                        .font(.hjBody)
                        .foregroundStyle(model.controller.wordsWritten > 0 ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                    Text(hint)
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .lineLimit(2)
                }
                .frame(width: 218, alignment: .leading)

                if model.totalWords > 0 {
                    WritingProgressBar(written: model.wordsWritten, total: model.totalWords)
                }

                // Scrolling without a gesture, because two-finger scroll is a lot to ask
                // of a five-year-old holding a pencil.
                ToolbarIconButton(systemImage: "chevron.down") { model.controller.nextLines() }

                PrimaryButton(title: "Done", systemImage: "checkmark", minWidth: 200, height: 64,
                              enabled: !model.pageText.isEmpty) {
                    finishAndMaybeClose()
                }
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The footer while recording: level, elapsed of 5:00, and the stop. The page above
    /// is the live transcript.
    private var listeningBar: some View {
        VStack(spacing: Tokens.Space.s2) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            Text("Nothing goes in your journal until you write it.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.top, Tokens.Space.s1)
            HStack(alignment: .center, spacing: Tokens.Space.s5) {
                LevelMeter(level: model.speech.level)
                    .frame(width: 280, height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(SpeechRecognitionService.formatted(model.speech.elapsed))
                        .font(.hjNumeralL).monospacedDigit().foregroundStyle(Tokens.Colour.textPrimary)
                    Text("of \(SpeechRecognitionService.formatted(SpeechRecognitionService.maximumDuration))")
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                }
                Spacer()
                PrimaryButton(title: "I'm done talking", systemImage: "checkmark", minWidth: 260, height: 64) {
                    model.dictationEnded()
                }
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.bottom, Tokens.Space.s4)
        }
    }

    /// §11.13 — fixing a spoken word in place. The word sits boxed on the page above;
    /// the keyboard rises under this bar.
    private func wordEditor(_ editing: WriteSessionViewModel.EditingWord) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            HStack(spacing: Tokens.Space.s4) {
                Text("Fix the word:").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                TextField("Word", text: Binding(
                    get: { model.editing?.draft ?? editing.draft },
                    set: { model.editing?.draft = $0 }
                ))
                .font(.hjHeadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(false)
                .padding(.horizontal, Tokens.Space.s4).padding(.vertical, Tokens.Space.s3)
                .sunkCard(radius: Tokens.Radius.button)
                .frame(maxWidth: 320)
                .focusedOnAppear()
                .onSubmit { model.commitEdit() }
                PrimaryButton(title: "Fix it", systemImage: "checkmark", minWidth: 160, height: 56,
                              enabled: !(model.editing?.draft.isEmpty ?? true)) {
                    model.commitEdit()
                }
                TextButton(title: "Never mind") { model.cancelEdit() }
                Spacer()
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The one line of guidance under the accuracy. It changes as the page does, because
    /// the thing worth saying changes with the state of the page.
    private var hint: String {
        if model.isEraserActive { return "Rub out a letter to fix it — nothing else is lost" }
        if model.controller.hasSelection { return "Write over the dark letters" }
        if model.pageText.isEmpty { return "Tap the mic and tell me about your day" }
        if model.hasSpokenText { return "Tap a line to write it" }
        return "Tap the mic to say more — or a line to fix it"
    }

    // MARK: - Results

    var resultsStage: some View {
        ScrollView {
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

                VStack(spacing: Tokens.Space.s3) {
                    if let result = model.lastResult, !result.finishedEverything {
                        PrimaryButton(title: "Keep writing", systemImage: "pencil.line",
                                      minWidth: 340, height: 72) { model.keepWriting() }
                    } else {
                        // More about the same day joins this page as spoken text.
                        PrimaryButton(title: "Say something new", systemImage: "mic.fill",
                                      minWidth: 340, height: 72) { model.sayMore() }
                    }
                    SecondaryButton(title: "See My Journal", minWidth: 300) { dismissSession() }
                }
                .padding(.top, Tokens.Space.s7)
                .padding(.bottom, Tokens.Space.s8)
            }
        }
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

/// Focuses a text field the moment it appears — the word editor exists to be typed into.
private struct FocusOnAppear: ViewModifier {
    @FocusState private var focused: Bool
    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onAppear { focused = true }
    }
}

extension View {
    func focusedOnAppear() -> some View { modifier(FocusOnAppear()) }
}
