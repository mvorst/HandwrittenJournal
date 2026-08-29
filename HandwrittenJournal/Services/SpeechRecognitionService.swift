import Foundation
import Speech
import AVFoundation

/// Long-form on-device dictation. DESIGN_DOCUMENT.md §4.4.
///
/// The child talks for as long as they like, up to five minutes. Nothing is committed
/// until they stop. The audio is recorded alongside the transcript so it can be sliced
/// into per-sentence clips afterwards (§10.4).
@Observable
@MainActor
final class SpeechRecognitionService {

    enum Availability: Equatable {
        case unknown
        case ready
        case microphoneDenied
        case speechDenied
        case unavailable(String)

        var isReady: Bool { self == .ready }
    }

    /// §4.4 — the cap exists because the recogniser drifts on long takes, not to hurry
    /// the child.
    static let maximumDuration: TimeInterval = 300

    private(set) var availability: Availability = .unknown
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Double = 0
    private(set) var recordingURL: URL?

    /// Everything heard in this take — the utterances the recogniser has finished and the
    /// one it is still working on, together.
    var transcript: String { take.text }

    var didReachCap = false

    private var take = SpokenTake()
    private let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private let sink = AudioSink()
    private var task: SFSpeechRecognitionTask?
    private var file: AVAudioFile?
    private var timer: Timer?
    private var startedAt: Date?
    /// Consecutive recognition failures with nothing heard between them. A recogniser that
    /// dies the moment it starts must not be restarted forever.
    private var failures = 0
    /// Which task's callbacks count. A finished task can still deliver one, and acting on
    /// it would clobber the utterance its replacement is already hearing.
    private var listening = 0

    // MARK: - Permissions

    func refreshAvailability() async {
        guard let recogniser, recogniser.isAvailable else {
            availability = .unavailable("Speech recognition is not available on this iPad.")
            return
        }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { availability = .speechDenied; return }

        let mic = await AVAudioApplication.requestRecordPermission()
        availability = mic ? .ready : .microphoneDenied
    }

    /// Current status without prompting — used to decide whether to show the explainer.
    func currentStatusWithoutPrompting() -> Availability {
        guard let recogniser, recogniser.isAvailable else {
            return .unavailable("Speech recognition is not available on this iPad.")
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: break
        case .notDetermined: return .unknown
        default: return .speechDenied
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .ready
        case .undetermined: return .unknown
        default: return .microphoneDenied
        }
    }

    // MARK: - Recording

    func start() throws {
        guard !isRecording else { return }
        take = SpokenTake()
        elapsed = 0
        didReachCap = false
        failures = 0

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-\(UUID().uuidString).caf")
        file = try AVAudioFile(forWriting: url, settings: format.settings)
        recordingURL = url

        // The tap outlives any one recognition task: the microphone and the recording run
        // for the whole take while the task underneath them is replaced at every pause.
        let sink = self.sink
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            sink.append(buffer)
            try? self?.file?.write(from: buffer)
            let rms = Self.rms(buffer)
            Task { @MainActor in self?.level = rms }
        }

        engine.prepare()
        try engine.start()
        startedAt = .now
        isRecording = true
        listen()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.startedAt else { return }
                self.elapsed = Date.now.timeIntervalSince(started)
                if self.elapsed >= Self.maximumDuration {
                    self.didReachCap = true
                    self.stop()
                }
            }
        }
    }

    /// Starts a recognition task on the live audio. One task covers one utterance: the
    /// recogniser ends it at a pause, and `heard` starts the next one.
    private func listen() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        sink.use(request)

        listening += 1
        let turn = listening
        task = recogniser?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in self?.heard(result, error: error, turn: turn) }
        }
    }

    /// **A pause ends an utterance, not the take.**
    ///
    /// The recogniser hands back one utterance at a time and numbers each from zero, so
    /// its latest hypothesis is only ever the tail of what the child has said. Taking it
    /// as the transcript threw away everything before the pause — and tearing the engine
    /// down on the first final result stopped the microphone mid-story. So a finished
    /// utterance is committed to the take and a fresh task listens on, because a
    /// five-year-old telling a story stops for breath constantly (§4.4).
    private func heard(_ result: SFSpeechRecognitionResult?, error: Error?, turn: Int) {
        guard turn == listening else { return }
        if let result { take.hear(result.bestTranscription.formattedString) }
        guard error != nil || (result?.isFinal ?? false) else { return }

        let heardSomething = !take.live.isEmpty
        take.endUtterance()

        // The child tapped stop, or the cap fired: the take really is over.
        guard isRecording else { finishEngine(); return }

        failures = (error != nil && !heardSomething) ? failures + 1 : 0
        guard failures < 3 else { stop(); return }
        listen()
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        sink.endAudio()
        finishEngine()
    }

    private func finishEngine() {
        timer?.invalidate(); timer = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        task?.finish()
        task = nil
        sink.use(nil)
        file = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stop()
        take = SpokenTake()
        elapsed = 0
        didReachCap = false
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
    }

    /// The audio tap runs on a render thread while the request it feeds is swapped on the
    /// main actor at every pause. A lock keeps the two apart; without it the swap would
    /// race a buffer append.
    private final class AudioSink: @unchecked Sendable {
        private let lock = NSLock()
        private var request: SFSpeechAudioBufferRecognitionRequest?

        func use(_ next: SFSpeechAudioBufferRecognitionRequest?) {
            lock.lock(); defer { lock.unlock() }
            request = next
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            lock.lock(); defer { lock.unlock() }
            request?.append(buffer)
        }

        func endAudio() {
            lock.lock(); defer { lock.unlock() }
            request?.endAudio()
        }
    }

    // MARK: - Helpers

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let mean = sqrt(sum / Float(count))
        return min(1, Double(mean) * 12)
    }

    static func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Assembles one take out of the utterances the recogniser hands back.
///
/// Kept apart from the service so the part that actually broke — what survives a pause
/// — can be tested without a microphone.
struct SpokenTake: Equatable {
    /// Utterances the recogniser has finished with, in the order they were said.
    private(set) var settled = ""
    /// The utterance it is still working on. Replaced wholesale on every partial
    /// result, because within one utterance the hypothesis is cumulative.
    private(set) var live = ""

    var text: String { Self.joined(settled, live) }

    mutating func hear(_ hypothesis: String) { live = hypothesis }

    /// The recogniser finished an utterance: it joins the take, and the next one
    /// starts from nothing.
    mutating func endUtterance() {
        settled = Self.joined(settled, live)
        live = ""
    }

    /// Utterances are sentences of one telling, so they join with a space. A *take*
    /// is what gets its own paragraph, and the view model does that (§5.2).
    static func joined(_ first: String, _ second: String) -> String {
        let first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = second.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.isEmpty { return second }
        if second.isEmpty { return first }
        return first + " " + second
    }
}
