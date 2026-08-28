import SwiftUI
import SwiftData

/// The heart of the app: the same entry read two ways.
///
/// **Typed** renders the transcript on ruled paper in the same face the child traced, so
/// the two readings are visually comparable rather than one plain and one pretty.
/// **Handwritten** renders the archived strokes in natural graphite, always — a journal
/// should read like handwriting, not like a marked-up test.
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WritingSession

    enum Reading: Hashable { case typed, handwritten }
    @State private var reading: Reading = .handwritten
    @State private var player = ClipPlayer()
    @State private var strokes: [TracingStroke] = []
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var renaming = false
    @State private var draftTitle = ""
    @State private var writing = false
    @State private var confirmStartOver = false

    private var setup: WritingSetup { session.setup }

    var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(options: [(Reading.typed, "Typed"), (Reading.handwritten, "Handwritten")],
                             selection: $reading)
                .frame(width: 420)
                .padding(.top, Tokens.Space.s5)

            page
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Space.s5)

            metadata
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Space.s5)

            HStack(spacing: Tokens.Space.s4) {
                SecondaryButton(title: writeAgainTitle, systemImage: "pencil.line", minWidth: 268) {
                    startWriting()
                }
                SecondaryButton(title: "Share", systemImage: "square.and.arrow.up", minWidth: 268) {
                    showExport = true
                }
            }
            .padding(.vertical, Tokens.Space.s5)
        }
        .background(Tokens.Colour.paper)
        .navigationTitle(session.displayDate)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.id) { await loadStrokes() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { startWriting() } label: {
                        Label(writeAgainTitle, systemImage: "pencil.line")
                    }
                    if let audio = session.audioData {
                        Button { player.play(audio, id: session.id) } label: {
                            Label(player.playingID == session.id ? "Stop" : "Hear what I said",
                                  systemImage: "speaker.wave.2.fill")
                        }
                    }
                    Button { showExport = true } label: {
                        Label("Share as PDF", systemImage: "square.and.arrow.up")
                    }
                    Button { draftTitle = session.customTitle ?? ""; renaming = true } label: {
                        Label("Rename this entry", systemImage: "textformat")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete this entry", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showExport) {
            ExportView(profile: session.author, session: session).presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $writing) {
            if let author = session.author {
                WriteSessionView(profile: author, context: context,
                                 resuming: session, startingOver: session.isComplete)
            }
        }
        .confirmationDialog("Write this entry again?", isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button("Write it again", role: .destructive) { writing = true }
            Button("Keep what I wrote", role: .cancel) {}
        } message: {
            Text("This will replace what you wrote. The words stay the same.")
        }
        .alert("Rename this entry", isPresented: $renaming) {
            TextField("Title", text: $draftTitle)
            Button("Save") { session.customTitle = draftTitle.isEmpty ? nil : draftTitle }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(session)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Grown-ups only. The handwriting and the recording go with it.")
        }
    }

    /// The page scrolls — a long entry overflows the surface, and the journal is never
    /// truncated.
    private var page: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                if reading == .typed {
                    GuidePreview(text: session.transcript, setup: setup, showRules: true, inset: Tokens.Space.s5)
                        .frame(height: typedHeight)
                } else if !strokes.isEmpty {
                    InkReplayView(strokes: strokes,
                                  capturedSize: CGSize(width: session.canvasWidth, height: session.canvasHeight),
                                  setup: setup)
                        .frame(height: replayHeight)
                } else {
                    Text(session.transcript)
                        .font(.hjBody).foregroundStyle(Tokens.Colour.starOff)
                        .padding(Tokens.Space.s5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 460)
        .background(Tokens.Colour.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).stroke(Tokens.Colour.divider, lineWidth: 1))
    }

    private var typedHeight: CGFloat {
        let width = UIScreen.main.bounds.width - Tokens.Layout.screenMargin * 2 - Tokens.Space.s5 * 2
        return max(200, MaskRenderer.contentHeight(text: session.transcript, setup: setup, width: width))
    }

    private var replayHeight: CGFloat {
        guard session.canvasWidth > 0 else { return 300 }
        let width = UIScreen.main.bounds.width - Tokens.Layout.screenMargin * 2
        return max(200, session.canvasHeight * (width / session.canvasWidth))
    }

    /// A finished entry is written *again* — that replaces the tracing, so it asks first.
    /// An unfinished one is simply carried on with, which needs no warning at all.
    private var writeAgainTitle: String {
        session.isComplete ? "Write This Again" : "Keep Writing"
    }

    private func startWriting() {
        if session.isComplete { confirmStartOver = true } else { writing = true }
    }

    /// One row for the whole entry: accuracy, words, and the recording the child made when
    /// they said it. There is nothing below entry level to report on (§4.7).
    private var metadata: some View {
        HStack(spacing: Tokens.Space.s5) {
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
                Text(session.setup.summary).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
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
        .padding(Tokens.Space.s4)
        .sunkCard(radius: Tokens.Radius.card)
    }

    private func loadStrokes() async {
        guard let data = session.strokeArchive else { strokes = []; return }
        strokes = (try? StrokeArchive.decode(data)) ?? []
    }
}
