<p align="center">
  <img src="docs/icon.png" width="128" alt="Clawd, the Claude Code mascot, as the Claude FM icon">
</p>

<h1 align="center">Claude FM Player</h1>

<p align="center">
  <em>Music for thinking and building, one click away in your menu bar.</em>
</p>

---

Claude FM is a tiny macOS menu bar app that plays the
[Claude FM livestream](https://www.youtube.com/watch?v=tRsQsTMvPNg) without a browser tab,
a Dock icon, or a single video frame on your screen. Click the little radio, hit play,
and get back to building. Clawd will keep the vibes going. 🦀🎶

## What it does

- **Lives in the menu bar.** No Dock icon, no windows, no clutter. The radio icon fills in while it's playing.
- **Play and pause.** That's it. It's a livestream, so there's nothing to skip. When you resume,
  it jumps straight back to the live edge instead of playing whatever you missed.
- **Its own volume slider.** Turn Claude FM down without touching your system volume or your
  call audio. Your level is remembered between launches.
- **Open at login.** Flip a switch and Claude FM is waiting in your menu bar every time you log in.
- **Play when opened.** Pair it with "Open at login" and the music starts the moment your Mac does.
- **Now Playing, starring Clawd.** Claude FM shows up in Control Center and responds to your
  keyboard's play/pause key, with the Claude Code mascot as the album art instead of a YouTube thumbnail.
- **Space bar toggles playback** while the menu is open, and ⌘Q quits.

## Requirements

- macOS 26 or later
- Xcode 26 or later to build it
- [yt-dlp](https://github.com/yt-dlp/yt-dlp), which finds the stream's audio for the app:

```bash
brew install yt-dlp
```

Claude FM looks for it in `/opt/homebrew/bin`, `/usr/local/bin` and `~/.local/bin`. If it can't
find it, the menu tells you how to install it. Keep it fresh with `brew upgrade yt-dlp` when
YouTube changes things and playback stops working.

## Build and run

```bash
git clone https://github.com/LorenzoZemp/ClaudeFMPlayer.git
cd ClaudeFMPlayer
open ClaudeFM.xcodeproj
```

Press ⌘R in Xcode. Look for the radio in your menu bar (not the Dock, it won't be there).

Prefer the command line?

```bash
xcodebuild -project ClaudeFM.xcodeproj -scheme ClaudeFM -derivedDataPath build build
open build/Build/Products/Debug/ClaudeFM.app
```

The project signs "to run locally", so you don't need a developer team to try it.

## How it works (and why)

YouTube doesn't hand out a plain audio URL for its streams, so something has to go and find one.

1. **When you press play, Claude FM asks yt-dlp for the stream.** It requests YouTube's
   audio-only live formats (itag 234, falling back to 233), so no video is ever downloaded.
2. **yt-dlp returns an HLS playlist**, which `AVPlayer` plays natively, like any other internet radio.
3. **Clawd takes the stage.** Because the app plays audio itself instead of through a web page,
   it owns the Now Playing slot, so Control Center, notch apps and your media keys all show Claude FM
   with Clawd as the artwork.

A few details that make it behave:

- **Nothing runs until you press play**, so an idle Claude FM costs next to nothing.
- **Pause really stops.** Pausing drops the stream, so pressing play again jumps back to the live
  edge instead of playing whatever you missed.
- **Links are refreshed.** YouTube's links expire after a few hours. Claude FM reuses a link for up
  to an hour, then fetches a new one. If playback fails, it fetches a fresh link and tries once more.
- **It's light.** Playback uses about 1% CPU, with no hidden browser running in the background.

### Why not the YouTube embed player?

The first version played the official YouTube embed in a hidden web view. It worked, but a web view
uses several times more CPU, and WebKit publishes YouTube's own Now Playing info, so notch apps showed
YouTube's thumbnail instead of Clawd. yt-dlp is an extra dependency, but it gives us real native playback.

### Why the app isn't sandboxed

Sandboxed Mac apps can't run tools installed with Homebrew, so the App Sandbox is turned off to let
Claude FM launch yt-dlp. That's normal for apps you build yourself or download outside the Mac App Store.
The app only runs yt-dlp and plays the stream it returns.

## Project layout

```
ClaudeFM/
├── ClaudeFMApp.swift     # The MenuBarExtra scene and "play when opened"
├── PlayerMenu.swift      # The menu: play/pause, volume, settings, quit
├── StreamPlayer.swift    # AVPlayer playback and its state
├── StreamResolver.swift  # Asks yt-dlp for the stream's audio URL
├── NowPlaying.swift      # Control Center, media keys and Clawd's album art
└── LaunchAtLogin.swift   # "Open at login" via SMAppService
```

## About Clawd

The artwork is a pixel-for-pixel trace of Clawd, the little critter from the Claude Code welcome
banner, drawn in Claude orange on a warm dark background. Claude, Claude Code and Clawd belong to
Anthropic. This is a fan-made project and isn't affiliated with or endorsed by Anthropic or YouTube.

## License

MIT. Go forth and vibe.
