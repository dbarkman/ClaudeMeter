import Foundation

/// Runs the Claude Code command-line tool to renew its own sign-in.
enum ClaudeCLI {
    /// Free check first; then a one-word request on the smallest model, which always
    /// makes Claude Code renew its token. That request is not saved as a session.
    static let statusStep = ["auth", "status"]
    static let requestStep = ["-p", "--model", "haiku", "--no-session-persistence", "Reply with the single word OK."]

    /// Don't send the paid request more than once per half hour, so a sign-in that
    /// can't be renewed doesn't trigger one on every 5-minute refresh.
    static let requestCooldown: TimeInterval = 30 * 60
    private static var lastRequestAt = Date.distantPast
    private static let lock = NSLock()

    static func renewalSteps(now: Date) -> [[String]] {
        lock.lock()
        defer { lock.unlock() }
        guard now.timeIntervalSince(lastRequestAt) >= requestCooldown else { return [statusStep] }
        lastRequestAt = now
        return [statusStep, requestStep]
    }

    /// Apps started from Finder don't get the shell's PATH, so check the usual install spots.
    static func locate() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.claude/local/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Runs `claude` with `arguments`, killing it after `timeout`. Returns true on exit 0.
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 90) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.currentDirectoryURL = FileManager.default.temporaryDirectory
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                var environment = ProcessInfo.processInfo.environment
                let bin = (path as NSString).deletingLastPathComponent
                environment["PATH"] = "\(bin):/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
                process.environment = environment

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: false)
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }
}
