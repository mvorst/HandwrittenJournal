import Foundation
import AVFoundation

/// DESIGN_DOCUMENT.md §10.4 — keeps the child's voice, one recording per entry.
///
/// There is nothing to slice any more: an entry has one recording, and "Hear what I said"
/// sits on the entry. When the child says more and it is appended to the page they are
/// already on, the new take is joined onto the end of the same recording (§4.4) so the
/// entry keeps one continuous telling rather than a list of fragments.
enum AudioSlicer {

    static func export(url: URL, range: ClosedRange<TimeInterval>) async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).m4a")
        session.outputURL = output
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: max(0, range.lowerBound), preferredTimescale: 600),
            end: CMTime(seconds: max(0.1, range.upperBound), preferredTimescale: 600)
        )
        await session.export()
        defer { try? FileManager.default.removeItem(at: output) }
        guard session.status == .completed else { return nil }
        return try? Data(contentsOf: output)
    }

    /// Joins a fresh take onto the end of the recording an entry already has.
    ///
    /// Returns the existing recording untouched if the new take cannot be read — losing
    /// the addition is bad, losing what was already captured is worse.
    static func append(_ existing: Data?, recording url: URL, range: ClosedRange<TimeInterval>) async -> Data? {
        guard let existing else { return await export(url: url, range: range) }
        guard let addition = await export(url: url, range: range) else { return existing }
        return await concatenate([existing, addition]) ?? existing
    }

    static func concatenate(_ clips: [Data]) async -> Data? {
        guard clips.count > 1 else { return clips.first }
        let directory = FileManager.default.temporaryDirectory
        var scratch: [URL] = []
        defer { scratch.forEach { try? FileManager.default.removeItem(at: $0) } }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        var cursor = CMTime.zero
        for clip in clips {
            let url = directory.appendingPathComponent("join-\(UUID().uuidString).m4a")
            guard (try? clip.write(to: url)) != nil else { continue }
            scratch.append(url)
            let asset = AVURLAsset(url: url)
            guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
                  let duration = try? await asset.load(.duration) else { continue }
            try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }
        guard cursor > .zero,
              let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }
        let output = directory.appendingPathComponent("joined-\(UUID().uuidString).m4a")
        session.outputURL = output
        session.outputFileType = .m4a
        await session.export()
        defer { try? FileManager.default.removeItem(at: output) }
        guard session.status == .completed else { return nil }
        return try? Data(contentsOf: output)
    }

    /// Discards the master once the entry's copy is safe.
    static func discardMaster(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Plays a stored clip. Kept tiny — "Hear it" is one button.
@Observable
@MainActor
final class ClipPlayer {
    private var player: AVAudioPlayer?
    private(set) var playingID: UUID?

    func play(_ data: Data, id: UUID) {
        if playingID == id { stop(); return }
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.play()
            playingID = id
            let duration = player?.duration ?? 0
            Task {
                try? await Task.sleep(for: .seconds(duration + 0.1))
                if playingID == id { stop() }
            }
        } catch {
            playingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }
}
