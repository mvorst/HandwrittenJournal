import SwiftUI
import SwiftData

/// The whole write flow: speak, check, write.
struct WriteSessionView: View {
    @Environment(\.dismiss) var dismiss
    @State var model: WriteSessionViewModel
    @State private var typedText = ""
    @FocusState private var editing: Bool

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
            case .start:                    startStage
            case .recording:                recordingStage
            case .cappedAtLimit:            cappedStage
            case .confirm:                  confirmStage
            case .writing:                  writingStage
            case .results:                  resultsStage
            }
        }
        .task { await model.prepare() }
        .onDisappear { model.discardIfEmpty() }
    }

    // MARK: - Chrome

    private func chrome(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            TextButton(title: "Close") { closeSession() }
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

    private func closeSession() {
        if model.stage == .writing { model.finishWriting() } else { dismiss() }
    }

    // MARK: - Permission

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
            Text("You talk, and we turn it into words you can trace.\nThe iPad listens only while you are recording.")
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
            TextButton(title: "Type it instead", systemImage: "keyboard") { model.stage = .start }
                .padding(.top, Tokens.Space.s4)
            Spacer()
        }
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 0) {
            chrome(today) { Color.clear.frame(width: 60) }
            Spacer()
            ZStack {
                Circle().fill(Tokens.Colour.paperSunk).frame(width: 152, height: 152)
                Image(systemName: "mic.fill").font(.system(size: 72)).foregroundStyle(Tokens.Colour.starOff)
            }
            Text(message).font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary).padding(.top, Tokens.Space.s6)
            Text("You can still type what you want to write.\nA grown-up can turn the microphone on in iPad Settings.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s4)
            typeBox.padding(.top, Tokens.Space.s6)
            Spacer()
        }
    }

    // MARK: - Start

    private var startStage: some View {
        VStack(spacing: 0) {
            chrome(today) { Color.clear.frame(width: 60) }
            Spacer()
            Button { model.startRecording() } label: {
                ZStack {
                    Circle().fill(Tokens.Colour.action).frame(width: 176, height: 176)
                        .hjShadow(Tokens.Elevation.raised)
                    Image(systemName: "mic.fill").font(.system(size: 76)).foregroundStyle(Tokens.Colour.textOnAction)
                }
            }
            .buttonStyle(PressableStyle())
            Text("Tell me about your day, \(profile.name)")
                .font(.hjTitle1).foregroundStyle(Tokens.Colour.textPrimary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s8)
            Text("Say as much as you like — up to five minutes.\nThen you can write it all down.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s3)
            typeBox.padding(.top, Tokens.Space.s6)
            Spacer()
            Text(model.setup.summary).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.bottom, Tokens.Space.s5)
        }
    }

    private var typeBox: some View {
        VStack(spacing: Tokens.Space.s3) {
            if editing {
                TextField("Type what you want to write", text: $typedText, axis: .vertical)
                    .font(.hjBody).lineLimit(3...8)
                    .padding(Tokens.Space.s4).sunkCard(radius: Tokens.Radius.button)
                    .focused($editing)
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                PrimaryButton(title: "Use this", systemImage: "checkmark", enabled: !typedText.isEmpty) {
                    editing = false
                    model.useTyped(typedText)
                }
            } else {
                TextButton(title: "Type it instead", systemImage: "keyboard") { editing = true }
            }
        }
    }

    // MARK: - Recording

    private var recordingStage: some View {
        VStack(spacing: 0) {
            chrome(today) { Color.clear.frame(width: 60) }
            ZStack {
                ForEach([240.0, 196.0, 162.0], id: \.self) { d in
                    Circle().fill(Tokens.Colour.action.opacity(d == 240 ? 0.10 : (d == 196 ? 0.16 : 0.26)))
                        .frame(width: d, height: d)
                }
                Circle().fill(Tokens.Colour.action).frame(width: 132, height: 132)
                Image(systemName: "mic.fill").font(.system(size: 58)).foregroundStyle(Tokens.Colour.textOnAction)
            }
            .padding(.top, Tokens.Space.s5)

            Text(SpeechRecognitionService.formatted(model.speech.elapsed))
                .font(.hjNumeralXL).monospacedDigit().foregroundStyle(Tokens.Colour.textPrimary)
            Text("of \(SpeechRecognitionService.formatted(SpeechRecognitionService.maximumDuration))")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            LevelMeter(level: model.speech.level).padding(.top, Tokens.Space.s4)

            HStack {
                Text("What you've said").font(.hjBodyEm).foregroundStyle(Tokens.Colour.textSecondary)
                Spacer()
                Text("Keep going — I'm listening").font(.hjCaption).foregroundStyle(Tokens.Colour.action)
            }
            .padding(.horizontal, Tokens.Layout.screenMargin).padding(.top, Tokens.Space.s6)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.speech.transcript.isEmpty ? "…" : model.speech.transcript)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .lineSpacing(10).foregroundStyle(Tokens.Colour.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Space.s5).id("t")
                }
                .onChange(of: model.speech.transcript) { proxy.scrollTo("t", anchor: .bottom) }
            }
            .frame(maxHeight: .infinity)
            .background(Tokens.Colour.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).stroke(Tokens.Colour.divider, lineWidth: 1))
            .padding(.horizontal, Tokens.Layout.screenMargin).padding(.top, Tokens.Space.s3)

            PrimaryButton(title: "I'm done talking", systemImage: "checkmark", minWidth: 380, height: 72) {
                model.stopRecording()
            }
            .padding(.top, Tokens.Space.s6)
            Text("Nothing is written down until you tap this.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.vertical, Tokens.Space.s4)
        }
    }

    private var cappedStage: some View {
        VStack(spacing: 0) {
            chrome(today) { Color.clear.frame(width: 60) }
            Spacer()
            ZStack {
                Circle().fill(Tokens.Colour.starOff).frame(width: 132, height: 132)
                Image(systemName: "mic.fill").font(.system(size: 58)).foregroundStyle(Tokens.Colour.paperRaised)
            }
            Text("5:00").font(.hjNumeralXL).foregroundStyle(Tokens.Colour.textPrimary).padding(.top, Tokens.Space.s4)
            Text("That's a whole lot of story!").font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s4)
            Text("I stopped listening so we can start writing.\nYou can say more once this is written.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center).padding(.top, Tokens.Space.s3)
            PrimaryButton(title: "Check what I said", systemImage: "checkmark", minWidth: 400, height: 72) {
                model.stage = .confirm
            }
            .padding(.top, Tokens.Space.s7)
            Spacer()
        }
    }

    // MARK: - Confirm

    private var confirmStage: some View {
        VStack(spacing: 0) {
            HStack {
                TextButton(title: "Say it again") { model.stage = .start }
                Spacer()
                Text("Is that right?").font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                Spacer()
                Color.clear.frame(width: 110)
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .frame(height: Tokens.Layout.toolbarHeight)
            .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }

            Text("Tap the words to fix anything I heard wrong.")
                .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Layout.screenMargin).padding(.top, Tokens.Space.s4)

            TextEditor(text: $model.draftTranscript)
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .lineSpacing(10)
                .scrollContentBackground(.hidden)
                .padding(Tokens.Space.s4)
                .background(Tokens.Colour.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                    .stroke(Tokens.Colour.action, lineWidth: Tokens.Stroke.emphasis))
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Space.s3)

            Text("\(WritingSession.wordCount(model.draftTranscript)) words to write")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.top, Tokens.Space.s3)

            PrimaryButton(title: "Start writing", systemImage: "pencil.line", minWidth: 380, height: 72,
                          enabled: !model.draftTranscript.trimmingCharacters(in: .whitespaces).isEmpty) {
                model.beginWriting()
            }
            .padding(.top, Tokens.Space.s5)
            Text("You can stop whenever you like — it saves as you go.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.vertical, Tokens.Space.s4)
        }
    }
}
