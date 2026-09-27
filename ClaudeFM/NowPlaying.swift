import AppKit
import MediaPlayer

/// Publishes Claude FM to the system's Now Playing (Control Center, the menu bar widget,
/// media keys) with Clawd as the artwork instead of YouTube's thumbnail.
final class NowPlaying {
    private let center = MPNowPlayingInfoCenter.default()
    private let artwork: MPMediaItemArtwork? = NSImage(named: "Artwork").map { image in
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    init(onPlay: @escaping () -> Void, onPause: @escaping () -> Void) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { _ in onPlay(); return .success }
        commands.pauseCommand.addTarget { _ in onPause(); return .success }
        commands.togglePlayPauseCommand.addTarget { _ in
            // The player decides which way to go, so this just forwards the intent.
            MPNowPlayingInfoCenter.default().playbackState == .playing ? onPause() : onPlay()
            return .success
        }
        // A livestream has nothing to skip or scrub, so keep those buttons greyed out.
        for command in [commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.skipForwardCommand, commands.skipBackwardCommand,
                        commands.changePlaybackPositionCommand] {
            command.isEnabled = false
        }
    }

    func update(isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "Claude FM",
            MPMediaItemPropertyArtist: "Music for thinking and building",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }
}
