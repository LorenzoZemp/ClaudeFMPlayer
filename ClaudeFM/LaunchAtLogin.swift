import Observation
import ServiceManagement
import os

/// Wraps SMAppService so the toggle always reflects what macOS actually has registered,
/// including changes the user makes in System Settings › General › Login Items.
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Launch at login change failed: \(error.localizedDescription)")
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.lorenzozemp.ClaudeFM", category: "app")
}
