import SwiftUI
import SwiftData

/// **One entry, one screen.** DESIGN_DOCUMENT.md §4.4 and §4.7, merged.
///
/// Reading an entry and writing it were two screens with a modal between them, which made
/// "look at what I wrote" and "write some more" feel like different places. They are the
/// same page in two modes:
///
/// | Mode | The page is | Opens this way |
/// |---|---|---|
/// | **Edit** | the writing surface: mic, ink, tools | a new entry, straight after the telling |
/// | **View** | the entry as it reads: the handwriting, with its stats | an entry reopened from the journal |
///
/// **The pencil switches modes by itself.** Putting the pen on a page you were reading is
/// the ask to write on it, so it hands over without the child finding a button first — the
/// *Write on this page* button is there for fingers. The way out of Edit is **Back**
/// (v3.2): it scores the page as it stands, so the journal is always current, and returns
/// to wherever the child came from. There is no mode switch in the toolbar any more.
///
/// Nothing is destroyed by moving between them: it is one session, one canvas archive, and
/// the ink is set aside on the way out of Edit so the surface can be rebuilt from it.
struct EntryPageView: View {

    enum Mode: Hashable { case view, edit }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context

    @State var model: WriteSessionViewModel
    @State private var mode: Mode
    @State var typedText = ""
    /// Whether the typing box is open. Kept apart from `typing`: a `@FocusState` can
    /// only be set once a view is bound to it, so opening the box *by* focusing it
    /// never opened it at all.
    @State var showTyping = false
    @FocusState var typing: Bool
    /// The stop button's ring while a take runs from the stage (v3.2).
    @State var stagePulse = false

    @State private var strokes: [TracingStroke] = []
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var confirmStartOver = false
    @State private var renaming = false
    @State private var draftTitle = ""

