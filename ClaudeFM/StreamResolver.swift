import Foundation

/// Asks yt-dlp for the livestream's audio-only HLS playlist, which AVPlayer can play directly.
///
/// YouTube doesn't publish a stable audio URL, and the links it hands out expire after a few
/// hours, so we resolve a fresh one whenever playback starts.
enum StreamResolver {
    enum Failure: LocalizedError {
        case notInstalled
        case noStream(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled: "Install yt-dlp: brew install yt-dlp"
            case .noStream(let detail): detail.isEmpty ? "Couldn't find the stream" : detail
            }
        }
    }

    nonisolated static let watchURL = "https://www.youtube.com/watch?v=tRsQsTMvPNg"

    // Menu bar apps don't inherit your shell's PATH, so check the usual install spots.
    nonisolated private static let searchPaths = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "\(NSHomeDirectory())/.local/bin/yt-dlp",
    ]

    nonisolated static var executable: URL? {
        searchPaths.first(where: FileManager.default.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }

    /// Runs yt-dlp off the main thread and returns the playlist URL.
    nonisolated static func resolve() async throws -> URL {
        guard let executable = executable else { throw Failure.notInstalled }

        let process = Process()
        process.executableURL = executable
        // 234 and 233 are YouTube's high and low quality audio-only live formats.
        process.arguments = ["--get-url", "--format", "234/233/bestaudio", "--no-warnings", watchURL]
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        // Read before waiting so a chatty process can't fill the pipe and stall.
        let data = await Task.detached {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return data
        }.value

        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, let url = URL(string: text), url.scheme == "https" else {
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw Failure.noStream(message.contains("is offline") ? "The stream is offline right now" : "")
        }
        return url
    }
}
