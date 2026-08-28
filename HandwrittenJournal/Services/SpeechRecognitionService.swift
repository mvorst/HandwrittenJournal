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
    private(set) var transcript = ""
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Double = 0
    private(set) var recordingURL: URL?

    var didReachCap = false

    private let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var file: AVAudioFile?
    private var timer: Timer?
    private var startedAt: Date?

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
        transcript = ""
        elapsed = 0
        didReachCap = false

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        if #available(iOS 16.0, *) { request.addsPunctuation = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-\(UUID().uuidString).caf")
        file = try AVAudioFile(forWriting: url, settings: format.settings)
        recordingURL = url

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            try? self?.file?.write(from: buffer)
            let rms = Self.rms(buffer)
            Task { @MainActor in self?.level = rms }
        }

        engine.prepare()
        try engine.start()
        startedAt = .now
        isRecording = true

        task = recogniser?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || (result?.isFinal ?? false) { self.finishEngine() }
            }
        }

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

    func stop() {
        guard isRecording else { return }
        isRecording = false
        request?.endAudio()
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
        request = nil
        file = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stop()
        transcript = ""
        elapsed = 0
        didReachCap = false
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
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
