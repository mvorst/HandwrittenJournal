import SwiftUI

struct DictationView: View {
    @ObservedObject var navigationState: NavigationState
    @EnvironmentObject var gameState: GameStateViewModel
    @StateObject private var viewModel = DictationViewModel()

    private var playerName: String {
        gameState.player?.firstName ?? "Friend"
    }

    var body: some View {
        VStack(spacing: 30) {
            // Top bar
            HStack {
                Button(action: { navigationState.currentScreen = .dashboard }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppConstants.primaryAction)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            Text("What do you want to write, \(playerName)?")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            if viewModel.isManualEntry {
                // Manual text entry
                TextField("Type your sentence here...", text: $viewModel.text, axis: .vertical)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    )
                    .frame(maxWidth: 500)
                    .lineLimit(4)
                    .onChange(of: viewModel.text) { _, newValue in
                        if newValue.count > AppConstants.maxTextLength {
                            viewModel.text = String(newValue.prefix(AppConstants.maxTextLength))
                        }
                    }
            } else {
                // Microphone button
                Button(action: toggleRecording) {
                    ZStack {
                        // Pulsing ring — only visible while recording
                        if viewModel.isRecording {
                            Circle()
                                .fill(AppConstants.outsideRed.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .modifier(PulseModifier())
                        }

                        Circle()
                            .fill(viewModel.isRecording ? AppConstants.outsideRed : AppConstants.primaryAction)
                            .frame(width: 80, height: 80)
                            .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)

                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }

                // Label below button
                Text(viewModel.isRecording ? "Tap to stop" : "Tap to speak")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)

                // Live transcription text
                if !viewModel.transcribedText.isEmpty {
                    Text("\"\(viewModel.transcribedText)\"")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                        .animation(.easeIn(duration: 0.15), value: viewModel.transcribedText)
                } else if viewModel.isRecording {
                    Text("Listening...")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(AppConstants.outsideRed)
                }
            }

            // Action buttons
            HStack(spacing: 20) {
                if viewModel.hasText || viewModel.hasTranscription {
                    Button("Try Again") {
                        viewModel.reset()
                    }
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }

                if !viewModel.finalText.isEmpty {
                    Button(action: {
                        let text = viewModel.finalText
                        viewModel.stopListening()
                        navigationState.currentScreen = .tracing(text: text)
                    }) {
                        HStack {
                            Text("Done")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppConstants.primaryAction)
                        )
                    }
                }
            }

            Spacer()

            // Type instead button
            Button(action: { viewModel.toggleManualEntry() }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isManualEntry ? "mic.fill" : "keyboard")
                    Text(viewModel.isManualEntry ? "Use voice" : "Type instead")
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
        .appBackground()
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopListening()
        } else {
            viewModel.startListening()
        }
    }
}

// Self-contained pulse animation that starts when the view appears
private struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.35
                }
            }
    }
}
