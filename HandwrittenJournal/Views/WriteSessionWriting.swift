import SwiftUI

// MARK: - The writing page, and what comes after it

extension WriteSessionView {

    /// One continuous scrolling page. The child works down it at their own pace and stops
    /// whenever they like. Finished lines lose their guide and become handwriting in
    /// place; tapping one offers it back to be written again (WIREFRAME_SPEC.md §11.11).
    var writingStage: some View {
        VStack(spacing: 0) {
            HStack {
                TextButton(title: "I'm finished") { model.finishWriting() }
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

            TracingSurface(text: model.transcript,
                           setup: model.setup,
                           showGuideLines: profile.guideLinesEnabled,
                           showGuideText: true,
                           colourBlind: profile.colorBlindMode,
                           allowFinger: profile.allowFingerTracing,
                           isEraserActive: model.isEraserActive,
                           startAtWord: model.startWord,
                           restoring: model.restoredStrokes,
                           controller: $model.controller)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        VStack(spacing: Tokens.Space.s3) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            HStack(alignment: .center, spacing: Tokens.Space.s5) {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(model.controller.hasInk
                         ? "So far: \(Int((model.controller.liveAccuracy * 100).rounded()))%"
                         : "Not started yet")
                        .font(.hjBody)
                        .foregroundStyle(model.controller.hasInk ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                    Text(hint)
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                        .lineLimit(2)
                }
                .frame(width: 250, alignment: .leading)

                WritingProgressBar(written: model.wordsWritten, total: model.totalWords)

                // Scrolling without a gesture, because two-finger scroll is a lot to ask
                // of a five-year-old holding a pencil.
                ToolbarIconButton(systemImage: "chevron.down") { model.controller.nextLines() }

                PrimaryButton(title: "Done", systemImage: "checkmark", minWidth: 220, height: 64) {
                    model.isEraserActive = false
                    model.finishWriting()
                }
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    /// The one line of guidance under the accuracy. It changes as the page does, because
    /// the thing worth saying changes: where to start, what finished lines become, and —
    /// once there is one — that a finished line can be tapped and written again.
    private var hint: String {
        if model.isEraserActive { return "Rub out a letter to fix it — nothing else is lost" }
        if model.controller.selectedLine != nil { return "Tap the button to write that line again" }
        if !model.controller.hasInk { return "Start at the top" }
        if model.controller.gradedLineCount > 0 { return "Tap a line you've written to do it again" }
        return "Finished lines become your handwriting"
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
                        Text("\(result.wordsRemaining) words are waiting whenever you want them.")
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
                                      minWidth: 340, height: 72) { model.writeMore() }
                    } else {
                        // More about the same day joins this page rather than starting
                        // a new one (§11.11).
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
        return result.finishedEverything ? "You wrote the whole thing!" : "Great writing, \(profile.name)!"
    }

    private var subtitle: String {
        guard let result = model.lastResult, result.wordsWritten > 0 else {
            return "Your words are waiting in the journal."
        }
        return result.wordsWritten == 1
            ? "You wrote 1 word today"
            : "You wrote \(result.wordsWritten) of \(result.totalWords) words"
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
