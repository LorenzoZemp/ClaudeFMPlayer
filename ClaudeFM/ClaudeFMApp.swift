import SwiftUI

@main
struct ClaudeFMApp: App {
    @State private var player: StreamPlayer

    init() {
        let player = StreamPlayer()
        if UserDefaults.standard.bool(forKey: "playOnLaunch") {
            player.play()
        }
        _player = State(initialValue: player)
    }

    var body: some Scene {
        // A menu bar-only app: LSUIElement in the Info.plist keeps it out of the Dock.
        MenuBarExtra {
            PlayerMenu(player: player)
        } label: {
            Image(systemName: player.isPlaying ? "radio.fill" : "radio")
        }
        // .window lets the menu host real controls like a slider.
        .menuBarExtraStyle(.window)
    }
}
