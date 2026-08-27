import AVFoundation

final class AudioService {
    static let shared = AudioService()
    private var player: AVAudioPlayer?

    private init() {}

    func play(sound: String, ext: String = "mp3") {
        guard let url = Bundle.main.url(forResource: sound, withExtension: ext) else {
            // Gracefully handle missing audio files
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            // Silently fail — audio is non-critical
        }
    }

    func stopAll() {
        player?.stop()
        player = nil
    }
}
