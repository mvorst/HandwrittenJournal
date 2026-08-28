import SwiftUI
import SwiftData

/// The write flow — one screen (v2.5). The page carries the mic, the live transcript,
/// the fixing and the writing; the only other stages are Results and the two microphone
/// edge cases, which exist because the first thing a five-year-old sees must never be an
/// adult system dialog.
struct WriteSessionView: View {
    @Environment(\.dismiss) var dismiss
    @State var model: WriteSessionViewModel
    @State private var typedText = ""
    @FocusState private var typing: Bool

    let profile: UserProfile

    init(profile: UserProfile, context: ModelContext,
         resuming session: WritingSession? = nil, startingOver: Bool = false) {
        self.profile = profile
        _model = State(initialValue: WriteSessionViewModel(profile: profile, context: context,
                                                           resuming: session, startingOver: startingOver))
    }

    var body: some View {
        ZStack {
            Tokens.Colour.paper.ignoresSafeArea()
            switch model.stage {
            case .explainPermission:        permissionExplainer
            case .unavailable(let message): unavailable(message)
            case .writing:                  writingStage
            case .results:                  resultsStage
            }
        }
        .task { await model.prepare() }
        // The service stops itself at the five-minute cap; the page needs to notice.
        .onChange(of: model.speech.isRecording) { _, recording in
            if !recording { model.dictationEnded() }
        }
        .onDisappear { model.discardIfEmpty() }
    }

    // MARK: - Chrome

    private func chrome(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            TextButton(title: "Back to the page") { model.backToPage() }
            Spacer()
            Text(title).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .frame(height: Tokens.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    var today: String { Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()) }
    func dismissSession() { dismiss() }

    // MARK: - Permission (frame 40 — shown before the iOS prompt)

    private var permissionExplainer: some View {
        VStack(spacing: 0) {
            chrome(today) { Color.clear.frame(width: 60) }
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
            chrome(today) { Color.clear.frame(width: 60) }
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

    /// The typing path — the same road as speaking, with the mic removed. Typed words
    /// land as spoken text and are no more real until they are written.
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