    let profile: UserProfile
    /// Whether the page was opened from the journal — where Back from Edit returns to
    /// the entry as it reads — or is a new entry, where Back is the journal itself.
    private let openedFromJournal: Bool

    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, mode: Mode = .edit) {
        self.profile = profile
        self.openedFromJournal = session != nil
        _model = State(initialValue: WriteSessionViewModel(profile: profile, context: context,
                                                           resuming: session))
        // A new entry opens on the writing surface — the child has just said the words and
        // the next thing they do is write them. An entry reopened from the journal opens
        // as what it is: something they finished and came back to read.
        _mode = State(initialValue: session == nil ? .edit : mode)
    }

    /// Which of the page's faces is up: writing, reading what was written, or the results.
    private func logScreen() {
        switch model.stage {
        case .writing: Telemetry.screen(mode == .edit ? .write : .read)
        case .results: Telemetry.screen(.results)
        case .explainPermission, .unavailable: break
        }
    }

    var body: some View {
        // v3.3 — one screen, two layouts: the window's shape decides, and the page keeps
        // its portrait width either way (`ScreenLayout`).
        GeometryReader { geo in
            let layout = ScreenLayout(geo, railSide: profile.resolvedRailSide)
            ZStack {
                Tokens.Colour.paper.ignoresSafeArea()
                switch model.stage {
                case .explainPermission:        permissionExplainer
                case .unavailable(let message): unavailable(message)
                case .results:                  resultsStage(layout)
                case .writing:                  mode == .edit ? AnyView(writingStage(layout)) : AnyView(readingStage(layout))
                }
            }
        }
        .task { await model.prepare() }
        .task(id: mode) { if mode == .view { await loadStrokes() } }
        .onChange(of: model.stage, initial: true) { logScreen() }
        .onChange(of: mode) { logScreen() }
        // The service stops itself at the five-minute cap; the page needs to notice.
        .onChange(of: model.speech.isRecording) { _, recording in
            if !recording { model.dictationEnded() }
        }
        .onDisappear {
            model.setAsideInk()
            model.discardIfEmpty()
        }
        .sheet(isPresented: $showExport) {
            ExportView(profile: profile, session: model.session).presentationDetents([.large])
        }
        .confirmationDialog("Write this entry again?", isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button("Write it again", role: .destructive) { startOver() }
            Button("Keep what I wrote", role: .cancel) {}
        } message: {
            Text("This will replace what you wrote. The words stay the same.")
        }
        .alert("Rename this entry", isPresented: $renaming) {
            TextField("Title", text: $draftTitle)
            Button("Save") { model.session?.customTitle = draftTitle.isEmpty ? nil : draftTitle }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteEntry() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Grown-ups only. The handwriting goes with it.")
        }
    }

    var today: String { Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()) }

    /// The date this page belongs to — the entry's own, not today's, once there is one.
    var pageDate: String { model.session?.displayDate ?? today }

    func dismissSession() { dismiss() }

    // MARK: - Switching

    /// Edit is where the ink is made, so leaving it is the moment to keep the ink: the
    /// surface is torn down here and rebuilt from the archive when the child comes back
    /// — and coming back is the moment to stage that rebuild from the entry itself.
    func show(_ next: Mode) {
        guard next != mode else { return }
        if mode == .edit || next == .edit { model.setAsideInk() }
        model.cancelEdit()
        model.isEraserActive = false
        if model.mic == .listening { model.dictationEnded() }
        mode = next
    }

    private func startOver() {
        model.writeItAllAgain()
        show(.edit)
    }

    private func deleteEntry() {
        if let session = model.session { context.delete(session) }
        model.forgetSession()
        dismiss()
    }

    private func loadStrokes() async {
        guard let data = model.session?.strokeArchive else { strokes = []; return }
        strokes = (try? StrokeArchive.decode(data)) ?? []
    }

    // MARK: - Chrome

    /// The one bar both modes share: Back, the date, and whatever tools the mode brings
    /// with it (v3.2 — the View/Edit switch is gone; Back is the way out of both).
    func chrome<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Tokens.Space.s4) {
            TextButton(title: "Back") { leave() }
            Spacer(minLength: Tokens.Space.s4)
            Text(pageDate).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Tokens.Space.s4)
            trailing()
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: Tokens.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    /// Back (v3.2). From Edit the page is scored as it stands first, so the journal is
    /// always current, and the child goes back to where they came from: the journal for
    /// a new entry, the entry as it reads for one they reopened. Finishing — with its
    /// results — is the footer's *I'm finished*.
    private func leave() {
        if mode == .edit {
            model.saveScore()
            if openedFromJournal, !(model.session?.pageText.isEmpty ?? true) {
                show(.view)
            } else {
                dismissSession()
            }
        } else {
            dismissSession()
        }
    }

    /// The ⋯ menu — everything that is about the entry rather than about the page.
    var entryMenu: some View {
        Menu {
            if model.session?.hasWriting == true {
                Button { confirmStartOver = true } label: {
                    Label("Write it all again", systemImage: "arrow.counterclockwise")
                }
            }
            Button { showExport = true } label: {
                Label("Share as PDF", systemImage: "square.and.arrow.up")
            }
            Button { draftTitle = model.session?.customTitle ?? ""; renaming = true } label: {
                Label("Rename this entry", systemImage: "textformat")
            }
            Divider()
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Delete this entry", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Tokens.Colour.action)
                .frame(width: Tokens.Target.minimum, height: Tokens.Target.minimum)
        }
        .disabled(model.session == nil)
    }

    // MARK: - Reading (§4.7)

    /// The entry as the child wrote it: their own strokes alone on the ruled page, laid
    /// out at the width they wrote at. In landscape (v3.3) the stats and the actions take
    /// the column beside the page — on the rail's side, so the page stays put when the
    /// pencil lands and Edit takes over.
    private func readingStage(_ layout: ScreenLayout) -> some View {
        let stack = layout.isLandscape
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0))
        return VStack(spacing: 0) {
            chrome { entryMenu }

            stack {
                if layout.railOnLeft { readingAside(layout) }

                readingPage(layout)
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                    .padding(.top, Tokens.Space.s5)
                    .padding(.bottom, layout.isLandscape ? Tokens.Space.s5 : 0)
                    .frame(width: layout.isLandscape ? layout.pageWidth : nil)
                    .frame(maxHeight: .infinity)

                if !layout.isLandscape {
                    metadata(layout)
                        .padding(.horizontal, Tokens.Layout.screenMargin)
                        .padding(.top, Tokens.Space.s5)

                    HStack(spacing: Tokens.Space.s4) {
                        PrimaryButton(title: "Write on this page", systemImage: "pencil.line",
                                      minWidth: 300, height: 64) { show(.edit) }
                        SecondaryButton(title: "Share", systemImage: "square.and.arrow.up", minWidth: 240) {
                            showExport = true
                        }
                    }
                    .padding(.vertical, Tokens.Space.s5)
                }

                if layout.railOnRight { readingAside(layout) }
            }
        }
    }

    /// The column beside the reading page in landscape (v3.3): the stats card at the
    /// top, the two actions at the foot, stretched to the column.
    private func readingAside(_ layout: ScreenLayout) -> some View {
        VStack(spacing: Tokens.Space.s4) {
            metadata(layout)
            Spacer(minLength: 0)
            PrimaryButton(title: "Write on this page", systemImage: "pencil.line",
                          minWidth: 200, height: 64, fillsWidth: true) { show(.edit) }
            SecondaryButton(title: "Share", systemImage: "square.and.arrow.up",
                            minWidth: 200, fillsWidth: true) { showExport = true }
        }
        .padding(.vertical, Tokens.Space.s5)
        .padding(layout.railOnLeft ? .leading : .trailing, Tokens.Layout.screenMargin)
        .frame(width: layout.railWidth)
    }

    private func readingPage(_ layout: ScreenLayout) -> some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                if let session = model.session {
                    if !strokes.isEmpty {
                        PageReplayView(strokes: strokes,
                                       text: session.transcript,
                                       capturedWidth: session.canvasWidth,
                                       setup: model.setup,
                                       showGuideText: false,
                                       onPencilTap: { show(.edit) })
                            .frame(height: replayHeight(session, layout: layout))
                    } else {
                        Text(session.transcript.isEmpty ? session.spokenBuffer : session.transcript)
                            .font(.hjBody).foregroundStyle(Tokens.Colour.starOff)
                            .padding(Tokens.Space.s5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Colour.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).stroke(Tokens.Colour.divider, lineWidth: 1))
        // Touching the page — finger or pencil — is the ask to write on it. The pencil is
        // caught by the replay view's own recogniser; this catches everything else.
        .onTapGesture { show(.edit) }
    }

    /// The replay is scaled from the width the child wrote at, so its height follows that
    /// same ratio — and it is sized to the *content*, not to the captured canvas, because
    /// the writing page keeps ruling itself far below the last word. Content is the written
    /// text and every stroke on the page: a doodle drawn under the last word is part of
    /// the page and must be in view (v3.2).
    private func replayHeight(_ session: WritingSession, layout: ScreenLayout) -> CGFloat {
        guard session.canvasWidth > 0 else { return 300 }
        // The page column's width — the device's portrait width less the margins (v3.3),
        // never the window's, which in landscape would blow the entry up to fill it.
        let width = layout.pageWidth - Tokens.Layout.screenMargin * 2
        let scale = width / session.canvasWidth
        let textWidth = session.canvasWidth - Tokens.Layout.surfaceInset * 2
        guard textWidth > 0 else { return max(200, session.canvasHeight * scale) }
        var content = session.transcript.isEmpty ? 0
            : MaskRenderer.contentHeight(text: session.transcript, setup: model.setup, width: textWidth)
        if let lowest = strokes.map({ $0.bounds().maxY }).max() {
            content = max(content, lowest + Tokens.Space.s7)
        }
        let ceiling = session.canvasHeight > 0 ? session.canvasHeight : content
        return max(200, min(content, ceiling) * scale)
    }

    /// One row for the whole entry: accuracy and words. There is nothing below entry
    /// level to report on (§4.7). In landscape the same card stacks to its column.
    @ViewBuilder
    private func metadata(_ layout: ScreenLayout) -> some View {
        if layout.isLandscape {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                if let session = model.session {
                    if session.hasWriting {
                        HStack(alignment: .center, spacing: Tokens.Space.s5) {
                            accuracyBlock(session)
                            StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
                        }
                    }
                    wordsBlock(session)
                }
            }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sunkCard(radius: Tokens.Radius.card)
        } else {
            HStack(spacing: Tokens.Space.s5) {
                if let session = model.session {
                    if session.hasWriting {
                        accuracyBlock(session)
                        StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
                    }
                    wordsBlock(session)
                    Spacer()
                }
            }
            .padding(Tokens.Space.s4)
            .sunkCard(radius: Tokens.Radius.card)
        }
    }

    private func accuracyBlock(_ session: WritingSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(session.accuracyPercent)%")
                .font(.hjNumeralL).foregroundStyle(Tokens.Colour.textPrimary)
            Text("accuracy").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
        }
    }

    private func wordsBlock(_ session: WritingSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.hasWriting
                 ? "\(session.wordsWritten) of \(session.totalWords) words"
                 : "\(session.totalWords) words, not written yet")
                .font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
            Text(session.hasWriting && session.isComplete
                 ? "You finished the whole thing."
                 : "\(session.wordsRemaining) words are still waiting on the page.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            Text(model.setup.summary).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
        }
    }

    // MARK: - Permission (frame 40 — shown before the iOS prompt)

    private var permissionExplainer: some View {
        VStack(spacing: 0) {
            backToPageBar
            Spacer()
            ZStack {
                Circle().fill(Tokens.Colour.paperSunk).frame(width: 176, height: 176)
                Image(systemName: "mic.fill").font(.system(size: 84)).foregroundStyle(Tokens.Colour.action)
            }
            Text("Can we use the microphone?").font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s8)
            Text("You talk, and your words land on the page for you to write.\nThe iPad listens only while you are recording.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s4)
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(Tokens.Colour.textSecondary)
                Text("Your voice stays on this iPad. It is never sent anywhere, and a grown-up can delete it.")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            }
            .padding(Tokens.Space.s5).frame(maxWidth: .infinity, alignment: .leading).sunkCard()
            .padding(.horizontal, Tokens.Layout.screenMargin).padding(.top, Tokens.Space.s6)

            PrimaryButton(title: "OK, ask me", systemImage: "checkmark", minWidth: 360, height: 72) {
                Task { await model.requestPermission() }
            }
            .padding(.top, Tokens.Space.s8)
            TextButton(title: "Type it instead", systemImage: "keyboard") { model.backToPage() }
                .padding(.top, Tokens.Space.s4)
            Spacer()
        }
    }

    // MARK: - Unavailable (frame 41 — typing onto the page becomes the primary path)

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 0) {
            backToPageBar
            Spacer()
            ZStack {
                Circle().fill(Tokens.Colour.paperSunk).frame(width: 152, height: 152)
                Image(systemName: "mic.fill").font(.system(size: 72)).foregroundStyle(Tokens.Colour.starOff)
            }
            Text(message).font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary).padding(.top, Tokens.Space.s6)
            Text("You can still type your words straight onto the page and write them.\nA grown-up can turn the microphone on in iPad Settings.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s4)
            typeBox.padding(.top, Tokens.Space.s6)
            Spacer()
        }
    }

    private var backToPageBar: some View {
        HStack {
            TextButton(title: "Back to the page") { model.backToPage() }
            Spacer()
            Text(pageDate).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
            Spacer()
            Color.clear.frame(width: 60)
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: Tokens.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    /// The typing path — the same road as speaking, with the mic removed. Typed words land
    /// as spoken text and are no more real until they are written.
    var typeBox: some View {
        VStack(spacing: Tokens.Space.s3) {
            if showTyping {
                TextField("Type what you want to write", text: $typedText, axis: .vertical)
                    .font(.hjBody).lineLimit(3...8)
                    .padding(Tokens.Space.s4).sunkCard(radius: Tokens.Radius.button)
                    .focused($typing)
                    .onAppear { typing = true }
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                PrimaryButton(title: "Put it on the page", systemImage: "checkmark", enabled: !typedText.isEmpty) {
                    typing = false
                    showTyping = false
                    model.useTyped(typedText)
                    typedText = ""
                }
            } else {
                TextButton(title: "Type it instead", systemImage: "keyboard") { showTyping = true }
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
