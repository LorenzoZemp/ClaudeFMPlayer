import AppKit
import Observation
import WebKit
import os

/// Plays the Claude FM YouTube livestream through YouTube's own embedded player,
/// hosted in a WKWebView that is never shown.
///
/// Why a web view: YouTube doesn't publish a plain audio URL, and it now streams through
/// a protocol (SABR) that needs signed tokens, so there's no stable HLS link for AVPlayer.
/// The official embed player keeps working as YouTube changes things behind it.
@Observable
final class StreamPlayer: NSObject {
    enum Status: Equatable {
        case idle, loading, playing, paused
        case failed(String)
    }

    static let videoID = "tRsQsTMvPNg"

    private(set) var status: Status = .idle {
        didSet {
            guard status != oldValue, status != .idle else { return }
            nowPlaying?.update(isPlaying: isPlaying)
        }
    }

    var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: "volume")
            run("fm.setVolume(\(Int(volume * 100)))")
        }
    }

    var isPlaying: Bool { status == .playing || status == .loading }

    // Created on first play so the app costs nothing until you listen.
    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var hostWindow: NSWindow?
    @ObservationIgnored private var nowPlaying: NowPlaying?

    override init() {
        volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.7
        super.init()
        nowPlaying = NowPlaying(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() }
        )
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        status = .loading
        if let webView {
            // Jumps to the live edge so resuming after a pause doesn't play stale audio.
            webView.evaluateJavaScript("fm.play()")
        } else {
            loadPlayer()
        }
    }

    func pause() {
        run("fm.pause()")
        status = .paused
    }

    private func run(_ script: String) {
        webView?.evaluateJavaScript(script)
    }

    private func loadPlayer() {
        let config = WKWebViewConfiguration()
        // Allows the embed to start with sound without a click inside the page.
        config.mediaTypesRequiringUserActionForPlayback = []
        // Keeps WebKit from throttling the page because it isn't on screen.
        config.preferences.inactiveSchedulingPolicy = .none
        config.userContentController.add(WeakMessageHandler(self), name: "fm")

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 180), configuration: config)
        // YouTube rejects embeds with no referrer (error 153), so give the page a web origin.
        webView.loadHTMLString(Self.html(volume: Int(volume * 100)), baseURL: URL(string: "https://claudefm.app/"))
        self.webView = webView

        // WebKit won't start media in a page that isn't in a window, so park it in one
        // that sits off screen and never takes clicks or focus.
        let window = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: 320, height: 180),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
        window.contentView = webView
        window.orderFrontRegardless()
        hostWindow = window
    }

    private func handle(event: String, value: Int) {
        switch event {
        case "state":
            // YT.PlayerState: 1 playing, 2 paused, 3 buffering, 0 ended, -1 unstarted.
            switch value {
            case 1: status = .playing
            // Also fires when something outside the menu pauses the page, like a media key.
            case 2: status = .paused
            case 3: if status != .paused { status = .loading }
            case 0: status = .failed("The stream has ended")
            default: break
            }
        case "error":
            status = .failed(Self.describe(errorCode: value))
            Logger.app.error("YouTube player error \(value)")
            // Drop the player so the next play starts fresh.
            hostWindow?.close()
            hostWindow = nil
            webView = nil
        default:
            break
        }
        Logger.app.info("Player event \(event, privacy: .public) \(value) -> \(String(describing: self.status), privacy: .public)")
    }

    private static func describe(errorCode: Int) -> String {
        switch errorCode {
        case 100: "The stream isn't available"
        case 101, 150, 153: "YouTube won't play this stream here"
        default: "Couldn't play the stream"
        }
    }

    /// A 320×180 player makes YouTube pick a low video quality, which keeps CPU and data use down.
    private static func html(volume: Int) -> String {
        """
        <!doctype html>
        <html><head>
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;background:#000}</style>
        </head><body>
        <div id="player"></div>
        <script>
        const post = (event, value) => webkit.messageHandlers.fm.postMessage({ event, value });
        let player;
        window.fm = {
          play() { if (!player) return; player.seekTo(player.getDuration(), true); player.playVideo(); },
          pause() { player && player.pauseVideo(); },
          setVolume(v) { if (!player) return; player.unMute(); player.setVolume(v); },
        };
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: 320, height: 180, videoId: '\(videoID)',
            playerVars: { autoplay: 1, controls: 0, playsinline: 1, origin: 'https://claudefm.app' },
            events: {
              onReady: (e) => { e.target.unMute(); e.target.setVolume(\(volume)); e.target.playVideo(); post('ready', 0); },
              onStateChange: (e) => post('state', e.data),
              onError: (e) => post('error', e.data),
            },
          });
        }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }

    /// WKUserContentController retains its handlers, so this breaks the cycle back to the player.
    private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: StreamPlayer?
        init(_ target: StreamPlayer) { self.target = target }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
            target?.handle(event: event, value: (body["value"] as? Int) ?? 0)
        }
    }
}
