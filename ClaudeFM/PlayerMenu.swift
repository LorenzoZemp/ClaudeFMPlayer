import SwiftUI

struct PlayerMenu: View {
    @Bindable var player: StreamPlayer
    @State private var launchAtLogin = LaunchAtLogin()
    @AppStorage("playOnLaunch") private var playOnLaunch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude FM")
                        .font(.headline)
                    statusLine
                }
                Spacer()
                Button(action: player.togglePlayback) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .keyboardShortcut(.space, modifiers: [])
                .help(player.isPlaying ? "Pause" : "Play")
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                Slider(value: $player.volume, in: 0...1)
                    .accessibilityLabel("Volume")
                Image(systemName: "speaker.wave.3.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.set($0) }
                )) {
                    settingLabel("Open at login")
                }
                Toggle(isOn: $playOnLaunch) {
                    settingLabel("Play when opened")
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()

            Button("Quit Claude FM") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280)
        // The user may have changed login items in System Settings since we last looked.
        .onAppear { launchAtLogin.refresh() }
    }

    /// Stretches the label so the switches line up on the trailing edge, like System Settings.
    private func settingLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch player.status {
        case .idle:
            Text("Not playing")
                .foregroundStyle(.secondary)
        case .loading:
            Text("Connecting…")
                .foregroundStyle(.secondary)
        case .playing:
            Label("Live", systemImage: "circle.fill")
                .labelStyle(LiveLabelStyle())
        case .paused:
            Text("Paused")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}

/// A small red dot before "Live", like the badge on a broadcast.
private struct LiveLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 6))
                .foregroundStyle(.red)
            configuration.title
                .foregroundStyle(.secondary)
        }
    }
}
