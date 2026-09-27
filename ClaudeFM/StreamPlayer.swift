import AVFoundation
import Observation
import os

/// Plays the Claude FM livestream's audio with AVPlayer, using a URL resolved by yt-dlp.
@Observable
final class StreamPlayer {
    enum Status: Equatable {
        case idle, loading, playing, paused
        case failed(String)
    }

    private(set) var status: Status = .idle {
        didSet {
            guard status != oldValue, status != .idle else { return }
            nowPlaying?.update(isPlaying: isPlaying)
        }
    }

    var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: "volume")
            player.volume = Float(volume)
        }
    }

    var isPlaying: Bool { status == .playing || status == .loading }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var nowPlaying: NowPlaying?
    @ObservationIgnored private var playerObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var resolved: (url: URL, at: Date)?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// YouTube's links last about six hours; refresh well before that.
    private let urlLifetime: TimeInterval = 60 * 60

    init() {
        volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.7
        player.volume = Float(volume)

        playerObservation = player.observe(\.timeControlStatus) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in self?.playerDidChange(playing: playing) }
        }
        nowPlaying = NowPlaying(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() }
        )
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }
        status = .loading
        loadTask = Task { await start(retrying: true) }
    }

    func pause() {
        loadTask?.cancel()
        // Dropping the item (rather than just pausing) means the next play starts at the live edge.
        itemObservation = nil
        player.replaceCurrentItem(with: nil)
        status = .paused
    }

    private func start(retrying: Bool) async {
        do {
            let url = try await streamURL()
            guard !Task.isCancelled else { return }

            let item = AVPlayerItem(url: url)
            itemObservation = item.observe(\.status) { [weak self] item, _ in
                guard item.status == .failed else { return }
                Task { @MainActor in self?.itemDidFail(retrying: retrying) }
            }
            player.replaceCurrentItem(with: item)
            player.play()
        } catch {
            guard !Task.isCancelled else { return }
            status = .failed(error.localizedDescription)
            Logger.app.error("Couldn't resolve the stream: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func streamURL() async throws -> URL {
        if let resolved, Date.now.timeIntervalSince(resolved.at) < urlLifetime {
            return resolved.url
        }
        let url = try await StreamResolver.resolve()
        resolved = (url, .now)
        return url
    }

    /// Most failures are an expired link, so resolve a fresh one and try once more.
    private func itemDidFail(retrying: Bool) {
        guard isPlaying else { return }
        Logger.app.error("Playback failed: \(self.player.currentItem?.error?.localizedDescription ?? "unknown", privacy: .public)")
        resolved = nil
        if retrying {
            loadTask = Task { await start(retrying: false) }
        } else {
            pause()
            status = .failed("Couldn't play the stream")
        }
    }

    private func playerDidChange(playing: Bool) {
        // Only move forward from loading; paused and failed were chosen deliberately.
        if playing, status == .loading {
            status = .playing
        } else if !playing, status == .playing {
            status = .loading
        }
        Logger.app.info("Player playing=\(playing) -> \(String(describing: self.status), privacy: .public)")
    }
}
