import SwiftUI
import Combine

@MainActor
final class DictationViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isManualEntry: Bool = false
    // Forwarded from speechService so the view redraws on changes
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?

    let speechService = SpeechRecognitionService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward all speech service published properties into this object
        // so a single @StateObject observation drives the UI.
        speechService.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isRecording)
        speechService.$transcribedText
            .receive(on: RunLoop.main)
            .assign(to: &$transcribedText)
        speechService.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: &$errorMessage)
    }

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasTranscription: Bool {
        !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var finalText: String {
        if isManualEntry {
            return trimmedText
        }
        return transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startListening() {
        speechService.requestAuthorization()
        speechService.startRecording()
    }

    func stopListening() {
        speechService.stopRecording()
        text = speechService.transcribedText
    }

    func reset() {
        speechService.reset()
        text = ""
    }

    func toggleManualEntry() {
        if speechService.isRecording {
            speechService.stopRecording()
        }
        isManualEntry.toggle()
    }
}
