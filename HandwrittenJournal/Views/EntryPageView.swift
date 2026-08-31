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
/// | **View** | the entry as it reads: typed or handwritten, with its stats | an entry reopened from the journal |
///
/// **The pencil switches modes by itself.** Putting the pen on a page you were reading is
/// the ask to write on it, so it hands over without the child finding a button first — the
/// button is there for fingers.
///
/// Nothing is destroyed by moving between them: it is one session, one canvas archive, and
/// the ink is set aside on the way out of Edit so the surface can be rebuilt from it.
struct EntryPageView: View {

    enum Mode: Hashable { case view, edit }
    enum Reading: Hashable { case typed, handwritten }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context

    @State var model: WriteSessionViewModel
    @State private var mode: Mode
    @State private var reading: Reading = .handwritten
    @State var typedText = ""
    @FocusState var typing: Bool

    @State private var player = ClipPlayer()
    @State private var strokes: [TracingStroke] = []
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var confirmStartOver = false
    @State private var renaming = false
    @State private var draftTitle = ""

    let profile: UserProfile

    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, mode: Mode = .edit) {
        self.profile = profile
        _model = State(initialValue: WriteSessionViewModel(profile: profile, context: context,
                                                           resuming: session))
        // A new entry opens on the writing surface — the child has just said the words and
        // the next thing they do is write them. An entry reopened from the journal opens
        // as what it is: something they finished and came back to read.
        _mode = State(initialValue: session == nil ? .edit : mode)
    }

    var body: some View {
        ZStack {
            Tokens.Colour.paper.ignoresSafeArea()
            switch model.stage {
            case .explainPermission:        permissionExplainer
            case .unavailable(let message): unavailable(message)
            case .results:                  resultsStage
            case .writing:                  mode == .edit ? AnyView(writingStage) : AnyView(readingStage)
            }
        }
        .task { await model.prepare() }
        .task(id: mode) { if mode == .view { await loadStrokes() } }
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
            Text("Grown-ups only. The handwriting and the recording go with it.")
        }
    }

    var today: String { Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()) }

    /// The date this page belongs to — the entry's own, not today's, once there is one.
    var pageDate: String { model.session?.displayDate ?? today }

    func dismissSession() { dismiss() }

    // MARK: - Switching

    /// Edit is where the ink is made, so leaving it is the moment to keep the ink: the
    /// surface is torn down here and rebuilt from the archive when the child comes back.
    func show(_ next: Mode) {
        guard next != mode else { return }
        if mode == .edit { model.setAsideInk() }
        model.cancelEdit()
        model.isEraserActive = false
        if model.mic == .listening { model.dictationEnded() }
        mode = next
    }

    /// The results are read and done with: back to the page, as the entry it now is.
    func finishedLooking() {
        model.lastResult = nil
        model.newBadges = []
        model.stage = .writing
        show(.view)
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

    /// The one bar both modes share: the way out, the date, the mode switch, and whatever
    /// tools the mode brings with it.
    func chrome<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Tokens.Space.s4) {
            TextButton(title: leaveTitle) { leave() }
            Spacer(minLength: Tokens.Space.s4)
            Text(pageDate).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Tokens.Space.s4)
            modeSwitch
            trailing()
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: Tokens.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    /// Finishing an entry is a moment worth marking, so Edit keeps *I'm finished* and its
    /// results. Reading one is not — Back is just back.
    private var leaveTitle: String { mode == .edit ? "I'm finished" : "Back" }

    private func leave() {
        if mode == .edit {
            model.isEraserActive = false
            if model.pageText.isEmpty { dismissSession() } else { model.finishWriting() }
        } else {
            dismissSession()
        }
    }

    private var modeSwitch: some View {
        SegmentedControl(options: [(Mode.view, "View"), (Mode.edit, "Edit")],
                         selection: Binding(get: { mode }, set: { show($0) }),
                         height: 48)
            .frame(width: 200)
            .disabled(!canRead)
    }

    /// There is nothing to read until something has been said.
    private var canRead: Bool { !(model.session?.pageText.isEmpty ?? true) }

    /// The ⋯ menu — everything that is about the entry rather than about the page.
    var entryMenu: some View {
        Menu {
            if let audio = model.session?.audioData, let id = model.session?.id {
                Button { player.play(audio, id: id) } label: {
                    Label(player.playingID == id ? "Stop" : "Hear what I said",
                          systemImage: "speaker.wave.2.fill")
                }
            }
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

    /// The same entry read two ways. **Typed** puts the words on ruled paper in the face
    /// the child traced; **Handwritten** puts their own strokes back over the faint guide,
    /// laid out at the width they wrote at so the words stay under the ink.
    private var readingStage: some View {
        VStack(spacing: 0) {
            chrome { entryMenu }

            SegmentedControl(options: [(Reading.typed, "Typed"), (Reading.handwritten, "Handwritten")],
                             selection: $reading)
                .frame(width: 420)
                .padding(.top, Tokens.Space.s5)

            readingPage
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Space.s5)
                .frame(maxHeight: .infinity)

            metadata
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
    }

    private var readingPage: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                if let session = model.session {
                    if reading == .typed {
                        GuidePreview(text: session.transcript, setup: model.setup,
                                     showRules: true, inset: Tokens.Space.s5)
                            .frame(height: typedHeight(session))
                    } else if !strokes.isEmpty {
                        PageReplayView(strokes: strokes,
                                       text: session.transcript,
                                       capturedWidth: session.canvasWidth,
                                       setup: model.setup,
                                       onPencilTap: { show(.edit) })
                            .frame(height: replayHeight(session))
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
    }

    private func typedHeight(_ session: WritingSession) -> CGFloat {
        let width = UIScreen.main.bounds.width - Tokens.Layout.screenMargin * 2 - Tokens.Space.s5 * 2
        return max(200, MaskRenderer.contentHeight(text: session.transcript, setup: model.setup, width: width))
    }

    /// The replay is scaled from the width the child wrote at, so its height follows that
    /// same ratio — and it is sized to the *text*, not to the captured canvas, because the
    /// writing page keeps ruling itself far below the last word.
    private func replayHeight(_ session: WritingSession) -> CGFloat {
        guard session.canvasWidth > 0 else { return 300 }
        let width = UIScreen.main.bounds.width - Tokens.Layout.screenMargin * 2
        let scale = width / session.canvasWidth
        let textWidth = session.canvasWidth - Tokens.Layout.surfaceInset * 2
        guard textWidth > 0 else { return max(200, session.canvasHeight * scale) }
        let content = MaskRenderer.contentHeight(text: session.transcript, setup: model.setup, width: textWidth)
        return max(200, min(content, session.canvasHeight) * scale)
    }

    /// One row for the whole entry: accuracy, words, and the recording the child made when
    /// they said it. There is nothing below entry level to report on (§4.7).
    private var metadata: some View {
        HStack(spacing: Tokens.Space.s5) {
            if let session = model.session {
                if session.hasWriting {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.accuracyPercent)%")
                            .font(.hjNumeralL).foregroundStyle(Tokens.Colour.textPrimary)
                        Text("accuracy").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                    }
                    StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
                }
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
                Spacer()
                if let audio = session.audioData {
                    Button { player.play(audio, id: session.id) } label: {
                        HStack(spacing: Tokens.Space.s2) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 24))
                            Text(player.playingID == session.id ? "Stop" : "Hear what I said").font(.hjBodyEm)
                        }
                        .foregroundStyle(Tokens.Colour.action)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(Tokens.Space.s4)
        .sunkCard(radius: Tokens.Radius.card)
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
            if typing {
                TextField("Type what you want to write", text: $typedText, axis: .vertical)
                    .font(.hjBody).lineLimit(3...8)
                    .padding(Tokens.Space.s4).sunkCard(radius: Tokens.Radius.button)
                    .focused($typing)
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                PrimaryButton(title: "Put it on the page", systemImage: "checkmark", enabled: !typedText.isEmpty) {
                    typing = false
                    model.useTyped(typedText)
                    typedText = ""
                }
            } else {
                TextButton(title: "Type it instead", systemImage: "keyboard") { typing = true }
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
